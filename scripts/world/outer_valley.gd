class_name CinderOuterValley
extends Node3D

const LAND := preload("res://art/outer_valley/outer_land.glb")
const TRAILS := preload("res://data/outer_valley/trails.json")
const LANDMARKS := preload("res://data/outer_valley/landmarks.json")
const PIGMENT := preload("res://art/outer_valley/valley_pigment.gdshader")
const POOL := preload("res://art/materials/grove/shallows.gdshader")
const WINCH := preload("res://scripts/world/valley_winch.gd")
const DETAIL := preload("res://scripts/world/outer_camp_detail.gd")
const ROUTE_PAINT := preload("res://art/textures/stylized/route_paint.png")
const SITE_DATA := {
	"lanternwood": preload("res://data/sites/lanternwood.tres"),
	"sunken_aqueduct": preload("res://data/sites/sunken_aqueduct.tres"),
	"sunwatch": preload("res://data/sites/sunwatch.tres"),
}
const DESTINATIONS := {
	"quarry": "Broken Quarry", "grove": "Flooded Grove", "relay": "Fallen Relay",
	"west": "Lanternwood", "south": "Sunken Aqueduct", "east": "Sunwatch Observatory",
	"cross": "Pilgrims’ Cross", "ruins": "Western Arcade", "terrace": "Bellmakers’ Terrace",
	"saddle": "Orchard Pass", "spring": "Mineral Spring",
}

var sites: Array[CinderSite] = []
var roads: Array[PackedVector3Array] = []
var road_names := PackedStringArray()
var caches := PackedVector3Array()
var cache_ids := PackedStringArray()
var junctions := {}
var _winches: Array[Node3D] = []
var _landmarks := {}
var _camp_detail := DETAIL.new()

func _ready() -> void:
	name = "OuterValley"
	var land := LAND.instantiate()
	add_child(land)
	var pigment := ShaderMaterial.new()
	pigment.shader = PIGMENT
	pigment.set_shader_parameter("route_paint", ROUTE_PAINT)
	pigment.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	var leaf_pigment := pigment.duplicate() as ShaderMaterial
	leaf_pigment.set_shader_parameter("moves_in_wind", true)
	var soil := pigment.duplicate() as ShaderMaterial
	soil.set_shader_parameter("family", 1)
	var bark := pigment.duplicate() as ShaderMaterial
	bark.set_shader_parameter("family", 2)
	var channel := ShaderMaterial.new()
	channel.shader = POOL
	channel.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	for piece: MeshInstance3D in land.find_children("*", "MeshInstance3D", true, false):
		if str(piece.name).begins_with("Water"):
			piece.material_override = channel
		elif str(piece.name).begins_with("Leaves"):
			piece.material_override = leaf_pigment
		elif str(piece.name).begins_with("Ground"):
			piece.material_override = soil
		elif str(piece.name).begins_with("Trunks"):
			piece.material_override = bark
		elif not str(piece.name).begins_with("Lantern"):
			piece.material_override = pigment
	for key: String in TRAILS.data.nodes:
		junctions[key] = _point(TRAILS.data.nodes[key])
	var wood: Vector3 = junctions.west
	var sluice: Vector3 = junctions.south
	var summit: Vector3 = junctions.east
	_landmarks[&"lanternwood"] = PackedVector3Array([wood + Vector3(5, 0, -4)])
	_landmarks[&"sunken_aqueduct"] = PackedVector3Array([sluice + Vector3(6, 0, -5.5)])
	_landmarks[&"sunwatch_observatory"] = PackedVector3Array([
		summit + Vector3(-5.5, 0, 5), summit + Vector3(5.5, 0, 5)])
	add_child(_camp_detail)
	_camp_detail.setup(_landmarks, junctions)
	for trail: Array in TRAILS.data.trails:
		var route := PackedVector3Array([junctions[trail[1]]])
		for coord: Array in trail[2]:
			route.append(_point(coord))
		route.append(junctions[trail[3]])
		roads.append(route)
		road_names.append(trail[0])
		_sign(route[0], route[1], DESTINATIONS[trail[3]])
		_sign(route[-1], route[-2], DESTINATIONS[trail[1]])
	for spec: Dictionary in LANDMARKS.data.sites:
		_create_camp(spec)
	for entry: Array in LANDMARKS.data.caches:
		cache_ids.append(entry[0])
		caches.append(junctions[entry[1]] + _point(entry[2]))
	for entry: Dictionary in LANDMARKS.data.gates:
		var trail := roads[road_names.find(entry.trail)]
		var start := trail[int(entry.section)]
		var end := trail[int(entry.section) + 1]
		var direction := end - start
		var grade := direction.y / Vector2(direction.x, direction.z).length()
		direction.y = 0.0
		var winch := WINCH.new()
		add_child(winch)
		winch.configure(entry.id, entry.name, (start + end) * .5, direction.normalized(), grade)
		_winches.append(winch)

func _create_camp(definition: Dictionary) -> void:
	var origin: Vector3 = junctions[definition.node]
	var sockets := PackedVector3Array()
	for offset: Array in definition.sockets:
		sockets.append(origin + Vector3(offset[0], .05, offset[1]))
	var lanes: Array[PackedVector3Array] = []
	for track: Array in definition.lanes:
		var lane := PackedVector3Array()
		for offset: Array in track:
			lane.append(origin + Vector3(offset[0], .03, offset[1]))
		lanes.append(lane)
	var site := CinderSite.new()
	site.name = definition.resource.to_pascal_case() + "Site"
	add_child(site)
	site.configure(SITE_DATA[definition.resource], origin + Vector3.UP * .05, sockets, lanes,
		origin + _point(definition.eye), origin + _point(definition.target))
	sites.append(site)

func _sign(origin: Vector3, next: Vector3, label: String) -> void:
	var along := origin.direction_to(next)
	var camp_exit: bool = origin == junctions.west or origin == junctions.south or origin == junctions.east
	var lead := 10.7 if camp_exit else 5.5
	var offset := along * lead + along.cross(Vector3.UP).normalized() * 2.65
	var mark := CinderWaymark.new()
	mark.position = origin + offset
	add_child(mark)
	mark.set_destination(label, along)
	for lettering: Label3D in mark.find_children("*", "Label3D", true, false):
		# A sign beside the orbit camera should never obscure the traveler.
		lettering.fixed_size = true
		lettering.pixel_size = .00053
		lettering.visibility_range_begin = 1.15
		lettering.visibility_range_begin_margin = .48

func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func get_sites() -> Array[CinderSite]:
	return sites

func landmark_positions(site_id: StringName) -> PackedVector3Array:
	return _landmarks.get(site_id, PackedVector3Array())

func observatory_cache_position() -> Vector3:
	var summit: Vector3 = junctions.east
	return summit + Vector3(0, .04, 7.65)

func activate_landmark(site_id: StringName, stage: int = 0) -> void:
	_camp_detail.activate(site_id, stage)

func set_landmark_progress(site_id: StringName, steps: int) -> void:
	_camp_detail.show_progress(site_id, steps)

func seed_life(value: int) -> void:
	_camp_detail.seed_life(value)

func nearby_shortcut(at: Vector3) -> String:
	for winch in _winches:
		if not winch.opened and at.distance_to(winch.handle) <= 3.3:
			return winch.title
	return ""

func try_open_shortcut(at: Vector3) -> bool:
	for winch in _winches:
		if not winch.opened and at.distance_to(winch.handle) <= 3.3:
			winch.set_open(true, true)
			return true
	return false

func unlocked_shortcut_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for winch in _winches:
		if winch.opened:
			ids.append(winch.code)
	return ids

func restore_shortcuts(ids: PackedStringArray) -> void:
	for winch in _winches:
		winch.set_open(ids.has(winch.code), false)

func shortcut_handle(id: String) -> Vector3:
	for winch in _winches:
		if winch.code == id:
			return winch.handle
	return Vector3.INF

## Follow the shortest available set of authored roads between two posted junctions.
func route_between_nodes(start_id: String, end_id: String) -> PackedVector3Array:
	if not junctions.has(start_id) or not junctions.has(end_id):
		return PackedVector3Array()
	var distances := {start_id: 0.0}
	var pending: Array[String] = [start_id]
	var reached_from := {}
	var edges := {}
	while not pending.is_empty():
		var here := pending[0]
		for candidate in pending:
			if distances[candidate] < distances[here]:
				here = candidate
		pending.erase(here)
		if here == end_id:
			break
		for i in roads.size():
			var record: Array = TRAILS.data.trails[i]
			if here != record[1] and here != record[3]:
				continue
			if not _road_is_open(record[0]):
				continue
			var reverse: bool = here == record[3]
			var next: String = record[1] if reverse else record[3]
			var cost := float(distances[here])
			var road := roads[i]
			for j in range(1,road.size()):
				cost += road[j-1].distance_to(road[j])
			if cost >= float(distances.get(next, INF)):
				continue
			distances[next] = cost
			reached_from[next] = here
			edges[next] = -(i + 1) if reverse else i + 1
			if not pending.has(next):
				pending.append(next)
	if not distances.has(end_id):
		return PackedVector3Array()
	var chain: Array[int] = []
	var cursor := end_id
	while cursor != start_id:
		chain.push_front(edges[cursor])
		cursor = reached_from[cursor]
	var points := PackedVector3Array([junctions[start_id]])
	for edge in chain:
		var section := roads[absi(edge) - 1].duplicate()
		if edge < 0:
			section.reverse()
		points.append_array(section.slice(1))
	return points

func _road_is_open(road: String) -> bool:
	for gate: Dictionary in LANDMARKS.data.gates:
		if gate.trail == road:
			return unlocked_shortcut_ids().has(gate.id)
	return true
