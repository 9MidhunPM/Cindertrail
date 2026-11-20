extends Node
## Routes the objective bearing along the valley's authored walking surfaces.

const NO_ROUTE := {"point": Vector3.INF, "distance": -1.0}
const OPEN_DISTANCE := 0.55
const PICKUP_DISTANCE := 18.0
const APPROACH_STEP := 0.78

const OUTER_CAMPS := {
	&"lanternwood": "west", &"sunken_aqueduct": "south", &"sunwatch_observatory": "east",
}

var _world: Node3D
var _valley: CinderOuterValley
var _graph := AStar3D.new()
var _points: Dictionary[Vector3, int] = {}
var _segments: Array[Vector2i] = []
var _gate_signature := PackedStringArray()
var _bell_open := false
var _last_origin := Vector3.INF
var _last_goal := Vector3.INF
var _last_reading := NO_ROUTE

func bind(world: Node3D) -> void:
	_world = world
	_valley = world.outer_valley
	_rebuild()

func direction_to(origin: Vector3, goal: Vector3) -> Dictionary:
	if not is_instance_valid(_valley) or not origin.is_finite() or not goal.is_finite():
		return NO_ROUTE
	if _gate_signature != _valley.compass_crossings() or _bell_open != _world.bell_road.walkable:
		_rebuild()
	if _last_goal == goal and _last_origin.distance_squared_to(origin) < OPEN_DISTANCE * OPEN_DISTANCE:
		return _last_reading
	var route := _walk_route(origin, goal)
	_last_origin = origin
	_last_goal = goal
	_last_reading = NO_ROUTE
	if route.is_empty():
		return _last_reading
	var distance := 0.0
	var bearing := Vector3.INF
	for i in range(1, route.size()):
		distance += route[i - 1].distance_to(route[i])
		if bearing == Vector3.INF and _flat_distance(origin, route[i]) >= .9:
			bearing = route[i]
	_last_reading = {"point": goal if bearing == Vector3.INF else bearing, "distance": distance}
	return _last_reading

func _rebuild() -> void:
	_graph.clear()
	_points.clear()
	_segments.clear()
	_gate_signature = _valley.compass_crossings()
	_bell_open = _world.bell_road.walkable
	_last_origin = Vector3.INF
	var outside := _valley.compass_paths()
	for path in outside:
		_add_path(path)
	# The fork mesh endpoints use surveyed deck elevations. Preserve them and
	# join to their matching, explicitly posted trailheads.
	for fork: Dictionary in _valley.active_forks.values():
		_link(fork.points[0], _valley.junctions[fork.start])
		_link(fork.points[-1], _valley.junctions[fork.end])
	for side_street: PackedVector3Array in _valley.town_side_paths.values():
		_add_path(side_street)
		_link_to_paths(side_street[0], outside, 1.4)
		_link_to_paths(side_street[-1], outside, 1.4)
	for site: CinderSite in _world.sites:
		if OUTER_CAMPS.has(site.checkpoint_id):
			_link(_valley.junctions[OUTER_CAMPS[site.checkpoint_id]], site.anchor.global_position)
	_add_districts()
	for path: PackedVector3Array in _world.frontier.paths:
		_add_path(path)
	_link(_world.frontier.paths[1][-1], _world.frontier.site.anchor.global_position)

func _add_districts() -> void:
	var grove: CinderGrove = _world.grove_terrain
	var grove_paths := grove.map_paths()
	var exits := ["grove", "grove_west", "grove_north"]
	for i in grove_paths.size():
		var path := grove_paths[i]
		_add_path(path)
		_link(path[0], _valley.junctions[exits[i]])
	if _bell_open:
		var deck: PackedVector3Array = _world.bell_road.compass_path()
		_add_path(deck)
		_link_to_paths(deck[0], grove_paths, 1.1)
		_link_to_paths(deck[-1], grove_paths, 1.1)
	for district: Node3D in _world.districts:
		if district is CinderQuarry:
			var paths: Array[PackedVector3Array] = district.map_paths()
			for path in paths:
				_add_path(path)
			_link(paths[0][0], _valley.junctions.quarry_gate)
			_link_to_paths(paths[1][0], [paths[0]], .9)
			_link(paths[1][-1], _valley.junctions.quarry)
		elif district is CinderRelay:
			var paths: Array[PackedVector3Array] = district.compass_paths()
			for path in paths:
				_add_path(path)
			_link(paths[0][0], _valley.junctions.relay_gate)
			_link(paths[3][0], _valley.junctions.relay)
			_link(paths[1][-1], _world.beacon.global_position)

func _add_path(path: PackedVector3Array) -> void:
	for i in range(1, path.size()):
		_link(path[i - 1], path[i])

func _link(a: Vector3, b: Vector3) -> void:
	if a == b:
		return
	var left := _point(a)
	var right := _point(b)
	if not _graph.are_points_connected(left, right):
		_graph.connect_points(left, right)
		_segments.append(Vector2i(left, right))

func _point(location: Vector3) -> int:
	if not _points.has(location):
		var id := _points.size()
		_points[location] = id
		_graph.add_point(id, location)
	return _points[location]

func _link_to_paths(join: Vector3, paths: Array, limit: float) -> void:
	var best := limit * limit
	var match_segment := PackedVector3Array()
	var projection := Vector3.ZERO
	for path: PackedVector3Array in paths:
		for i in range(1, path.size()):
			var on_path := Geometry3D.get_closest_point_to_segment(join, path[i - 1], path[i])
			var separation := join.distance_squared_to(on_path)
			if separation < best:
				best = separation
				projection = on_path
				match_segment = PackedVector3Array([path[i - 1], path[i]])
	if match_segment.is_empty():
		return
	_link(join, projection)
	_link(match_segment[0], projection)
	_link(projection, match_segment[1])

func _walk_route(origin: Vector3, goal: Vector3) -> PackedVector3Array:
	if not _points.has(goal):
		return PackedVector3Array()
	var state := _world.get_world_3d().direct_space_state
	var level := _ground_at(state, origin, .28, 1.4)
	if level == Vector3.INF:
		return PackedVector3Array()
	if level.distance_to(goal) <= 3.0 and _walkable_strip(state, level, goal):
		return PackedVector3Array([origin, goal])
	var approaches: Array[Dictionary] = []
	for segment in _segments:
		var a := _graph.get_point_position(segment.x)
		var b := _graph.get_point_position(segment.y)
		var projection := Geometry3D.get_closest_point_to_segment(level, a, b)
		var cost := level.distance_squared_to(projection)
		if cost <= PICKUP_DISTANCE * PICKUP_DISTANCE:
			approaches.append({"point": projection, "cost": cost, "segment": segment})
	approaches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
	for candidate in approaches:
		var segment: Vector2i = candidate.segment
		var projection: Vector3 = candidate.point
		if not _walkable_strip(state, level, projection):
			continue
		var path := _route_on_segment(segment, projection, _points[goal])
		if not path.is_empty():
			path.insert(0, origin)
			return path
	return PackedVector3Array()

func _route_on_segment(segment: Vector2i, projection: Vector3, target_id: int) -> PackedVector3Array:
	var waypoint := _points.size()
	_graph.add_point(waypoint, projection)
	_graph.connect_points(waypoint, segment.x)
	_graph.connect_points(waypoint, segment.y)
	var path := _graph.get_point_path(waypoint, target_id)
	_graph.remove_point(waypoint)
	return path

func _walkable_strip(state: PhysicsDirectSpaceState3D, origin: Vector3, destination: Vector3) -> bool:
	var length := _flat_distance(origin, destination)
	if length < .3:
		return absf(origin.y - destination.y) < .7
	var lift := Vector3.UP * .84
	var rail := PhysicsRayQueryParameters3D.create(origin + lift, destination + lift, 1)
	if not state.intersect_ray(rail).is_empty():
		return false
	var count := maxi(1, ceili(length / APPROACH_STEP))
	var last := origin
	for i in range(1, count + 1):
		var sample := origin.lerp(destination, float(i) / count)
		var ground := _ground_at(state, sample, .45, .65)
		if ground == Vector3.INF or absf(last.y - ground.y) > .60:
			return false
		last = ground
	return true

func _ground_at(state: PhysicsDirectSpaceState3D, point: Vector3, above: float, below: float) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * above, point - Vector3.UP * below, 1)
	var hit := state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < .67:
		return Vector3.INF
	return hit.position

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
