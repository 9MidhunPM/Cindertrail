extends SceneTree
## Retries an endgame save through normal title and defeat actions. Pass -- --generated
## to use a newly rolled layout. Use a temporary XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1.
var game: Node
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> bool:
	print("PASS " if value else "FAIL ", message)
	if not value:
		failures += 1
	return value

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _steer(target: Vector3) -> void:
	var offset: Vector3 = (target - game.player.global_position).slide(Vector3.UP)
	var direction := offset.normalized() if offset.length() > .26 else Vector3.ZERO
	var side: Vector3 = game.camera.global_basis.x.slide(Vector3.UP).normalized()
	var ahead: Vector3 = -game.camera.global_basis.z.slide(Vector3.UP).normalized()
	var actions := ["move_left", "move_right", "move_forward", "move_back"]
	var amounts := [-direction.dot(side), direction.dot(side), direction.dot(ahead), -direction.dot(ahead)]
	for i in actions.size():
		if amounts[i] > 0.0:
			Input.action_press(actions[i], amounts[i])
		else:
			Input.action_release(actions[i])

func _run() -> void:
	if OS.get_environment("CINDERTRAIL_TEST_SAVE") != "1":
		quit(2)
		return
	set_meta(&"journey_entry", &"title")
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	var entered := CinderRelay.SUMMIT + Vector3(0, .23, 1.6)
	var endgame := {"restoration": 100.0, "health": 77.0, "scrap": 0,
		"position": entered, "inventory": [{"socket": -1, "kind": 0, "level": 2}]}
	var generated := OS.get_cmdline_user_args().has("--generated")
	if generated:
		game._begin_journey()
		entered = game.beacon.global_position + Vector3(0, .23, 1.6)
		game._store_checkpoint(entered)
		var fresh := JourneyCheckpoint.read()
		endgame.position = entered
		fresh.merge(endgame, true)
		endgame = fresh
	JourneyCheckpoint.write(endgame)
	game._hud_action(&"checkpoint")
	await scene_changed
	game = current_scene
	await _frames(15)
	_check(game.core.restoration == 100.0 and not game.summit.cleared, "Loaded journey restores the sun and leaves the required summit ahead")
	game.interact()
	await _frames(85)
	_check(game.active_site == game.summit.site and game.mode == game.Mode.PREPARE, "Beacon opens tactical preparation before delivery")
	_check(game.core.form == SunCore.Form.DEPLOYED and game.battle.place(0, 0), "Single deployed sun and carried module on a crown socket")
	if not _check(game.start_wave(), "Guardian enters the first defense"):
		quit(1)
		return
	await _frames(32)
	Input.action_press("pack")
	await _frames(180)
	Input.action_release("pack")
	_check(game.mode == game.Mode.TRANSIT and game.battle.enemies.is_empty() and game.core.form == SunCore.Form.CARRIED,
		"Retreat resets the unfinished guardian and packs the same sun")
	game.interact()
	await _frames(85)
	game.battle.place(0, 0)
	game.start_wave()
	# Idle tower fire puts real damage into plating, but cannot break a shoulder.
	var idle_low := 340.0
	for i in 8000:
		if game.mode == game.Mode.LOSE or game.summit.cleared:
			break
		idle_low = minf(idle_low, game.summit.guardian.health)
		await physics_frame
	_check(idle_low < 335.0 and not game.summit.cleared and game.mode == game.Mode.LOSE,
		"A firing tower and idle traveler lose to the guardian's actual pulses")
	_check(game.mode == game.Mode.LOSE and game._checkpoint.health == 77.0, "Defeat retains the pre-fight checkpoint")
	game._hud_action(&"checkpoint")
	await scene_changed
	game = current_scene
	await _frames(12)
	_check(game.core.health == 77.0 and game.core.form == SunCore.Form.CARRIED and game.battle.scrap == 0,
		"Retry restores the arrival health, zero scrap and carried sun")
	var original: int = game.core.get_instance_id()
	game.interact()
	await _frames(85)
	game.start_wave()
	# First deliberately miss a brace at full pressure. Then use only the
	# traveler's starter sparks, analog movement and the ring's walkable gap.
	var pulses := 0
	for i in 420:
		if game.core.health < 77.0:
			break
		await physics_frame
	if _check(game.core.health == 68.0, "The first missed pulse deals nine damage to the deployed sun"):
		pulses = 1
	var stages := {}
	var sides := {}
	var saw_ring := false
	var saw_offset := false
	var escort := false
	var fight_frames := 0
	var previous_health: float = game.core.health
	for i in 11000:
		if game.summit.cleared or game.mode == game.Mode.LOSE:
			break
		var boss = game.summit.guardian
		stages[boss.stage] = true
		saw_ring = saw_ring or boss.phase == boss.Phase.RING
		saw_offset = saw_offset or boss.phase == boss.Phase.OFFSET_CHARGE
		if boss.phase == boss.Phase.OPEN:
			sides[boss.shoulder_direction().z] = true
		_steer(boss.counter_position())
		var target: CinderEnemy = boss
		for enemy in game.battle.enemies:
			if enemy != boss:
				escort = true
				if boss.phase != boss.Phase.BRACE:
					target = enemy
				break
		if not game.player.is_staggered():
			var from: Vector3 = game.player.global_position + Vector3.UP * 1.13
			game.battle.attack(from, from.direction_to(target.body_center()))
		fight_frames += 1
		if game.core.health < previous_health and boss.phase == boss.Phase.PULSE:
			pulses += 1
		previous_health = game.core.health
		await physics_frame
	_steer(game.player.global_position)
	print("Guardian starter fight %.1fs after deliberate first miss; core %.1f, pulses %d" %
		[fight_frames / 60.0, game.core.health, pulses])
	_check(stages.size() == 3 and sides.size() == 2 and saw_ring and saw_offset and escort,
		"Both shoulders, the rising ring, offset charge and escort lanes appeared across three stages")
	if not _check(game.summit.cleared and game.mode == game.Mode.PREPARE,
		"An active traveler with zero scrap, zero installed modules and starter sparks wins"):
		quit(1)
		return
	await _frames(3)
	_check(JourneyCheckpoint.read().get("guardian_cleared", false) and game.battle.enemies.is_empty(),
		"The cleared summit persists and its escorts scatter")
	game.player.global_position = game.beacon.global_position + Vector3(0, .15, 1.55)
	game.interact()
	await _frames(100)
	_check(game.mode == game.Mode.WIN and game.core.get_parent() == game.beacon
		and game.core.form == SunCore.Form.DELIVERED and game.core.get_instance_id() == original,
		"Delivery places the original sun in the cradle")
	_check(game.finale.active and JourneyCheckpoint.read().get("guardian_cleared", false),
		"Closing during the ending retains the guardian-cleared checkpoint")
	await _frames(175)
	_check(game.atmosphere.sunrise, "The first painted beat wakes daylight across the valley")
	game._hud_action(&"title")
	await scene_changed
	game = current_scene
	game._continue_journey()
	await _frames(8)
	_check(game.summit.cleared and game.core.form == SunCore.Form.CARRIED and game.core.restoration == 100.0,
		"Continue after an interrupted ending returns to the cleared crown")
	var restored_id: int = game.core.get_instance_id()
	game.interact()
	_check(game.mode == game.Mode.WIN and game.finale.active, "The resumed traveler delivers without repeating the guardian")
	game.finale.skip()
	_check(game.core.get_instance_id() == restored_id and game.core.get_parent() == game.beacon,
		"Immediate skip places the resumed core in the cradle")
	_check(JourneyCheckpoint.read().is_empty() and game.hud.visible,
		"Skipping the ending settles dawn, clears the completed journey, and reveals the results")
	quit(1 if failures else 0)
