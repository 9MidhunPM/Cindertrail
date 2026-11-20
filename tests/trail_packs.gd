extends SceneTree
## Verify a bypass, sparked ambush, leash, partial clear and saved one-time reward on actual terrain.

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, detail: String) -> void:
	print("PASS " if value else "FAIL ", detail)
	if not value:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", 945)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await frames(5)
	var game = current_scene
	var packs = game.trail_packs
	var battle: CinderBattle = game.battle
	_check(packs._dens.size() == 6, "Six authored turnoffs include both seeded frontier branches")
	var floor_ok := true
	for site in packs._dens:
		for i in site.pack.size():
			var bed: Vector3 = site.bed(i)
			var ray := PhysicsRayQueryParameters3D.create(bed + Vector3.UP * 3, bed - Vector3.UP * .82, 1)
			var floor_hit := game.player.get_world_3d().direct_space_state.intersect_ray(ray) as Dictionary
			if floor_hit.is_empty() or absf(float(floor_hit.position.y) - bed.y) > .34:
				print("Uneven roost ", site.key, " at ", bed, ": ", floor_hit.get("position"))
				floor_ok = false
	_check(floor_ok, "The sleeping packs rest on walkable ground at all six turnoffs")
	var den = packs._dens[0]
	for candidate in packs._dens:
		if candidate.pack.size() > 1:
			den = candidate
			break
	var shoulder: Vector3 = den.to_global(Vector3(0, .3, 0))
	game.player.global_position = shoulder
	await frames(12)
	_check(den.scouting and battle.enemies.is_empty() and not den._resting.is_empty(),
		"The through-road exposes tracks and resting silhouettes without starting combat")
	var origin := shoulder + Vector3.UP * .8
	var aim: Vector3 = origin.direction_to(den.bed(0) + Vector3.UP * den.pack[0].height * .5)
	packs.provoke_by_aim(origin, aim)
	var member_count: int = den.pack.size()
	_check(battle.enemies.size() == member_count and not battle.active_wave,
		"An aimed spark provokes the visible pack without starting a defense wave")
	if battle.enemies.is_empty():
		quit(1)
		return
	var shot_target := battle.enemies[0]
	var health_before := shot_target.health
	battle.attack(origin, aim)
	_check(shot_target.health < health_before, "The first spark hits the newly alerted creature")
	var funds := battle.scrap
	var hit_count := battle.melee(shot_target.global_position, Vector3.FORWARD, .4, PI, 120, 0)
	_check(hit_count == 1 and battle.scrap == funds and int(packs.progress().get(den.key, 0)) == 1,
		"A partial clear records the defeated member without awarding the pack reward")
	game.player.global_position = shoulder + Vector3.UP * 58
	await frames(15)
	_check(battle.enemies.is_empty() and battle.scrap == funds, "Escaping the pack releases the pursuit and its budget")
	game.player.global_position = shoulder
	await frames(12)
	game.player.global_position = den.center() + Vector3.UP * .15
	await frames(14)
	_check(battle.enemies.size() == member_count - 1, "Walking onto the turnoff re-engages only surviving pack members")
	battle.melee(den.center(), Vector3.FORWARD, 8, PI, 120, 0)
	var paid := battle.scrap
	var carried: Dictionary = packs.progress()
	_check(den.claimed and paid == funds + 4 + member_count * 2, "Clearing the last survivor pays exactly one reward")
	packs.restore_progress(carried)
	game.player.global_position = shoulder
	await frames(10)
	game.player.global_position = den.center()
	await frames(12)
	_check(battle.enemies.is_empty() and battle.scrap == paid and den.claimed,
		"Restoring the encounter record keeps a cleared turnoff empty")
	_check(not battle.engaged and game.grove.threat == 0 and game.core.restoration == 0,
		"Trail combat preserves camp threat and restoration")
	print("Trail pack failures: ", failures)
	quit(1 if failures > 0 else 0)
