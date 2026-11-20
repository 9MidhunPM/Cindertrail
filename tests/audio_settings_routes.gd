extends SceneTree
## Run in real time with CINDERTRAIL_TEST_SAVE=1 and an isolated XDG_DATA_HOME.

const MAIN := preload("res://scenes/main.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Run with an isolated XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1")
		quit(2)
		return
	Engine.max_fps = 120
	set_meta(&"audio_qa", true)
	if not JourneyCheckpoint.write({"position": Vector3(-3.0, .76, 15.0), "health": 97.0}):
		push_error("Could not write the isolated audio settings fixture")
		quit(2)
		return
	var game := MAIN.instantiate()
	root.add_child(game)
	await process_frame
	var front: CinderFrontEnd = game.get("_front_end")
	var continued := root.gui_get_focus_owner()
	_check(continued != null and continued.name == &"ContinueJourney", "Title focuses the saved journey")
	if not await _focus(&"Settings"):
		quit(1)
		return
	await _key(KEY_ENTER)
	_check(front.stage == &"settings" and _focused(&"MasterVolume"), "Enter opens title audio settings on Master volume")
	await _key(KEY_LEFT)
	var master := AudioServer.get_bus_index(&"Master")
	var music := AudioServer.get_bus_index(&"Music")
	var effects := AudioServer.get_bus_index(&"Effects")
	var ambience := AudioServer.get_bus_index(&"Ambience")
	var master_level := AudioServer.get_bus_volume_linear(master)
	_check(is_equal_approx(master_level, .81), "Keyboard reduces Master volume by one step")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_check(_focused(&"MusicVolume"), "Controller D-pad reaches Music independently")
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(music), .99), "Controller changes Music without changing Effects or Ambience")
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(effects), 1.0)
		and is_equal_approx(AudioServer.get_bus_volume_linear(ambience), 1.0), "Effects and Ambience retain their levels")

	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(master, capture)
	var effect_index := AudioServer.get_bus_effect_count(master) - 1
	AudioServer.set_bus_mute(effects, true)
	AudioServer.set_bus_mute(ambience, true)
	var music_slider := front.find_child("MusicVolume", true, false) as HSlider
	if music_slider == null:
		quit(1)
		return
	await create_timer(.45).timeout
	capture.clear_buffer()
	await create_timer(.20).timeout
	var unmuted_peak := _peak(capture)
	music_slider.value = 0.0
	AudioServer.set_bus_mute(effects, true)
	AudioServer.set_bus_mute(ambience, true)
	await create_timer(.12).timeout
	capture.clear_buffer()
	await create_timer(.16).timeout
	var muted_peak := _peak(capture)
	_check(unmuted_peak > .0001 and muted_peak < .00001 and AudioServer.is_bus_mute(music),
		"Setting Music to zero silences the actual exploration track")
	AudioServer.remove_bus_effect(master, effect_index)
	music_slider.value = .64
	_check(not AudioServer.is_bus_mute(music), "Increasing Music unmutes its route")

	await _key(KEY_ESCAPE)
	_check(front.stage == &"menu" and _focused(&"Settings"), "Escape returns to title and restores focus")
	if not await _focus(&"ContinueJourney"):
		quit(1)
		return
	await _key(KEY_ENTER)
	_check(front.stage == &"hidden" and is_equal_approx(game.core.health, 97.0), "Keyboard Continue restores the journey")
	await _key(KEY_ESCAPE)
	_check(paused and _focused(&"Resume"), "Escape opens pause with keyboard focus")
	if not await _focus(&"Settings"):
		quit(1)
		return
	await _key(KEY_ENTER)
	music_slider = front.find_child("MusicVolume", true, false) as HSlider
	_check(paused and front.stage == &"settings" and _focused(&"MasterVolume")
		and music_slider != null and is_equal_approx(music_slider.value, .64)
		and is_equal_approx(AudioServer.get_bus_volume_linear(master), master_level),
		"Pause settings reopen with the same Master and Music levels")
	await _key(KEY_ESCAPE)
	_check(paused and front.stage == &"hidden" and _focused(&"Resume"), "Closing settings returns to the paused journey")
	await _key(KEY_ENTER)
	_check(not paused and front.stage == &"hidden", "Keyboard Resume returns control to the traveler")
	game.queue_free()
	await create_timer(.18).timeout
	print("Audio settings routes failures ", failures)
	quit(0 if failures == 0 else 1)

func _check(condition: bool, detail: String) -> void:
	print("PASS " if condition else "FAIL ", detail)
	if not condition:
		failures += 1

func _focused(name: StringName) -> bool:
	var focus := root.gui_get_focus_owner()
	return focus != null and focus.name == name

func _focus(name: StringName) -> bool:
	for index in 12:
		if _focused(name):
			return true
		await _key(KEY_TAB)
	_check(false, "Tab reaches %s" % name)
	return false

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	await _press(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)

func _press(event: InputEvent) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame

func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak
