extends SceneTree
## Run in real time with CINDERTRAIL_TEST_SAVE=1 and an isolated XDG_DATA_HOME.

const SOUNDSCAPE := preload("res://scripts/game/soundscape.gd")
const FRONT := preload("res://scenes/ui/front_end.tscn")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, detail: String) -> void:
	print("PASS " if ok else "FAIL ", detail)
	if not ok:
		failures += 1

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Use an isolated XDG_DATA_HOME and set CINDERTRAIL_TEST_SAVE=1")
		quit(2)
		return
	Engine.max_fps = 120
	set_meta(&"audio_qa", true)
	var soundscape := SOUNDSCAPE.new()
	root.add_child(soundscape)
	var score := soundscape.get_node("JourneyScore")
	var master := AudioServer.get_bus_index(&"Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(master, capture)
	await _settings()
	_check(AudioServer.get_bus_effect(master, 0) is AudioEffectHardLimiter,
		"Master keeps a hard limiter before the audio meter")

	var music_bus := AudioServer.get_bus_index(&"Music")
	var ambience_bus := AudioServer.get_bus_index(&"Ambience")
	AudioServer.set_bus_mute(music_bus, true)
	AudioServer.set_bus_mute(ambience_bus, true)
	await create_timer(.06).timeout
	capture.clear_buffer()
	for sample in 100:
		soundscape.cue("attack")
	for name in ["footstep", "footstep_alt", "deploy", "pack", "build", "hurt", "repair", "mortar", "wave",
			"collect", "win", "blade_ready", "spin", "slash", "slam", "impact", "skimmer_wake", "ram_stamp"]:
		soundscape.cue(name)
	soundscape.toll_bell(Vector3(4, 0, 0), true)
	_check(soundscape.get_child_count() < 40, "Repeated cues reuse a fixed number of voices")
	soundscape.cue("vesper_charge")
	var telegraph_playing := false
	for voice in soundscape.get_children():
		if voice is AudioStreamPlayer and voice.playing and voice.stream.resource_path.ends_with("vesper_charge.wav"):
			telegraph_playing = true
	_check(telegraph_playing, "Boss warnings remain audible after an effect burst")
	await create_timer(.30).timeout
	var local_peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		local_peak = maxf(local_peak, maxf(absf(frame.x), absf(frame.y)))
	_check(local_peak > .0001 and local_peak < .9, "Master meter receives audible samples below clipping")
	AudioServer.set_bus_mute(music_bus, false)
	AudioServer.set_bus_mute(ambience_bus, false)

	if not OS.get_cmdline_user_args().has("--mix-only"):
		await _wait_for_cue(score, &"exploration", 1.0)
		soundscape.update_score(false, true, false, false, 7)
		await _wait_for_cue(score, &"defense", 2.0)
		soundscape.update_score(false, false, true, false, 3)
		await _wait_for_cue(score, &"pursuit", 3.0)
		soundscape.update_score(false, true, true, true, 10)
		await _wait_for_cue(score, &"vesper", 3.0)
		soundscape.update_score(false, false, false, false)
		await create_timer(.5).timeout
		_check(score.current_cue == &"vesper", "Quiet delay filters transient combat exits")
		await _wait_for_cue(score, &"exploration", 5.0)

	soundscape.ending_cue(&"handoff")
	await create_timer(.55).timeout
	var ending := soundscape.get_node_or_null("LastSunriseScore") as AudioStreamPlayer
	_check(ending != null and ending.playing and ending.bus == &"Music" and score.current_cue.is_empty(),
		"The timed sunrise score takes over the Music bus")
	soundscape.ending_cue(&"settled")
	await create_timer(.8).timeout
	_check(ending != null and not ending.playing, "Skipping or finishing the finale stops its music")
	soundscape.queue_free()
	AudioServer.remove_bus_effect(master, 1)
	# Let AudioServer consume the queued voice deletions before stopping its mixer thread.
	await create_timer(.15).timeout
	print("Adaptive audio failures ", failures)
	quit(0 if failures == 0 else 1)

func _settings() -> void:
	var front := FRONT.instantiate()
	root.add_child(front)
	front.show_settings()
	var music := front.find_child("MusicVolume", true, false) as HSlider
	var effects := front.find_child("EffectsVolume", true, false) as HSlider
	var ambience := front.find_child("AmbienceVolume", true, false) as HSlider
	_check(music != null and effects != null and ambience != null, "Settings exposes three independent audio levels")
	if music == null or effects == null or ambience == null:
		front.free()
		return
	music.value = .47
	effects.value = 0.0
	ambience.value = .78
	front.free()
	var reopened := FRONT.instantiate()
	root.add_child(reopened)
	reopened.show_settings()
	var stored := reopened.find_child("MusicVolume", true, false) as HSlider
	_check(is_equal_approx(stored.value, .47)
		and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects"))
		and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"Ambience")), .78),
		"Reopening restores Music, Effects, and Ambience independently")
	(reopened.find_child("EffectsVolume", true, false) as HSlider).value = 1.0
	reopened.free()
	await process_frame

func _wait_for_cue(score: Node, expected: StringName, limit: float) -> void:
	var deadline := Time.get_ticks_msec() + roundi(limit * 1000.0)
	while score.current_cue != expected and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(score.current_cue == expected, "Music follows %s" % expected)
