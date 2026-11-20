extends SceneTree
## Run against the project's main scene. An optional -- --film=/absolute/output
## captures the full ending from a guardian-cleared crown with native Godot.
var game: Node
var failures := 0
var film := ""
var cues: Array[StringName] = []
var finishes := 0
var finish_time := 0.0
const STILL_TIMES := [2.3, 7.5, 12.4, 18.0, 24.5]
const STILL_NAMES := ["handoff", "arch", "ford", "ward", "beacon"]

func _initialize() -> void:
	_run.call_deferred()

func _check(good: bool, label: String) -> bool:
	print("PASS " if good else "FAIL ", label)
	if not good:
		failures += 1
	return good

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _load_world(reduced: bool, deployed: bool) -> void:
	set_meta(&"direct_journey", true)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(4)
	game.director.reduced_motion = reduced
	game.summit.cleared = true
	game.core.restoration = 100.0
	game.player.global_position = game.beacon.global_position + Vector3(0, .12, 1.6)
	game.player.recovery_point = game.player.global_position
	game.player.reset_physics_interpolation()
	game.director.reset_pose()
	await _frames(8)
	if deployed:
		game.summit.site.show()
		game._deploy(game.summit.site)
		await _frames(82)

func _start() -> int:
	var original: int = game.core.get_instance_id()
	game.interact()
	if not film.is_empty():
		print("FILM_BEGIN_FRAME ", Engine.get_process_frames())
	if not _check(game.mode == game.Mode.WIN and game.finale != null and game.finale.active,
			"Delivery starts the presentation in the actual game"):
		return -1
	cues.assign([game.finale.phase])
	finishes = 0
	var stage: CanvasLayer = game.finale
	stage.score_cue.connect(func(cue: StringName): cues.append(cue))
	stage.finished.connect(func():
		finishes += 1
		finish_time = stage.elapsed
	)
	return original

func _settled(original: int) -> void:
	_check(finishes == 1 and cues.count(&"settled") == 1, "The ending settled once")
	_check(game.core.get_instance_id() == original and game.core.get_parent() == game.beacon
		and game.core.form == SunCore.Form.DELIVERED and game.atmosphere.sunrise,
		"The original sun remains in the beacon at dawn")
	_check(game.hud.visible and game.finale == null, "Results are visible after completion")

func _close_scene() -> void:
	current_scene = null
	game.queue_free()
	await process_frame
	await process_frame

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--film="):
			film = arg.trim_prefix("--film=")
	if not film.is_empty() and (not film.is_absolute_path() or DisplayServer.get_name() == "headless"):
		quit(2)
		return
	if not film.is_empty():
		DirAccess.make_dir_recursive_absolute(film)
	await _load_world(false, true)
	var complete_id := _start()
	if complete_id < 0:
		quit(1)
		return
	_check(not game.hud.visible, "The results do not cover the handoff")
	var stage: CanvasLayer = game.finale
	var captured := 0
	var panels := stage.get_node("Page/Paintings").get_children()
	var imported := panels.size() == 3
	for panel: TextureRect in panels:
		imported = imported and panel.texture != null and panel.texture.get_width() >= 1280
	_check(imported, "All three illustrated plates loaded at presentation resolution")
	var frames := 0
	while is_instance_valid(stage) and stage.active and frames < 4500:
		await process_frame
		frames += 1
		if is_instance_valid(stage) and not film.is_empty() and captured < STILL_TIMES.size() and stage.elapsed >= STILL_TIMES[captured]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(film.path_join(STILL_NAMES[captured] + ".png"))
			captured += 1
	_check(cues == [&"handoff", &"arch", &"ford", &"relay", &"return", &"settled"],
		"Full playback follows the authored beats and settles at 26 seconds")
	_check(finish_time == 26.0, "Timeline duration is 26 seconds")
	_settled(complete_id)
	if not film.is_empty():
		await _frames(30)
		quit(1 if failures else 0)
		return
	await _close_scene()
	await _load_world(true, false)
	var skip_id := _start()
	if skip_id < 0:
		quit(1)
		return
	var transform_at_start: Transform3D = game.camera.global_transform
	await _frames(48)
	_check(game.camera.global_transform.is_equal_approx(transform_at_start), "Reduced motion keeps the handoff camera still")
	await _frames(270)
	var still_plate: TextureRect = game.finale.get_node("Page/Paintings").get_child(0)
	_check(still_plate.visible and still_plate.material.get_shader_parameter("still"),
		"Reduced motion uses a still painting")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	var mid: CanvasLayer = game.finale
	root.push_input(esc)
	_check(game.finale == null, "Escape skips the active painting")
	mid.skip()
	await process_frame
	esc = esc.duplicate()
	esc.pressed = false
	root.push_input(esc)
	_settled(skip_id)
	await _close_scene()
	await _load_world(false, false)
	var immediate_id := _start()
	if immediate_id < 0:
		quit(1)
		return
	var current: CanvasLayer = game.finale
	current.get_node("Page/SkipEnding").pressed.emit()
	current.skip()
	_settled(immediate_id)
	await _close_scene()
	quit(1 if failures else 0)
