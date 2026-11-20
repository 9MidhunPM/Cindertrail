extends SceneTree
## Run after import: godot --headless --fixed-fps 60 --script tests/combat_smoke.gd

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(passed: bool, detail: String) -> void:
	if passed:
		print("PASS ", detail)
	else:
		failures += 1
		push_error("FAIL " + detail)

func _frames(count: int) -> void:
	for _frame in count:
		await physics_frame

func _run() -> void:
	set_meta(&"direct_journey", true)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var game = current_scene
	var battle: CinderBattle = game.battle
	var grove: CinderSite = game.grove
	var core: SunCore = game.core
	game.player.position = grove.anchor.global_position + Vector3(0, 0.10, 1.0)
	game.interact()
	await _frames(100)
	_check(core.form == SunCore.Form.DEPLOYED and game.start_wave(), "Deploy and deliberately engage the grove")
	var wet_speed := 0.0
	var dry_speed := 0.0
	var west_arrived := false
	var east_arrived := false
	for frame in 1100:
		await physics_frame
		for enemy in battle.enemies:
			var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
			if grove.wet_depth_at(enemy.global_position):
				wet_speed = maxf(wet_speed, speed)
			else:
				dry_speed = maxf(dry_speed, speed)
			if CinderEnemy.flat_distance(enemy.global_position, grove.anchor.global_position) < 1.6:
				if enemy.route[0].x < 0:
					west_arrived = true
				else:
					east_arrived = true
		if west_arrived and east_arrived:
			break
	_check(west_arrived and east_arrived, "Both authored wading lanes reach the defended island")
	_check(wet_speed > 0.4 and dry_speed > wet_speed * 1.25, "Crawlers slow in the water and recover on dry land")
	_check(core.health < 100 and core.restoration > 0, "Combat and extraction run together")
	var starting_scrap := battle.scrap
	_check(battle.place(0, 1) and battle.scrap == starting_scrap - 7, "Buying a slowing emitter debits its price")
	_check(not battle.place(0, 2) and not battle.place(19, 0) and battle.scrap == starting_scrap - 7, "Invalid placements are free")
	_check(battle.upgrade(0) and battle.scrap == starting_scrap - 13, "Upgrade purchased and attached to the module")
	var hp_at_pack := core.health
	Input.action_press("pack")
	await _frames(165)
	Input.action_release("pack")
	_check(core.form == SunCore.Form.CARRIED and core.health < hp_at_pack, "Packing under attack leaves the core vulnerable")
	var reserve := grove.remaining_energy
	var threat := grove.threat
	var funds := battle.scrap
	var active_count := battle.enemies.size()
	_check(not battle.active_wave and battle.towers.is_empty() and active_count > 0, "Packing recalls defenses and leaves pursuers alive")
	var pursuit := battle.enemies[0] if active_count > 0 else null
	var departure := pursuit.global_position if pursuit else Vector3.ZERO
	Input.action_press("move_back")
	Input.action_press("sprint")
	await _frames(65)
	Input.action_release("move_back")
	Input.action_release("sprint")
	await _frames(15)
	_check(is_instance_valid(pursuit) and pursuit.pursuing and departure.distance_to(pursuit.global_position) > 1.0, "Existing enemies pursue the traveler after packing")
	_check(battle.enemies.size() == active_count and grove.threat == threat and is_equal_approx(reserve, grove.remaining_energy), "Travel pauses spawning and extraction")
	# Move close enough to use the normal interaction again, isolating restoration
	# of the inventory from a second traversal of the checked approach.
	game.player.position = grove.anchor.global_position + Vector3(0,0.1,1)
	game.interact()
	await _frames(85)
	_check(battle.place(1, 1) and battle.towers[1].level == 2 and battle.scrap == funds, "Redeployment preserves the upgraded module without charging again")
	_check(grove.threat == threat and is_equal_approx(reserve, grove.remaining_energy), "Redeployment preserves local threat and reserve")
	print("Combat integration failures: ", failures)
	current_scene.queue_free()
	await _frames(3)
	quit(1 if failures > 0 else 0)
