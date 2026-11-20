extends SceneTree

## Run with a temporary XDG_DATA_HOME. This test writes a real journey checkpoint.
var game: Node
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, detail: String) -> void:
	if condition:
		print("PASS ", detail)
	else:
		failures += 1
		push_error("FAIL " + detail)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _press(name: String) -> void:
	var button := game.find_child(name, true, false) as Button
	_check(button != null and button.is_visible_in_tree(), "Action visible: " + name)
	if button != null and button.is_visible_in_tree():
		button.pressed.emit()
	await process_frame

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Use a temporary XDG_DATA_HOME and set CINDERTRAIL_TEST_SAVE=1")
		quit(1)
		return
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	var front: CinderFrontEnd = game.get("_front_end")
	_check(front.get("stage") == &"menu" and not game.hud.visible, "Ordinary launch opens the title")
	var opening: Vector3 = game.player.position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(game.player.position.is_equal_approx(opening), "Title blocks movement")
	await _press("NewJourney")
	_check(front.get("stage") == &"comic", "New Journey opens the comic")
	await _press("NextPanel")
	_check(front.get("panel_index") == 1, "Comic advances")
	await _press("PreviousPanel")
	_check(front.get("panel_index") == 0, "Comic goes back")
	await _press("SkipIntro")
	await _frames(120)
	_check(front.get("stage") == &"hidden" and game.hud.visible, "Comic skip enters the world")
	_check(game.player.is_on_floor() and not JourneyCheckpoint.read().is_empty(), "First checkpoint is saved on safe ground")
	game.player.position = Vector3(-4.08, 0.84, 9)
	await _frames(20)
	game.interact()
	game.grove.threat = 4
	game.grove.remaining_energy -= 3.5
	game.core.restoration = 3.5
	game.core.health = 64.0
	game.battle.inventory.append({"kind": 0, "level": 2, "socket": -1})
	var scrap: int = game.battle.scrap
	game._save_checkpoint()
	var saved := JourneyCheckpoint.read()
	_check(saved.get("claimed", PackedStringArray()).size() == 1 and saved.get("health") == 64.0, "Checkpoint records supply pickup and core damage")
	game.player.position = game.grove.anchor.global_position + Vector3(0, 0.12, 2)
	await _frames(8)
	game.interact()
	await _frames(85)
	game.start_wave()
	await _frames(50)
	game._save_checkpoint()
	_check(JourneyCheckpoint.read() == saved, "An active defense cannot replace the safe checkpoint")
	game.core.damage(999)
	game._hud_action(&"checkpoint")
	await scene_changed
	game = current_scene
	await _frames(15)
	_check(game.core.health == 64.0 and game.core.restoration == 3.5, "Retry restores health and extraction")
	_check(game.grove.threat == 4 and game.grove.remaining_energy == saved.sites[game.grove.checkpoint_id].reserve, "Retry restores finite reserve and threat")
	_check(game.battle.scrap == scrap and game.battle.inventory.size() == 1 and game.battle.inventory[0].level == 2, "Retry restores the upgraded packed module and economy")
	_check(game.core.get_parent() == game.player.visual.carry_anchor, "Retry returns the core to the harness")
	game._hud_action(&"title")
	await scene_changed
	game = current_scene
	await _press("ContinueJourney")
	_check(game.core.restoration == 3.5 and game.hud.visible, "Continue resumes from the same checkpoint")
	quit(1 if failures else 0)
