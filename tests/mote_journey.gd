extends SceneTree
## Follow the normal guide input through travel, deployment, a live wave and pause.

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	OS.set_environment("OPENAI_API_KEY", "")
	OS.set_environment("CINDERTRAIL_GUIDE_ONLINE", "0")
	OS.set_environment("CINDERTRAIL_GUIDE_VOICE", "0")
	set_meta(&"direct_journey", true)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	_expect(game.mote.visible and not game.mote_guide.online_available(), "Mote travels with the player offline")
	_ask(game)
	_expect(game.hud._guide_text.text.contains("compass"), "H explains the current trail objective")

	game.player.global_position = game.grove.anchor.global_position + Vector3.UP * 0.1
	game.player.velocity = Vector3.ZERO
	game.interact()
	_expect(game.mode == game.Mode.DEPLOY and game.hud._guide_text.text.is_empty(), "Deploy clears the trail subtitle")
	for tick in 240:
		if game.mode != game.Mode.DEPLOY:
			break
		await physics_frame
	_expect(game.mode == game.Mode.PREPARE and game.mote.visible, "Mote stays with the hero in the tactical view")
	_ask(game)
	_expect(game.hud._guide_text.text.contains("sockets"), "H switches to a local tower tip")

	var wave_started: bool = game.start_wave()
	_expect(wave_started and game.hud._guide_text.text.is_empty(), "The first wave clears the setup tip")
	_ask(game)
	_expect(game.hud._guide_text.text.contains("Ford bell") and game.hud._guide_text.text.contains("Press E"),
		"H explains the Grove's landmark during a wave")
	var wave_tip: String = game.hud._guide_text.text
	_expect(not game.hud.guide_voice_started("Outdated advice", 9.0), "Audio cannot replace a newer subtitle")
	_expect(game.hud.guide_voice_started(wave_tip, 12.0) and game.hud._guide_seconds >= 12.8
		and game.hud._guide_speaker.text == "Mote · AI voice", "Matching speech holds the caption through its measured duration")
	game._set_paused(true)
	_ask(game)
	_expect(not game.mote.visible and not game.hud._guide_panel.is_visible_in_tree()
		and game.hud._guide_text.text == wave_tip, "Pause hides Mote and suspends the current subtitle")
	game._set_paused(false)
	_expect(game.mote.visible and game.hud._guide_panel.is_visible_in_tree() and game.hud._guide_speaker.text == "Mote",
		"Mote and the current subtitle return without restarting interrupted audio")

	root.remove_child(game)
	game.free()
	quit(1 if _failures else 0)

func _ask(game: Node) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = KEY_H
	input.pressed = true
	game._unhandled_input(input)

func _expect(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ", description)
	if not condition:
		_failures += 1
