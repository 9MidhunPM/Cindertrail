class_name CinderRelay
extends Node3D

const SITE_SPEC := preload("res://data/sites/relay.tres")
const STONE_SHADER := preload("res://art/materials/grove/weathered_palette.gdshader")
const CREAM := Color("#b9a180")
const HIGHLIGHT := Color("#d8c3a1")
const STONE_DARK := Color("#796e63")
const CLIFF := Color("#746d66")
const COPPER := Color("#a36b3d")
const BRONZE := Color("#634729")
const IRON := Color("#333b42")
const GOLD := Color("#e5b969")
const GRASS := Color("#956b31")
const CENTER := Vector3(10, 4.80, -53)
const SUMMIT := Vector3(20, 11.0, -84)
const APPROACH := [Vector3(0, .68, -24), Vector3(0, .68, -27),
	Vector3(4, 1.6, -34), Vector3(7, 2.7, -41), Vector3(8.54, 4.8, -44.55), Vector3(9, 4.8, -47), CENTER]
const WEST := [Vector3(-7, 3.10, -52.6), Vector3(-2.2, 3.98, -52.6),
	Vector3(4.0, 4.8, -52.6), CENTER]
const NORTH := [Vector3(3.8, 3.75, -68), Vector3(3.8, 4.58, -62.5),
	Vector3(6.0, 4.8, -57.8), CENTER]
const EAST := [Vector3(28, 3.88, -51.4), Vector3(23.4, 4.40, -51.4),
	Vector3(16.7, 4.8, -53), CENTER]
const BEACON_TRAIL := [Vector3(16, 4.8, -56), Vector3(20, 5.4, -62),
	Vector3(20, 7.3, -69), Vector3(19, 9.3, -77), Vector3(20, 11, -81), SUMMIT]

var site: CinderSite
var beacon: Marker3D
var caches := PackedVector3Array()

var _rng := RandomNumberGenerator.new()
var _visual := SurfaceTool.new()
var _collision := StaticBody3D.new()
var _walk_faces := PackedVector3Array()

func _ready() -> void:
	name = "FallenRelayTerrain"
	_rng.seed = 84440
	_visual.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collision.name = "RelayCollision"
	add_child(_collision)
	_ravine()
	_rng.seed = 84440
	_build_plateau()
	_passage(APPROACH, 4.1, true, 4)
	_passage(WEST, 3.4, true, 0)
	_passage(NORTH, 3.2, true, 2)
	_passage(EAST, 3.7, false, 0)
	_passage(BEACON_TRAIL, 3.4, true, 3)
	_supply_overlook()
	_generator()
	_beacon_summit()
	_finish_terrain()
	site = CinderSite.new()
	site.name = "FallenRelaySite"
	add_child(site)
	site.configure(SITE_SPEC, CENTER + Vector3.UP * 0.04,
		PackedVector3Array([Vector3(5.4, 4.82, -55.4), Vector3(12.2, 4.82, -56.1),
			Vector3(14.3, 4.82, -50.0), Vector3(6.4, 4.82, -49.7)]),
		[PackedVector3Array(WEST), PackedVector3Array(NORTH), PackedVector3Array(EAST)],
		Vector3(18.5, 19.6, -31.0), Vector3(10, 3.5, -54.4))

func _ravine() -> void:
	# Fill beneath the exposed bridge piers with a descending, non-walkable ravine.
	var grid: Array[PackedVector3Array] = []
	var bed := Color("#324f4d")
	var ledge := Color("#66716b")
	for row in 23:
		var points := PackedVector3Array()
		for column in 25:
			var x := -41.0 + column * 4.20 + _rng.randf_range(-.78, .78)
			var z := -24.7 - row * 3.90 + _rng.randf_range(-.57, .57)
			var height := _ravine_height(x, z) + _rng.randf_range(-.74, .58)
			points.append(Vector3(x, height, z))
		grid.append(points)
	for row in range(grid.size() - 1):
		for column in range(grid[row].size() - 1):
			var a := grid[row][column]
			var b := grid[row][column + 1]
			var c := grid[row + 1][column + 1]
			var d := grid[row + 1][column]
			var ridge := clampf((a.y + 7.0) * .12, 0.0, 1.0)
			var tint := bed.lerp(ledge, ridge).lightened(_rng.randf_range(-.10, .06))
			_face(a, b, c, Vector3.UP, tint)
			_face(a, c, d, Vector3.UP, tint.lightened(_rng.randf_range(-.07, .10)))
	for tree in 31:
		var x := _rng.randf_range(-27.5, 42.5)
		var z := _rng.randf_range(-89.0, -28.0)
		if absf(x - 11.0) < 10.0 or (z < -73.0 and absf(x - 19.0) < 8.0):
			continue
		var origin := Vector3(x, _ravine_height(x,z) - .56, z)
		var scale_factor := _rng.randf_range(.63, 1.32)
		_ravine_tree(origin, scale_factor, tree % 8 == 0)

func _ravine_height(x: float, z: float) -> float:
	var rise := smoothstep(27.0, 43.0, absf(z))
	var shelf := 4.2 * exp(-pow((x - 12.0) / 32.0, 2.0))
	var cut := 3.4 * exp(-pow((x + z * .43 + 9.0) / 8.7, 2.0))
	return -3.95 + rise * (shelf - cut + sin(x * .19) * 1.55 + cos(z * .18) * 1.5)

func _ravine_tree(origin: Vector3, scale_factor: float, orange: bool) -> void:
	var trunk_top := origin + Vector3.UP * scale_factor * 2.2
	_beam(origin, trunk_top, .17 * scale_factor, Color("#575246"), 5)
	var tone := Color("#98562d") if orange else Color("#1b5d58")
	for i in 5:
		var theta := TAU * (i + _rng.randf_range(-.15, .15)) / 5.0
		var arm := Vector3(cos(theta) * .94, _rng.randf_range(-.4, .42), sin(theta) * .94)
		var crown := trunk_top + arm * scale_factor
		_beam(trunk_top - Vector3.UP * .4, crown, .065 * scale_factor, Color("#575246"), 4)
		var rim := PackedVector3Array()
		for j in 7:
			var a := TAU * j / 7 + theta
			var radius := scale_factor * _rng.randf_range(.69, .96)
			rim.append(crown + Vector3(cos(a) * radius, _rng.randf_range(-.14, .15), sin(a) * radius))
		var peak := crown + Vector3.UP * scale_factor * _rng.randf_range(.39, .79)
		for j in rim.size():
			var next := (j + 1) % rim.size()
			_face(rim[j], rim[next], peak, Vector3.UP, tone.lightened(_rng.randf_range(-.08, .20)))
			_face(rim[j], rim[next], crown - Vector3.UP * .33, Vector3.DOWN, tone.darkened(.17))

func _build_plateau() -> void:
	var base := PackedVector3Array()
	var count := 22
	for i in count:
		var a := TAU * i / count
		var multiplier := _rng.randf_range(0.93, 1.09)
		base.append(CENTER + Vector3(cos(a) * 8.1, 0, sin(a) * 7.5) * multiplier)
	_plate(base, 6.1, CLIFF, true)
	var previous := 1.05
	for row in 4:
		var radius := [2.45, 3.9, 5.35, 7.25][row] as float
		var tiles := 10 + row * 5
		for index in tiles:
			var start := TAU * (index + 0.5 * (row % 2)) / tiles
			var end := start + TAU / tiles
			var polygon := PackedVector3Array()
			for pair in [Vector2(previous + .024, start + .008), Vector2(radius - .02, start + .006),
					Vector2(radius - .04, (start + end) / 2.0), Vector2(radius - .02, end - .006),
					Vector2(previous + .024, end - .008)]:
				polygon.append(CENTER + Vector3(cos(pair.y) * pair.x, .018 + _rng.randf_range(-.008, .008), sin(pair.y) * pair.x))
			_plate(polygon, .075, _stone(), false)
		previous = radius
	_disc(CENTER + Vector3.UP * .031, 1.1, 14, .11, HIGHLIGHT, false)
	_annular_floor(CENTER + Vector3.UP * .048, .82, 1.02, 18, COPPER)
	for i in 22:
		var a := TAU * i / 22.0
		var near_lane := minf(minf(absf(sin(a)), absf(cos(a))), absf(sin(a - 2.64)))
		if near_lane < 0.22:
			continue
		var edge := CENTER + Vector3(cos(a) * 7.43, .18, sin(a) * 6.75)
		var block := Vector3(_rng.randf_range(.52, 1.25), _rng.randf_range(.42, .94), _rng.randf_range(.51, .99))
		_block(edge, block, a + .32, _stone(), true)
		_grass(edge + Vector3(.28, -.14, .18), 7)

func _passage(path: Array, width: float, paving: bool, rail_frequency: int) -> void:
	for segment in range(path.size() - 1):
		var a: Vector3 = path[segment]
		var b: Vector3 = path[segment + 1]
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		var forward := flat.normalized()
		var side := Vector3(-forward.z, 0, forward.x)
		var spread := side * width * .5
		var begin := a - forward * .16 if segment == 0 else a
		var finish := b + forward * .16 if segment == path.size() - 2 else b
		var begin_spread := _joint_width(path, segment, width)
		var finish_spread := _joint_width(path, segment + 1, width)
		var base := PackedVector3Array([begin - begin_spread, begin + begin_spread,
			finish + finish_spread, finish - finish_spread])
		_plate(base, 1.0, CREAM, true)
		var count := ceili(flat.length() / .71)
		var angle := atan2(-forward.x, -forward.z)
		for row in count:
			var start := a.lerp(b, float(row) / count)
			var end := a.lerp(b, float(row + 1) / count)
			if paving:
				_pave_row(start, end, side, width)
			if row % 3 == 1:
				for hand in [-1.0, 1.0]:
					var edge: Vector3 = start + spread * hand
					_grass(edge - spread * .11 * hand, 5)
					var pillar_length := maxf(1.25, edge.y + 1.4)
					_rock_column(edge - Vector3.UP * .12, _rng.randf_range(.38, .75),
						pillar_length, CLIFF, 0.82 + _rng.randf_range(0.0, .85))
			if rail_frequency > 0 and row % rail_frequency == 1:
				for hand in [-1.0, 1.0]:
					var footing: Vector3 = start + spread * hand * .97
					_block(footing + Vector3.UP * .29, Vector3(.45, .72, .51), angle, _stone(), true)
					_block(footing + Vector3.UP * .68, Vector3(.55, .14, .6), angle, HIGHLIGHT)
					if row + rail_frequency < count:
						var next: Vector3 = a.lerp(b, float(row + rail_frequency) / count) + spread * hand * .97
						_beam(footing + Vector3.UP * .50, next + Vector3.UP * .50, .09, STONE_DARK, 4)

func _joint_width(path: Array, index: int, width: float) -> Vector3:
	var point: Vector3 = path[index]
	var before: Vector3 = path[index - 1] if index > 0 else point
	var after: Vector3 = path[index + 1] if index < path.size() - 1 else point
	var previous := (point - before).slide(Vector3.UP).normalized()
	var next := (after - point).slide(Vector3.UP).normalized()
	var along := (previous + next).normalized()
	var correction := maxf(maxf(along.dot(previous), along.dot(next)), .6)
	return Vector3(-along.z, 0, along.x) * width * .5 / correction

func _pave_row(begin: Vector3, end: Vector3, side: Vector3, width: float) -> void:
	var gaps := [-.50, _rng.randf_range(-.22, -.1), _rng.randf_range(.1, .26), .50]
	var run := begin.direction_to(end)
	for column in 3:
		var left: Vector3 = side * (float(gaps[column]) * width + .02)
		var right: Vector3 = side * (float(gaps[column + 1]) * width - .02)
		var riser := Vector3.UP * .038
		var start := begin + run * .025
		var finish := end - run * .025
		if absf(end.y - begin.y) > .029:
			start.y = maxf(begin.y, end.y) - .046
			finish.y = start.y
		_plate(PackedVector3Array([start + left + riser, start + right + riser,
			finish + right + riser, finish + left + riser]), .10, _stone(), false)

func _supply_overlook() -> void:
	var approach := [Vector3(4, 1.60, -34), Vector3(.5, 1.81, -37), Vector3(-1.9, 2.03, -40.1)]
	_passage(approach, 2.6, true, 0)
	var overlook := Vector3(-2.1, 2.03, -40.5)
	_disc(overlook, 1.9, 10, 2.6, _stone(), true)
	caches.append(overlook + Vector3(.1, .045, -.47))
	for offset in [Vector3(-1.15, 0, -.8), Vector3(.98, 0, -.95)]:
		_obelisk(overlook + offset, 2.45, .48)
	_beam(overlook + Vector3(-1.30, 2.39, -.85), overlook + Vector3(1.10, 2.39, -.93),
		.23, HIGHLIGHT, 4)
	_grass(overlook + Vector3(-1.11, .03, .77), 13)

func _generator() -> void:
	var base := Vector3(12.7, 4.8, -58.8)
	_disc(base, 2.68, 14, .27, STONE_DARK, true)
	_disc(base + Vector3.UP * .25, 2.02, 13, .26, CREAM, false)
	var center := base + Vector3.UP * 1.92
	_arch(center, 2.63, .52, .53, COPPER, 17, -0.10, PI + 0.10)
	_arch(center + Vector3(0, .015, .32), 2.25, .12, .13, GOLD, 16, .075, PI - .075)
	_arch(center, 2.60, .13, .24, BRONZE, 12, -.09, PI + .09)
	for side in [-1, 1]:
		var direction := float(side)
		_block(base + Vector3(direction * 2.60, .76, .0), Vector3(.65, 1.60, .83), -.04 * direction, BRONZE, true)
		_block(base + Vector3(direction * 2.60, .16, .0), Vector3(.88, .37, 1.18), -.04 * direction, HIGHLIGHT)
		for i in 5:
			var angle := .17 + i * .25
			var radial := Vector3(cos(angle) * direction, sin(angle), 0)
			_beam(center + radial * 2.39 + Vector3.FORWARD * .14,
				center + radial * 2.86 + Vector3.FORWARD * .14, .095, GOLD, 4)
	_disc(base + Vector3.UP * .64, 1.08, 10, .49, BRONZE, false)
	_disc(base + Vector3.UP * 1.10, .89, 12, .51, COPPER, true)
	_disc(base + Vector3.UP * 1.23, .81, 12, .18, GOLD, false)
	_disc(base + Vector3.UP * 1.48, .61, 12, .24, BRONZE, false)
	for i in 12:
		var theta := i * TAU / 12
		var at := base + Vector3(cos(theta) * .78, .64, sin(theta) * .78)
		_beam(at, at + Vector3.UP * .83, .055, GOLD, 5)
		_beam(at + Vector3.UP * .16, at + Vector3.UP * .44, .045, COPPER, 4)
	_beam(base + Vector3.UP * 1.4, base + Vector3.UP * 3.73, .15, IRON, 8)
	_disc(base + Vector3.UP * 2.44, .31, 8, .27, COPPER, false)
	_disc(base + Vector3.UP * 3.68, .54, 9, .46, BRONZE, false)
	var lamp := OmniLight3D.new()
	lamp.name = "RelayLamps"
	lamp.position = base + Vector3(0, 1.3, 1.15)
	lamp.light_color = Color("#f6aa5e")
	lamp.light_energy = .64
	lamp.omni_range = 6.2
	add_child(lamp)
	var west := Vector3(5.5, 4.81, -60.8)
	var east := Vector3(17.7, 4.62, -58.65)
	_obelisk(west, 5.9, 1.15)
	_obelisk(east, 6.7, 1.2)
	_cable(west + Vector3(0, 5.74, 0), base + Vector3(0, 4.10, .02), 1.3)
	_cable(base + Vector3(0, 4.10, .02), east + Vector3(0, 6.56, 0), 1.15)
	for post in [west, east]:
		_grass(post + Vector3(.55, .05, -.34), 14)
		_rock_column(post - Vector3.UP * .1, .86, post.y + 1.0, CLIFF, 1.15)

func _beacon_summit() -> void:
	var summit := PackedVector3Array()
	for i in 16:
		var angle := TAU * i / 16
		var radius := _rng.randf_range(4.3, 5.0)
		var edge := SUMMIT + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		edge.z = minf(edge.z, -81.1)
		summit.append(edge)
	_plate(summit, 12.6, CLIFF, true)
	_disc(SUMMIT + Vector3.UP * .026, 2.95, 18, .17, CREAM, false)
	_disc(SUMMIT + Vector3.UP * .044, 1.78, 14, .13, STONE_DARK, false)
	_disc(SUMMIT + Vector3.UP * .068, 1.28, 14, .15, HIGHLIGHT, false)
	_annular_floor(SUMMIT + Vector3.UP * .075, .92, 1.14, 14, COPPER)
	var center := SUMMIT + Vector3.UP * 1.77
	_arch(center, 2.05, .37, .39, HIGHLIGHT, 24, 0, TAU)
	_arch(center + Vector3.BACK * .244, 1.79, .11, .11, GOLD.lerp(COPPER, .31), 24, 0, TAU)
	_arch(center + Vector3.FORWARD * .244, 1.79, .11, .11, GOLD, 24, 0, TAU)
	_block(center + Vector3.UP * 2.08, Vector3(.32, .63, .70), .0, COPPER)
	for side in [-1, 1]:
		var foot := SUMMIT + Vector3(float(side) * 2.39, 0, 0)
		_obelisk(foot, 2.95, .73)
		_beam(foot + Vector3.UP * 1.4, center + Vector3(float(side) * 1.85, 0, 0), .15, COPPER, 6)
	for i in 23:
		var a := TAU * i / 23.0
		var edge := SUMMIT + Vector3(cos(a) * 3.70, .03, sin(a) * 3.70)
		_grass(edge, 6)
		if i % 3 == 0 and absf(cos(a)) > .45:
			_block(edge + Vector3.UP * .22, Vector3(.64, .50, .41), a, _stone(), true)
	beacon = Marker3D.new()
	beacon.name = "BeaconCradle"
	beacon.position = SUMMIT + Vector3.UP * .08
	add_child(beacon)

func _obelisk(base: Vector3, height: float, width: float) -> void:
	_block(base + Vector3.UP * .12, Vector3(width * 1.39, .24, width * 1.39), .12, CREAM, true)
	var tiers := ceili(height / .74)
	for i in tiers:
		var t := float(i) / tiers
		var wide := lerpf(width, width * .54, t)
		var reach := height / tiers
		var point := base + Vector3.UP * (reach * (i + .5) + .15)
		_block(point, Vector3(wide, reach - .014, wide), .12 + .035 * sin(i * 1.3), _stone(), true)
		if i > 0 and i % 3 == 1:
			_block(point + Vector3.UP * .19, Vector3(wide * 1.05, .086, wide * 1.05), .12, COPPER)
	_block(base + Vector3.UP * (height + .16), Vector3(width * .98, .19, width * .84), .12, HIGHLIGHT)
	_block(base + Vector3.UP * (height + .31), Vector3(width * .54, .27, width * .50), .12, GOLD)

func _finish_terrain() -> void:
	var geometry := MeshInstance3D.new()
	geometry.name = "MasonryAndRidge"
	var material := ShaderMaterial.new()
	material.shader = STONE_SHADER
	geometry.mesh = _visual.commit()
	geometry.material_override = material
	add_child(geometry)
	var surface := ConcavePolygonShape3D.new()
	surface.set_faces(_walk_faces)
	var walk := CollisionShape3D.new()
	walk.shape = surface
	_collision.add_child(walk)

func _plate(polygon: PackedVector3Array, thickness: float, color: Color, walkable: bool) -> void:
	var center := Vector3.ZERO
	for point in polygon:
		center += point
	center /= polygon.size()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if walkable:
			var face := [a, b, center] if (center - a).cross(b - a).y >= 0 else [a, center, b]
			_walk_faces.append_array(PackedVector3Array(face))
		var side := (a + b) * .5 - center
		side.y = 0
		var ridge_a := a.lerp(center, .014)
		var ridge_b := b.lerp(center, .014)
		var lip_a := a + Vector3.DOWN * minf(thickness * .45, .065)
		var lip_b := b + Vector3.DOWN * minf(thickness * .45, .065)
		var foot_a := a + Vector3.DOWN * thickness
		var foot_b := b + Vector3.DOWN * thickness
		_face(ridge_a, ridge_b, center, Vector3.UP, color)
		_quad(ridge_a, ridge_b, lip_b, lip_a, Vector3.UP + side.normalized() * .7, color.lightened(.05))
		_quad(lip_a, lip_b, foot_b, foot_a, side, color.darkened(.17 + .11 * _rng.randf()))

func _disc(center: Vector3, radius: float, sides: int, thickness: float, color: Color, walkable: bool) -> void:
	var ring := PackedVector3Array()
	for i in sides:
		var a := TAU * i / sides
		ring.append(center + Vector3(cos(a), 0, sin(a)) * radius)
	_plate(ring, thickness, color, walkable)

func _annular_floor(center: Vector3, inner: float, outer: float, count: int, color: Color) -> void:
	for i in count:
		var a := TAU * (i + .10) / count
		var b := TAU * (i + .88) / count
		var first := Vector3(cos(a), 0, sin(a))
		var last := Vector3(cos(b), 0, sin(b))
		_quad(center + first * inner, center + first * outer, center + last * outer,
			center + last * inner, Vector3.UP, color)

func _rock_column(top: Vector3, radius: float, length: float, color: Color, elongation: float) -> void:
	var ring := PackedVector3Array()
	var offset := _rng.randf() * TAU
	for i in 6:
		var a := i * TAU / 6.0 + offset
		ring.append(top + Vector3(cos(a) * radius, _rng.randf_range(-.26, .0), sin(a) * radius * elongation))
	_plate(ring, length, color.darkened(_rng.randf_range(.03, .26)), false)

func _block(point: Vector3, size: Vector3, yaw: float, color: Color, solid := false) -> void:
	var half := size * .5
	var rim := PackedVector3Array()
	var turn := Basis(Vector3.UP, yaw)
	var chamfer := minf(half.x, half.z) * .18
	var corners: Array[Vector2] = [
		Vector2(-half.x + chamfer, -half.z), Vector2(half.x - chamfer, -half.z),
		Vector2(half.x, -half.z + chamfer), Vector2(half.x, half.z - chamfer),
		Vector2(half.x - chamfer, half.z), Vector2(-half.x + chamfer, half.z),
		Vector2(-half.x, half.z - chamfer), Vector2(-half.x, -half.z + chamfer)]
	for corner in corners:
		rim.append(point + turn * Vector3(corner.x, half.y, corner.y))
	_plate(rim, size.y, color, false)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var volume := CollisionShape3D.new()
		volume.shape = shape
		volume.transform = Transform3D(turn, point)
		_collision.add_child(volume)

func _arch(center: Vector3, radius: float, width: float, depth: float, color: Color,
		count: int, begin: float, end: float) -> void:
	for i in count:
		var a := lerpf(begin, end, (i + .055) / count)
		var b := lerpf(begin, end, (i + .945) / count)
		var first := Vector3(cos(a), sin(a), 0)
		var last := Vector3(cos(b), sin(b), 0)
		var inner := radius - width * .5
		var outer := radius + width * .5
		var front := Vector3.BACK * depth * .5
		var outer_a := center + first * outer
		var outer_b := center + last * outer
		var inner_a := center + first * inner
		var inner_b := center + last * inner
		var tint := color.lerp(HIGHLIGHT, _rng.randf_range(0.0, .12))
		_quad(outer_a + front, outer_b + front, inner_b + front, inner_a + front, Vector3.BACK, tint)
		_quad(outer_a - front, outer_b - front, inner_b - front, inner_a - front, Vector3.FORWARD, tint.darkened(.07))
		_quad(outer_a - front, outer_b - front, outer_b + front, outer_a + front, first + last, tint.darkened(.16))
		_quad(inner_a - front, inner_b - front, inner_b + front, inner_a + front, -first - last, tint.darkened(.21))
		_quad(inner_a - front, outer_a - front, outer_a + front, inner_a + front, first.cross(Vector3.BACK), tint.darkened(.12))
		_quad(inner_b - front, outer_b - front, outer_b + front, inner_b + front, last.cross(Vector3.FORWARD), tint.darkened(.12))

func _cable(begin: Vector3, end: Vector3, sag: float) -> void:
	var last := begin
	for i in range(1, 16):
		var t := float(i) / 15.0
		var point := begin.lerp(end, t) + Vector3.DOWN * sin(t * PI) * sag
		_beam(last, point, .047, BRONZE, 5)
		last = point

func _beam(a: Vector3, b: Vector3, radius: float, color: Color, sides: int) -> void:
	var forward := a.direction_to(b)
	var normal := Vector3.UP if absf(forward.y) < .92 else Vector3.RIGHT
	var right := forward.cross(normal).normalized()
	var up := right.cross(forward).normalized()
	for i in sides:
		var angle := TAU * i / sides
		var next := TAU * (i + 1) / sides
		var first := (right * cos(angle) + up * sin(angle)) * radius
		var second := (right * cos(next) + up * sin(next)) * radius
		_quad(a + first, a + second, b + second, b + first, first + second, color)

func _grass(point: Vector3, blades: int) -> void:
	for i in blades:
		var angle := _rng.randf() * TAU
		var side := Vector3(cos(angle), 0, sin(angle))
		var base := point + side * _rng.randf_range(.01, .22)
		var bend := side.rotated(Vector3.UP, 1.11)
		var peak := base + (Vector3.UP + bend * .52) * _rng.randf_range(.11, .42)
		var tint := GRASS.lerp(GOLD, _rng.randf_range(.18, .70))
		var left := base - side * .025
		var right := base + side * .025
		_face(left, right, peak, bend, tint)
		_face(right, left, peak, -bend, tint.darkened(.12))

func _stone() -> Color:
	return CREAM.lerp(HIGHLIGHT, _rng.randf_range(-.23, .75)).lerp(STONE_DARK, _rng.randf_range(0.0, .16))

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, color: Color) -> void:
	_face(a, b, c, outward, color)
	_face(a, c, d, outward, color)

func _face(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < .00000001:
		return
	normal = normal.normalized()
	var vertices: Array[Vector3] = [a, b, c]
	if normal.dot(outward) < 0.0:
		normal = -normal
		vertices = [a, c, b]
	for v in vertices:
		_visual.set_normal(normal)
		_visual.set_color(color)
		_visual.add_vertex(v)
