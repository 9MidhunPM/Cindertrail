class_name CinderOuterValley
extends Node3D

const CLEARINGS := preload("res://scripts/world/outer_shrine_clearings.gd")
const FORK_DATA := preload("res://data/outer_valley/trail_forks.json")
const ENVIRONMENT := preload("res://scripts/world/exploration_environment.gd")
const NETWORK := preload("res://scripts/world/trail_network.gd")
const FORK_HUBS := {"pilgrims_cross": "cross", "orchard_pass": "saddle", "mineral_spring": "spring"}
const TOWN_WALKS := preload("res://scripts/world/town_cache_walks.gd")
const TOWN_TITLES := {"ruins": "Western Arcade", "terrace": "Bellmakers’ Steps", "spring": "Mineral Ward"}
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
## The original map named camp junctions by compass direction. These IDs now
## follow their camp when a layout places it in a different sector.
const DESTINATIONS := {
	"quarry": "Broken Quarry", "grove": "Flooded Grove", "relay": "Fallen Relay",
	"west": "Lanternwood", "south": "Sunken Aqueduct", "east": "Sunwatch Observatory",
	"cross": "Pilgrims’ Cross", "ruins": "Western Arcade", "terrace": "Bellmakers’ Terrace",
	"saddle": "Orchard Pass", "spring": "Mineral Spring",
	"grove_west": "Flooded Grove", "grove_north": "Flooded Grove",
	"quarry_gate": "Broken Quarry", "relay_gate": "Fallen Relay",
}

var layout_id := 0
var clearing_variants: Dictionary = {}
var journey_layout: CinderJourneyLayout
var abandoned_towns: Node3D
var active_forks: Dictionary = {}
var town_side_paths: Dictionary = {}
var _network := NETWORK.new()
var _graph: Dictionary
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
	_graph = CinderDistricts.graph(layout_id)
	var land_scene := load(CinderDistricts.landscape_path(layout_id)) as PackedScene
	var land := land_scene.instantiate()
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
	for key: String in _graph.nodes:
		junctions[key] = _point(_graph.nodes[key])
	var wood: Vector3 = junctions.west
	var sluice: Vector3 = junctions.south
	var summit: Vector3 = junctions.east
	_landmarks[&"lanternwood"] = PackedVector3Array([wood + Vector3(5, 0, -4)])
	_landmarks[&"sunken_aqueduct"] = PackedVector3Array([sluice + Vector3(6, 0, -5.5)])
	_landmarks[&"sunwatch_observatory"] = PackedVector3Array([
		summit + Vector3(-5.5, 0, 5), summit + Vector3(5.5, 0, 5)])
	add_child(_camp_detail)
	_camp_detail.setup(_landmarks, junctions)
	for trail: Array in _graph.trails:
		var route := PackedVector3Array([junctions[trail[1]]])
		for coord: Array in trail[2]:
			route.append(_point(coord))
		route.append(junctions[trail[3]])
		roads.append(route)
		road_names.append(trail[0])
		_sign(route[0], route[1], _destination(trail[3]))
		_sign(route[-1], route[-2], _destination(trail[1]))
	_build_trail_network(pigment)
	if journey_layout != null and journey_layout.version >= 2:
		abandoned_towns = ENVIRONMENT.new()
		add_child(abandoned_towns)
		abandoned_towns.build(junctions, journey_layout.town_variants, roads, road_names, journey_layout.journey_seed)
	for spec: Dictionary in LANDMARKS.data.sites:
		_create_camp(spec)
	for entry: Array in LANDMARKS.data.caches:
		cache_ids.append(entry[0])
		caches.append(junctions[entry[1]] + _point(entry[2]))
	if abandoned_towns != null:
		TOWN_WALKS.install(self, journey_layout)
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
	var spec: CinderSiteSpec = SITE_DATA[definition.resource]
	var variant := int(clearing_variants.get(spec.id, 0))
	definition = CLEARINGS.resolve(definition, variant, layout_id > 0)
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
	site.configure(spec, origin + _point(definition.get("anchor", [0, .05, 0])), sockets, lanes,
		origin + _point(definition.eye), origin + _point(definition.target))
	site.habitat_frame.origin = origin + Vector3.UP * .05
	if layout_id > 0:
		site.mark_clearing()
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

## Follow the shortest open route, including connectors between the selected fork landings.
func route_between_nodes(start_id: String, end_id: String) -> PackedVector3Array:
	return _network.between(start_id, end_id, unlocked_shortcut_ids(), junctions)

func _destination(key: String) -> String:
	if journey_layout != null and journey_layout.version >= 2 and TOWN_TITLES.has(key):
		return TOWN_TITLES[key]
	return DESTINATIONS[key]

func _build_trail_network(pigment: Material) -> void:
	var splits := {}
	if journey_layout != null and journey_layout.version >= 2:
		var library: Dictionary = FORK_DATA.data[str(layout_id)]
		for fork: String in CinderJourneyLayout.FORKS:
			var choice: int = journey_layout.fork_variants[fork]
			var branch: Dictionary = library[fork][choice]
			var points := PackedVector3Array()
			for coord: Array in branch.points:
				points.append(_point(coord))
			var mouths := PackedStringArray()
			var destinations := PackedStringArray()
			for key: String in ["start", "end"]:
				var socket: Array = branch[key]
				var trail_index := road_names.find(socket[0])
				var trail := roads[trail_index]
				var knot := posmod(int(socket[1]), trail.size())
				var id := "%s_approach" % fork if key == "start" else "%s_landing_%d" % [fork, choice]
				junctions[id] = trail[knot]
				if not splits.has(socket[0]):
					splits[socket[0]] = {}
				splits[socket[0]][knot] = id
				mouths.append(id)
				var original: Array = _graph.trails[trail_index]
				destinations.append(_destination(original[3] if original[1] == FORK_HUBS[fork] else original[1]))
			_network.add_edge(mouths[0], mouths[1], points)
			active_forks[fork] = {"name": branch.name, "start": mouths[0], "end": mouths[1], "points": points}
			roads.append(points)
			road_names.append(branch.name)
			var scene: PackedScene = load(branch.scene)
			var bridge := scene.instantiate() as Node3D
			bridge.name = String(branch.name).to_pascal_case()
			for part: MeshInstance3D in bridge.find_children("*", "MeshInstance3D", true, false):
				part.material_override = pigment
			add_child(bridge)
			_sign(points[0], points[1], branch.name + "\n" + destinations[1])
			_sign(points[-1], points[-2], branch.name + "\n" + destinations[0])
	for i in _graph.trails.size():
		var record: Array = _graph.trails[i]
		var points := roads[i]
		var knots: Dictionary = splits.get(record[0], {}).duplicate()
		knots[0] = record[1]
		knots[points.size() - 1] = record[3]
		var indexes := knots.keys()
		indexes.sort()
		for j in range(1, indexes.size()):
			var first: int = indexes[j - 1]
			var last: int = indexes[j]
			var gate_id := ""
			for gate: Dictionary in LANDMARKS.data.gates:
				if record[0] == gate.trail and first <= int(gate.section) and int(gate.section) < last:
					gate_id = gate.id
			_network.add_edge(knots[first], knots[last], points.slice(first, last + 1), gate_id)
