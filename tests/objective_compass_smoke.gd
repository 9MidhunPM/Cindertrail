extends SceneTree
## Run from the project root with godot --headless --fixed-fps 60 --script tests/objective_compass_smoke.gd.

const MAIN := "res://scenes/main.tscn"
const GUIDE := preload("res://scripts/world/objective_route.gd")
const MOVEMENT := [&"move_left", &"move_right", &"move_forward", &"move_back"]

var _failures := PackedStringArray()
var _world: Node3D
var _guide: GUIDE

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load(MAIN) as PackedScene
	# Bound a startup failure rather than leaving a bad scene running indefinitely.
	if scene == null:
		quit(2)
		return
	for seed in [CinderJourneyLayout.LEGACY_SEED, 0, 1, 2]:
		var version := 0 if seed == CinderJourneyLayout.LEGACY_SEED else 2
		set_meta(&"direct_journey", true)
		set_meta(&"journey_seed", seed)
		set_meta(&"world_layout_version", version)
		_world = scene.instantiate()
		if _world.get_script() == null:
			_world.free()
			quit(2)
			return
		root.add_child(_world)
		_guide = GUIDE.new()
		_world.add_child(_guide)
		_guide.bind(_world)
		await _ticks(8)
		_check_destinations(seed)
		await _check_bridge(seed)
		await _check_bell(seed)
		_world.queue_free()
		await process_frame
	print("Objective compass failures: ", _failures)
	quit(0 if _failures.is_empty() else 1)

func _check_destinations(seed: int) -> void:
	var opening: Vector3 = _world.player.global_position
	var site_count := 0
	for camp: CinderSite in _world.sites:
		var reading := _guide.direction_to(opening, camp.anchor.global_position)
		if reading.point.is_finite() and reading.distance >= opening.distance_to(camp.anchor.global_position) - .02:
			site_count += 1
	var beacon: Vector3 = _world.beacon.global_position
	var summit := _guide.direction_to(opening, beacon)
	var void_reading := _guide.direction_to(opening - Vector3.UP * 25.0, beacon)
	_check(site_count == 7 and summit.point.is_finite() and summit.distance > opening.distance_to(beacon)
		and void_reading.point == Vector3.INF, "%d routes to every camp and summit, hides bearing in a void" % seed)

func _check_bridge(seed: int) -> void:
	var valley: CinderOuterValley = _world.outer_valley
	for bridge in [["bellmakers_cut", "cross", "terrace"], ["aqueduct_towpath", "ruins", "saddle"]]:
		var source: Vector3 = valley.junctions[bridge[1]]
		var destination: Vector3 = valley.junctions[bridge[2]]
		var closed := _guide.direction_to(source, destination)
		var lowered := valley.try_open_shortcut(valley.shortcut_handle(bridge[0]))
		var moving := _guide.direction_to(source, destination)
		await _ticks(94)
		var opened := _guide.direction_to(source, destination)
		_check(lowered and closed.distance >= 0.0 and moving == closed and opened.distance < closed.distance - 1.0,
			"%d reroutes only when %s is walkable" % [seed, bridge[0]])

func _check_bell(seed: int) -> void:
	var sockets: Dictionary = _world.grove_terrain.bell_road_sockets()
	var target: Vector3 = _world.beacon.global_position if sockets.end.z < 0 else _world.sites[1].anchor.global_position
	var closed := _guide.direction_to(sockets.start, target)
	_world.bell_road.apply_reserve(12.0, 25.0, false)
	await _ticks(3)
	var opened := _guide.direction_to(sockets.start, target)
	var deck: PackedVector3Array = _world.bell_road.compass_path()
	_check(closed.distance >= 0.0 and opened.distance < closed.distance - 3.0 and opened.point.distance_to(deck[1]) < .25,
		"%d newly raised Bell Road becomes the next bearing" % seed)
	if seed == 1:
		_world.player.global_position = sockets.start + Vector3.UP * .10
		_world.player.velocity = Vector3.ZERO
		_world.player.reset_physics_interpolation()
		await _ticks(15)
		await _follow_bell(target, sockets.end)

func _follow_bell(goal: Vector3, exit_point: Vector3) -> void:
	var highest := 0.0
	var reached := false
	for i in 640:
		var feet: Vector3 = _world.player.global_position
		highest = maxf(highest, feet.y)
		if feet.distance_to(exit_point) <= 1.05:
			reached = true
			break
		var reading := _guide.direction_to(feet, goal)
		if not reading.point.is_finite():
			break
		var direction: Vector3 = (reading.point - feet).slide(Vector3.UP).normalized()
		var right: Vector3 = _world.camera.global_basis.x.slide(Vector3.UP).normalized()
		var forward: Vector3 = -_world.camera.global_basis.z.slide(Vector3.UP).normalized()
		var x := direction.dot(right)
		var z := direction.dot(forward)
		var input := [-x, x, z, -z]
		for j in MOVEMENT.size():
			if input[j] > .02:
				Input.action_press(MOVEMENT[j], input[j])
			else:
				Input.action_release(MOVEMENT[j])
		await physics_frame
	for action in MOVEMENT:
		Input.action_release(action)
	_check(reached and highest >= 1.45, "Real traveler follows the changing bearing over the new deck")

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, text: String) -> void:
	if condition:
		print("PASS ", text)
	else:
		_failures.append(text)
		push_error(text)
