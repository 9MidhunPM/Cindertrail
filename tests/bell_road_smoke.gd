extends "res://tools/qa/runtime.gd"
## CINDERTRAIL_TEST_SAVE=1 XDG_DATA_HOME=<temporary folder> godot --headless --fixed-fps 60 -s tests/bell_road_smoke.gd

var rises := 0
var openings := 0

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Run with an isolated XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1")
		quit(2)
		return
	# Version-one journey from before this landmark existed. The rest of the sun's
	# charge came from other sites, so total restoration cannot stand in for local draw.
	var legacy := {"restoration": 43.0, "health": 93.0,
		"sites": {"flooded_grove": {"reserve": 14.0, "threat": 1}}}
	if not _check(JourneyCheckpoint.write(legacy), "Write the isolated legacy checkpoint"):
		quit(1)
		return
	await _continue_from_title()
	var road: Node3D = game.bell_road
	var route := _world_route()
	var sun_id: int = game.core.get_instance_id()
	_check(not road.awakened and not road.walkable and _floor_at(route[1]).y < route[1].y - .45,
		"Legacy reserve above halfway loads submerged with no solid crest")
	await _dry_detour(route)
	await _start_grove_defense()
	await _physics_frames(120)
	_check(_core_count() == 1 and game.core.get_instance_id() == sun_id
		and game.core.get_parent() == game.grove.anchor, "Deployment transfers the same sun to the site")
	var first_reserve: float = game.grove.remaining_energy
	_check(first_reserve < 14.0 and first_reserve > 12.5 and not road.awakened,
		"First defense draws energy while the bell stays submerged")
	await _pack()
	_check(game.grove.remaining_energy > 12.5 and not road.awakened and _core_count() == 1
		and game.core.get_instance_id() == sun_id and game.core.form == SunCore.Form.CARRIED,
		"Early retreat carries the original sun and preserves partial extraction")
	await _start_grove_defense()
	for tick in 300:
		if game.grove.remaining_energy <= 12.5 + .00001:
			break
		if road.awakened:
			_check(false, "Bell rose before 12.5 reserve")
			break
		await physics_frame
	_check(road.awakened and rises == 1 and not road.walkable and game.battle.active_wave,
		"Cumulative halfway draw begins one reveal during the second live attack")
	for tick in 300:
		if road.walkable:
			break
		await physics_frame
	_check(road.walkable and openings == 1 and _floor_at(route[1]).y > route[1].y - .25,
		"Raised road has a solid crest after the animation")
	await _pack()
	_check(game.core.get_instance_id() == sun_id and _core_count() == 1
		and game.core.get_parent() == game.player.visual.carry_anchor,
		"The revealed road leaves the single sun in the backpack on retreat")
	# Quiet the arena for the checkpoint and give the crossing a single traceable pursuer.
	for enemy: CinderEnemy in game.battle.enemies.duplicate():
		game.battle._hit(enemy, 100000, &"melee")
	await _physics_frames(15)
	await _cross_with_pursuer(route)
	await _walk_route(Array(_reversed(route)), "first seeded span on foot in reverse")
	await _physics_frames(120)
	game._save_checkpoint()
	var record := JourneyCheckpoint.read()
	var reserve: float = game.grove.remaining_energy
	_check(record.get("sites", {}).get(game.grove.checkpoint_id, {}).get("reserve", -1.) == reserve
		and record.get("restoration", 0.) == game.core.restoration,
		"Safe checkpoint writes the actual remaining reserve under the stable Grove ID")
	await _continue_from_title()
	_check(game.bell_road.walkable and rises == 0 and openings == 0 and game.grove.remaining_energy == reserve
		and _world_route() == route and _core_count() == 1,
		"Continue silently restores the same crossing and sun")
	var other_seed := int(record.get("journey_seed", 34519)) ^ 1
	var old_halfway := {"journey_seed": other_seed, "restoration": 12.5,
		"sites": {"flooded_grove": {"reserve": 12.5, "threat": 2}}}
	_check(JourneyCheckpoint.write(old_halfway), "Write pre-landmark save at exactly half capacity")
	await _continue_from_title()
	var other_route := _world_route()
	_check(game.bell_road.walkable and rises == 0 and openings == 0 and other_route != route,
		"Equality restores the alternate seed's crossing immediately")
	_place(other_route[0])
	await _walk_route(Array(other_route), "second seeded span on foot")
	await _walk_route(Array(_reversed(other_route)), "second seeded span on foot in reverse")
	await _dry_detour(other_route)
	await _southern_shrine(other_seed)
	print("BELL_ROAD_SMOKE ", failures)
	_close.call_deferred(0 if failures.is_empty() else 1)

func _southern_shrine(start_seed: int) -> void:
	var seed_value := start_seed
	var layout := CinderJourneyLayout.generate(seed_value)
	while layout.clearing(&"flooded_grove") != 1:
		seed_value += 1
		layout = CinderJourneyLayout.generate(seed_value)
	var record := layout.checkpoint_fields()
	record["restoration"] = 15.0
	record["sites"] = {&"flooded_grove": {"reserve": 12.59, "threat": 2}}
	_check(JourneyCheckpoint.write(record), "Write southern-shrine seeded layout and stable reserve")
	await _continue_from_title()
	var route := _world_route()
	_check(route[-1].z < -10. and not game.bell_road.awakened,
		"Southern shrine uses the western-to-northern passage")
	game.director.reduced_motion = true
	await _start_grove_defense()
	await _physics_frames(53)
	_check(game.bell_road.walkable and rises == 1 and openings == 1,
		"Reduced motion opens the southern bell road once during active extraction")
	await _pack()
	_check(rises == 1 and openings == 1, "A continuing draw and completed pack do not repeat the reduced-motion reveal")
	for enemy: CinderEnemy in game.battle.enemies.duplicate():
		game.battle._hit(enemy, 100000, &"melee")
	await _dry_detour(route)
	await _cross_with_pursuer(route)
	await _walk_route(Array(_reversed(route)), "southern shrine's northern span in reverse")

func _continue_from_title() -> void:
	change_scene_to_file(MAIN)
	await scene_changed
	game = current_scene
	var resume := game.find_child("ContinueJourney", true, false) as Button
	_check(resume != null and resume.is_visible_in_tree(), "Continue Journey is available from title")
	rises = 0
	openings = 0
	node_added.connect(_observe_road)
	resume.pressed.emit()
	node_added.disconnect(_observe_road)
	await _physics_frames(15)

func _observe_road(node: Node) -> void:
	if node.has_signal(&"raised") and node.has_signal(&"opened"):
		node.connect(&"raised", func(): rises += 1)
		node.connect(&"opened", func(): openings += 1)

func _world_route() -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector3 in game.bell_road.route:
		result.append(game.bell_road.to_global(point))
	return result

func _reversed(route: PackedVector3Array) -> PackedVector3Array:
	var result := route.duplicate()
	result.reverse()
	return result

func _floor_at(point: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3., point - Vector3.UP * 3., 1)
	var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("position", Vector3.DOWN * 100.)

func _place(point: Vector3) -> void:
	_position_player(point + Vector3.UP * .12)
	game.player.recovery_point = point + Vector3.UP * .12

func _start_grove_defense() -> void:
	_place(game.grove.anchor.global_position + Vector3.BACK * 1.5)
	await _physics_frames(10)
	game.interact()
	await _wait_mode("Prepare", 180)
	_check(game.start_wave(), "Start an organized Grove attack")

func _dry_detour(route: PackedVector3Array) -> void:
	var center: Vector3 = game.grove.anchor.global_position
	var west_arm := [Vector3(-9,.70,2), center + Vector3(-4.4, 0, 1)]
	var south_arm := [Vector3(-2.6,.70,10), center + Vector3(.2, 0, 4.5)]
	var north_arm := [Vector3(2,.70,-12.5), center + Vector3(.5, 0,-4.4)]
	var first_arm: Array = south_arm if route[0].z > 7.0 else west_arm
	var second_arm: Array = west_arm if route[-1].z > -5.0 else north_arm
	second_arm = second_arm.duplicate()
	second_arm.reverse()
	var dry := [route[0]] + first_arm + [center] + second_arm + [route[-1]]
	_place(route[0])
	await _physics_frames(12)
	var wet_ticks := [0]
	var check_wet := func() -> void:
		if game.grove.wet_depth_at(game.player.global_position):
			wet_ticks[0] += 1
	physics_frame.connect(check_wet)
	await _walk_route(dry, "original causeways between the bell road's landings")
	physics_frame.disconnect(check_wet)
	_check(wet_ticks[0] == 0, "The old detour stays dry end to end")

func _cross_with_pursuer(route: PackedVector3Array) -> void:
	_place(route[0])
	await _physics_frames(12)
	var enemy: CinderEnemy = game.battle.spawn_roamer(CinderBattle.CRAWLER, route[0], route[0])
	if not _check(enemy != null, "Register a live pursuing crawler"):
		return
	await _walk_to(route[1])
	_check(game.player.is_on_floor() and absf(game.player.global_position.y - route[1].y) < .35,
		"Traveler stands on the raised crest in ordinary exploration controls")
	# Move beyond the crest so the crawler reaches the crown before stopping at attack range.
	await _walk_to(route[1].move_toward(route[-1], 1.9))
	for frame in 420:
		if enemy.global_position.distance_to(route[1]) < 1.75:
			break
		await physics_frame
	print("BELL_ROAD_PURSUIT crest=", route[1], " crawler=", enemy.global_position, " sun=", game.core.global_position)
	_check(enemy.global_position.distance_to(route[1]) < 1.75 and enemy.global_position.y > route[1].y - .4,
		"Crawler follows the traveler's breadcrumbs onto the raised crest")
	await _walk_to(route[-1])
	for frame in 420:
		if CinderEnemy.flat_distance(enemy.global_position, game.core.global_position) < 1.4:
			break
		await physics_frame
	print("BELL_ROAD_PURSUIT landing=", route[-1], " crawler=", enemy.global_position, " sun=", game.core.global_position)
	_check(CinderEnemy.flat_distance(enemy.global_position, route[-1]) < 2.5 and enemy.is_on_floor(),
		"Live pursuer reaches the far landing")
	game.battle._hit(enemy, 100000, &"melee")
