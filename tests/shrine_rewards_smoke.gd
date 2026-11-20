extends "res://tools/qa/runtime.gd"
## Use an isolated XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1.

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Run with an isolated XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1")
		quit(2)
		return
	var saved := {
		"restoration": 99.9,
		"sites": {"flooded_grove": {"reserve": .65}, "lanternwood": {"reserve": 0.0}},
	}
	_check(JourneyCheckpoint.write(saved), "Write an isolated checkpoint from before shrine rewards")
	await _continue_journey()
	_check(game.battle.upgrade_cap == 4 and game.arts.selected_id() == &"lanternwood",
		"A depleted legacy shrine grants its cap and equips Mothward")
	var sun_id: int = game.core.get_instance_id()
	_position_player(game.grove.anchor.global_position + Vector3(0, .12, 1.85))
	await _physics_frames(10)
	game.interact()
	if not await _wait_mode("Prepare", 150):
		_close.call_deferred(1)
		return
	_check(game.start_wave(), "A normal defense begins below 100 percent")
	Input.action_press("pack")
	game.pack_step(.01)
	await _physics_frames(40)
	_check(is_equal_approx(game.grove.remaining_energy, .65) and game.battle.enemies.is_empty(),
		"Packing before the first spawn cannot draw energy from a held wave")
	Input.action_release("pack")
	await _physics_frames(40)
	var reserve: float = game.grove.remaining_energy
	var threat: int = game.grove.threat
	var remaining: int = game.battle.remaining_spawns
	_check(game.core.restoration == 100.0 and is_equal_approx(reserve, .55) and game.battle.held
		and game.battle.upgrade_cap == 4, "Filling the sun pauses the wave and preserves the unfinished reserve")
	_check(game.start_wave() and game.battle.post_restoration
		and game.grove.threat == threat and game.battle.remaining_spawns == remaining,
		"Space explicitly resumes the active wave with the same spawns")
	await _physics_frames(135)
	_check(game.core.restoration == 100.0 and game.grove.remaining_energy == 0.0
		and game.battle.upgrade_cap == 5 and game.mode == game.Mode.PREPARE,
		"Optional depletion grants exactly one additional cap")
	_check(not game.start_wave() and game.battle.upgrade_cap == 5, "A spent shrine cannot grant its reward again")
	for enemy: CinderEnemy in game.battle.enemies.duplicate():
		game.battle._hit(enemy, 10000.0, &"melee")
	await _pack()
	_check(game.core.get_instance_id() == sun_id and game.core.form == SunCore.Form.CARRIED,
		"Packing after optional extraction carries the original sun")
	_action("cycle_ability")
	_check(game.arts.selected_id() == &"flooded_grove", "Q cycles to the new Grove ability")
	_action("cycle_ability")
	_action("cast_ability")
	var cooldown: float = game.arts.remaining_seconds()
	var health: float = game.core.health
	game.core.damage(10.0)
	_check(cooldown > 0.0 and is_equal_approx(game.core.health, health - 2.0),
		"G activates Mothward and absorbs only its fixed damage budget")
	await _physics_frames(135)
	game._save_checkpoint()
	var resumed := JourneyCheckpoint.read()
	_check(resumed.get("ability_selected") == &"lanternwood" and resumed.get("ability_cooldown", 0.0) > 0.0,
		"Safe travel saves equipped ability and cooldown")
	await _continue_journey()
	_check(game.battle.upgrade_cap == 5 and game.arts.selected_id() == &"lanternwood"
		and game.arts.remaining_seconds() > 0.0 and game.grove.remaining_energy == 0.0,
		"Continue restores both rewards, equipment choice and cooldown")
	_check(_core_count() == 1 and game.core.form == SunCore.Form.CARRIED,
		"Continue still instantiates exactly one carried core")
	_close.call_deferred(0 if failures.is_empty() else 1)

func _continue_journey() -> void:
	set_meta(&"journey_entry", &"continue")
	change_scene_to_file(MAIN)
	await scene_changed
	game = current_scene
	await _physics_frames(12)

func _action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	game._unhandled_input(press)
