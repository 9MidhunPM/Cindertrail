extends SceneTree
## godot --headless --fixed-fps 60 -s tests/wave_entries.gd

const ENTRY := preload("res://scripts/combat/wave_entry.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(passed: bool, detail: String) -> void:
	if not passed:
		failures += 1
		push_error(detail)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _run() -> void:
	set_meta(&"direct_journey", true)
	for fixture in [[0, 0, &"flooded_grove"], [3, 0, &"flooded_grove"],
			[3, 1, &"broken_quarry"], [3, 2, &"sunken_aqueduct"]]:
		set_meta(&"world_layout_version", fixture[0])
		set_meta(&"journey_seed", fixture[1])
		change_scene_to_file("res://scenes/main.tscn")
		await scene_changed
		await _frames(8)
		var game := current_scene
		var extensions := 0
		for site: CinderSite in game.sites:
			extensions += _verify_routes(site)
			if site.checkpoint_id == fixture[2]:
				await _verify_raid(game, site)
		var expected := 30 if fixture[0] == 3 else 1
		_check(extensions >= expected, "Some wave entrances failed to extend in layout %s" % str(fixture))
		print("WAVE_ENTRIES ", fixture, " verified extra entrances ", extensions)
	current_scene.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)

func _verify_routes(site: CinderSite) -> int:
	var space := site.get_world_3d().direct_space_state
	var extensions := 0
	for lane in site.lanes:
		for spec: CinderEnemyStats in [CinderBattle.CRAWLER, CinderBattle.BRUTE]:
			var route := ENTRY.extend(space, lane, spec)
			if route == lane:
				continue
			extensions += 1
			_check(route.slice(1) == lane, "Moved an authored waypoint at " + site.label)
			var start := route[0]
			var distance := CinderEnemy.flat_distance(start, lane[0])
			_check(distance >= 1.0 and distance <= 3.61, "Invalid extension at " + site.label)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				start + Vector3.UP * .14, start - Vector3.UP * .14, 1))
			_check(not ground.is_empty() and absf(ground.position.y - start.y) < .02,
				"Spawn has no walkable ground at " + site.label)
	return extensions

func _verify_raid(game: Node, site: CinderSite) -> void:
	var core: SunCore = game.core
	var battle: CinderBattle = game.battle
	game.player.global_position = site.anchor.global_position + Vector3(0, .12, .85)
	game.interact()
	await _frames(100)
	var engaged: bool = core.form == SunCore.Form.DEPLOYED and game.start_wave()
	_check(engaged, "Could not start wave at " + site.label)
	if not engaged:
		return
	var lanes := {}
	var spawn_frames: Array[int] = []
	for tick in 850:
		await physics_frame
		if battle.enemies.size() > spawn_frames.size():
			spawn_frames.append(tick)
		for enemy in battle.enemies:
			if not enemy.counts_for_wave or lanes.has(enemy.origin_lane):
				continue
			lanes[enemy.origin_lane] = true
			var lane := site.lanes[enemy.origin_lane]
			var expected := ENTRY.extend(site.get_world_3d().direct_space_state, lane, enemy.stats)
			_check(enemy.route == expected, "Wave did not use the resolved entrance at " + site.label)
		if core.health < 100.0 and lanes.size() == site.lanes.size():
			break
	_check(core.health < 100.0, "Raid from the new entrance could not reach " + site.label)
	_check(lanes.size() == site.lanes.size(), "Raid skipped an existing lane at " + site.label)
	_check(spawn_frames.size() >= 2 and spawn_frames[1] - spawn_frames[0] <= 40,
		"Raid spawn cadence slowed at " + site.label)
	while battle.enemies.size() < CinderBattle.WAVES.active_limit:
		if not battle.spawn_roamer(CinderBattle.CRAWLER, site.lanes[0][0], site.lanes[0][1]):
			break
	_check(battle.enemies.size() == 18 and
		battle.spawn_roamer(CinderBattle.CRAWLER, site.lanes[0][0], site.lanes[0][1]) == null,
		"Raid and roaming enemies no longer share an 18-enemy limit")
