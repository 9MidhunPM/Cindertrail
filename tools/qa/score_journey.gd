extends "res://tools/qa/remix_capture.gd"
## Record the real mixer using Godot --write-movie /tmp/sunrise.avi --fixed-fps 24
## --resolution 1920x1080 --script tools/qa/score_journey.gd -- --out=/absolute/path.
## --compare uses the inherited real-time render benchmark; omit --write-movie.
## --rehearse exercises staging headless, before music arrives.
var chapters: Array[Dictionary] = []
var rehearsal := false
var score: Node
var expected := ["exploration", "defense", "pursuit", "vesper"]

func _comparison_versions() -> Array:
	return [2, 3]

func _run() -> void:
	if OS.get_cmdline_user_args().has("--compare"):
		await super._run()
		return
	start_usec = Time.get_ticks_usec()
	route_case = "score-journey"
	rehearsal = OS.get_cmdline_user_args().has("--rehearse")
	use_window = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
	if not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Specify --out=/absolute/path")
		quit(2)
		return
	viewport = root
	if not rehearsal:
		root.min_size = SIZE
		root.max_size = SIZE
		root.size = SIZE
		root.unresizable = true
		var files_present := true
		for cue in expected:
			files_present = files_present and ResourceLoader.exists("res://art/audio/score/%s.ogg" % cue)
		if not _check(use_window and not Engine.get_write_movie_path().is_empty() and files_present, "Movie recording and all four score chapters available"):
			_finish()
			return
	set_meta(&"direct_journey", true)
	set_meta(&"world_layout_version", 3)
	set_meta(&"journey_seed", 428)
	game = load(MAIN).instantiate()
	root.add_child(game)
	current_scene = game
	await _physics_frames(12)
	if not rehearsal:
		score = game.soundscape.get_node("JourneyScore")
	if not await _record_journey():
		_check(false, "Journey showcase complete")
	measurements["chapters"] = chapters
	_finish()

func _record_journey() -> bool:
	var identity: int = game.core.get_instance_id()
	_mark("exploration")
	Input.action_press("move_forward")
	await _physics_frames(90)
	Input.action_release("move_forward")
	if not await _cue("exploration"):
		return false
	await _physics_frames(90)
	if not await _deploy(game.grove):
		return false
	_mark("defense")
	if not _check(game.start_wave(), "Defend at the generated Grove shrine"):
		return false
	if not await _cue("defense"):
		return false
	await _physics_frames(190)
	_key_action("melee")
	await _physics_frames(32)
	if not await _pack():
		return false
	_mark("pursuit")
	if not await _cue("pursuit"):
		return false
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _physics_frames(120)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	# Bridge the journey to a fully restored shrine for footage. Actual campaign
	# QA earns all 100 points along connected roads in a separate run.
	game.core.restoration = 100
	_position_player(game.beacon.global_position + Vector3(0, .15, 1.55))
	game.player.recovery_point = game.player.global_position
	game.director.reset_pose()
	await _physics_frames(12)
	_mark("vesper")
	if not rehearsal:
		physics_frame.connect(_observe_boss_music)
	if not await _fight_guardian():
		return false
	if not rehearsal:
		physics_frame.disconnect(_observe_boss_music)
		if not _check(measurements.get("heard_vesper", false), "Guardian soundtrack selected during battle"):
			return false
	game.interact()
	await _physics_frames(12)
	if not _check(game.mode == game.Mode.WIN and game.finale != null, "Finale starts on delivery"):
		return false
	_mark("finale")
	if not rehearsal:
		var voice: AudioStreamPlayer = game.soundscape.get_node_or_null("LastSunriseScore")
		_check(voice != null and voice.playing and voice.bus == &"Music", "Finale score plays through the Music bus")
	# The scene can normally be reloaded from the results screen. Capture its
	# finished signal and isolate the unattended recording from desktop input.
	var ending: Node = game.finale
	root.gui_disable_input = true
	game.set_process_unhandled_input(false)
	ending.set_process_input(false)
	await ending.finished
	var delivered: bool = is_instance_valid(game) and game.finale == null and game.hud.visible \
		and game.core.get_instance_id() == identity and game.core.get_parent() == game.beacon
	_mark("results")
	await _physics_frames(24)
	return _check(delivered, "Delivered core and sunrise results")

func _cue(name_of_cue: String) -> bool:
	if rehearsal:
		await _physics_frames(70)
		return true
	for tick in 240:
		if score.current_cue == StringName(name_of_cue):
			_mark("music_" + name_of_cue)
			return true
		await physics_frame
	return _check(false, "Score selects " + name_of_cue)

func _observe_boss_music() -> void:
	if score.current_cue == &"vesper" and not measurements.has("heard_vesper"):
		measurements["heard_vesper"] = true
		_mark("music_vesper")

func _mark(label: String) -> void:
	chapters.append({"chapter": label, "video_frame": Engine.get_process_frames()})
	print("CINDERTRAIL_CHAPTER ", label, " ", Engine.get_process_frames())
