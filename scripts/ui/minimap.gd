class_name CinderMinimap
extends Control
## Data-driven valley map. Draws the authored trails, water, camps, caches,
## the beacon, live creatures and the traveler straight from the running world,
## so it follows any change to the terrain without a baked image.
## As a corner minimap it rotates with the camera; as the full map it is north-up.

const PAPER := Color(0.035, 0.085, 0.105, 0.86)
const LAND := Color(0.16, 0.24, 0.21, 0.55)
const TRAIL := Color("#d8c39c")
const WATER := Color("#3fb7b0")
const GOLD := Color("#ffce83")
const SPENT := Color("#7d8a8c")
const ENEMY := Color("#ff6f5e")
const CYAN := Color("#64e2d9")
const RIM := Color(0.78, 0.62, 0.38, 0.9)

var game: Node
## Metres from the center to the rim of the corner map.
var radius_m := 95.0
var full := false
var objective := Vector3.INF
var _roads: Array[PackedVector3Array] = []
var _towns: Dictionary = {}
var _lake_center := Vector3.INF
var _bounds := Rect2()
var _font: Font
var _pulse := 0.0
var _zoom := 95.0

var _canvas := Control.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	# The root draws the mask; the canvas draws the map clipped to it.
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_map)

func bind(world: Node) -> void:
	game = world
	_roads.clear()
	_towns.clear()
	var grove: CinderGrove = world.get("grove_terrain")
	_lake_center = grove.global_position if grove != null else Vector3.INF
	var outer = world.get("outer_valley")
	if outer != null:
		if outer.abandoned_towns != null:
			for key: String in CinderOuterValley.TOWN_TITLES:
				_towns[CinderOuterValley.TOWN_TITLES[key]] = outer.junctions[key]
		for road: PackedVector3Array in outer.roads:
			_roads.append(road)
	var frontier = world.get("frontier")
	if frontier != null and frontier.get("paths") != null:
		for path: PackedVector3Array in frontier.paths:
			_roads.append(path)
	var districts = world.get("districts")
	if districts != null:
		for district in districts:
			for path: PackedVector3Array in district.map_paths():
				_roads.append(path)
	for site: CinderSite in world.sites:
		for lane in site.lanes:
			if lane.size() > 1:
				_roads.append(lane)
	var points := PackedVector2Array()
	for road in _roads:
		for p in road:
			points.append(Vector2(p.x, p.z))
	_bounds = Rect2(points[0], Vector2.ZERO) if not points.is_empty() else Rect2(-50, -50, 100, 100)
	for p in points:
		_bounds = _bounds.expand(p)
	_bounds = _bounds.grow(40.0)

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	var tactical: bool = game != null and game.get("active_site") != null
	_zoom = lerpf(_zoom, (48.0 if tactical else radius_m), 1.0 - exp(-4.0 * delta))
	queue_redraw()
	_canvas.queue_redraw()

## Map a world point to control coordinates.
func _to_map(point: Vector3, center: Vector2, scale_px: float, yaw: float, origin: Vector3) -> Vector2:
	var rel := Vector2(point.x - origin.x, point.z - origin.z)
	return center + rel.rotated(-yaw) * scale_px

func _draw() -> void:
	if full:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	else:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Color.WHITE)

func _camera_yaw() -> float:
	var view: Camera3D = game.get("camera")
	if view == null:
		return 0.0
	var forward := -view.global_basis.z
	return atan2(-forward.x, -forward.z)

func _draw_map() -> void:
	if game == null or game.get("player") == null:
		return
	var canvas := _canvas
	var center := size * 0.5
	var origin: Vector3
	var yaw := 0.0
	var scale_px: float
	var reach := minf(size.x, size.y) * 0.5
	if full:
		origin = Vector3(_bounds.get_center().x, 0, _bounds.get_center().y)
		scale_px = minf(size.x / _bounds.size.x, size.y / _bounds.size.y) * 0.96
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.07, 0.94))
	else:
		origin = game.player.global_position
		yaw = -_camera_yaw()
		scale_px = reach / _zoom
		_canvas.draw_circle(center, reach, PAPER)
	var clip := func(p: Vector2) -> bool:
		return full or p.distance_to(center) <= reach - 2.0
	# Land bands follow every trail so the walkable valley reads as a shape.
	for road in _roads:
		_polyline(road, center, scale_px, yaw, origin, LAND, maxf(26.0 * scale_px, 6.0), reach)
	if _lake_center != Vector3.INF:
		var middle := _to_map(_lake_center, center, scale_px, yaw, origin)
		_canvas.draw_circle(middle, 21.56 * scale_px, Color(WATER, 0.45))
	for road in _roads:
		_polyline(road, center, scale_px, yaw, origin, Color(TRAIL, 0.85), maxf(2.6 * scale_px, 1.6), reach)
	if full:
		for town: String in _towns:
			var point := _to_map(_towns[town], center, scale_px, yaw, origin)
			var ink := Color("#abccbd")
			_canvas.draw_polyline(PackedVector2Array([point + Vector2(-4, 2), point + Vector2(-4, -3),
				point + Vector2(0, -6), point + Vector2(4, -3), point + Vector2(4, 2)]), ink, 1.5, true)
			_canvas.draw_string(_font, point + Vector2(7, -5), town, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	# Caches, discoveries and the beacon.
	for cache in game.get("_caches"):
		if is_instance_valid(cache):
			_marker(cache.global_position, center, scale_px, yaw, origin, reach, &"cache", GOLD)
	var beacon: Node3D = game.get("beacon")
	if beacon != null:
		var ready: bool = game.core.restoration >= 99.9
		_marker(beacon.global_position, center, scale_px, yaw, origin, reach, &"beacon", GOLD if ready else SPENT, ready)
	for site: CinderSite in game.sites:
		var spent := site.remaining_energy <= 0.001
		var active: bool = site == game.get("active_site")
		var tint := SPENT if spent else (CYAN if active else GOLD)
		_marker(site.anchor.global_position, center, scale_px, yaw, origin, reach, &"site", tint, not spent,
			site.remaining_energy / maxf(site.spec.energy, 0.001), site.label)
	if game.battle != null:
		for enemy: CinderEnemy in game.battle.enemies:
			var p := _to_map(enemy.global_position, center, scale_px, yaw, origin)
			if clip.call(p):
				_canvas.draw_circle(p, 3.6 if enemy.stats.height >= 1.0 else 2.4, ENEMY)
	if objective != Vector3.INF:
		var pulse := 0.5 + 0.5 * sin(_pulse * 3.0)
		_marker(objective, center, scale_px, yaw, origin, reach, &"objective", Color(1, 1, 1, 0.55 + 0.45 * pulse), true)
	# The traveler, pointing where they face.
	var facing: float = game.player.visual.rotation.y
	var here := _to_map(game.player.global_position, center, scale_px, yaw, origin)
	var forward := Vector2(-sin(facing), -cos(facing)).rotated(-yaw)
	var side := Vector2(-forward.y, forward.x)
	_canvas.draw_colored_polygon(PackedVector2Array([here + forward * 9.0, here - forward * 5.0 + side * 5.5,
		here - forward * 2.5, here - forward * 5.0 - side * 5.5]), Color("#ffe6b0"))
	if not full:
		# View cone of the camera, the rim, and a north tick that turns with the map.
		_canvas.draw_arc(center, reach - 1.0, 0.0, TAU, 72, RIM, 2.0, true)
		_canvas.draw_arc(center, reach - 5.0, 0.0, TAU, 72, Color(RIM, 0.25), 1.0, true)
		var north := center + Vector2(0, -1).rotated(-yaw) * (reach - 11.0)
		_canvas.draw_string(_font, north + Vector2(-5, 6), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, GOLD)

func _polyline(road: PackedVector3Array, center: Vector2, scale_px: float, yaw: float, origin: Vector3,
		color: Color, width: float, reach: float) -> void:
	var run := PackedVector2Array()
	for p in road:
		var m := _to_map(p, center, scale_px, yaw, origin)
		if full or m.distance_to(center) <= reach * 1.6:
			run.append(m)
		else:
			if run.size() > 1:
				_canvas.draw_polyline(run, color, width, true)
			run.clear()
	if run.size() > 1:
		_canvas.draw_polyline(run, color, width, true)

func _marker(point: Vector3, center: Vector2, scale_px: float, yaw: float, origin: Vector3, reach: float,
		kind: StringName, tint: Color, emphasize := false, fill := 1.0, label := "") -> void:
	var p := _to_map(point, center, scale_px, yaw, origin)
	var pinned := false
	if not full and p.distance_to(center) > reach - 10.0:
		if kind != &"objective" and kind != &"beacon" and not (kind == &"site" and emphasize):
			return
		p = center + (p - center).normalized() * (reach - 10.0)
		pinned = true
	match kind:
		&"cache":
			_canvas.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), tint)
		&"beacon":
			var star := PackedVector2Array()
			for k in 10:
				var r := 8.0 if k % 2 == 0 else 3.4
				star.append(p + Vector2.from_angle(-PI * 0.5 + k * TAU / 10.0) * r)
			_canvas.draw_colored_polygon(star, tint)
		&"site":
			_canvas.draw_circle(p, 6.5, Color(0.03, 0.07, 0.09, 0.9))
			_canvas.draw_arc(p, 6.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 24, tint, 2.4, true)
			_canvas.draw_circle(p, 2.6, tint)
			if full and not label.is_empty():
				_canvas.draw_string(_font, p + Vector2(10, 5), "%s  %d%%" % [label, roundi(fill * 100.0)],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
		&"objective":
			_canvas.draw_arc(p, 9.0 + (0.0 if pinned else 2.0 * sin(_pulse * 3.0)), 0.0, TAU, 28, tint, 2.0, true)
			if pinned:
				var out := (p - center).normalized()
				var side := Vector2(-out.y, out.x)
				_canvas.draw_colored_polygon(PackedVector2Array([p + out * 8.0, p + side * 5.0, p - side * 5.0]), tint)
