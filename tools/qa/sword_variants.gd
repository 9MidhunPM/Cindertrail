extends SceneTree
## Native fixed-camera capture of both sword techniques in the live Flooded Grove.
## godot --fixed-fps 60 --script tools/qa/sword_variants.gd -- --out=/absolute/path
var game
var directory := ""
var started := PackedInt32Array()
var swung := PackedInt32Array()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			directory = arg.trim_prefix("--out=")
	if directory.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	set_meta(&"direct_journey", true)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	var pawn := game.player as CinderPlayer
	game.hud.hide()
	# Keep player steering on the ordinary gameplay camera for reproducibility.
	var view := Camera3D.new()
	view.fov = 39.0
	game.add_child(view)
	view.make_current()
	var facing := Vector3.FORWARD
	var start: Vector3 = game.grove.anchor.global_position + Vector3(2.0,.15,1.85)
	pawn.global_position = start
	pawn.velocity = Vector3.ZERO
	pawn.visual.rotation.y = 0.0
	pawn.reset_physics_interpolation()
	var focus := start + Vector3.UP * 1.0 + facing * 1.10
	view.position = focus + Vector3(-2.80,1.12,-3.75)
	view.look_at(focus)
	game.melee.swung.connect(func(index: int, _hits: int): swung.append(index))
	for warmup in 45:
		await physics_frame
	for frame in 151:
		match frame:
			10:
				var dash_length := CinderPlayer.DASH_SPEED * CinderPlayer.DASH_SECONDS
				if not pawn.begin_swept_dash(facing, dash_length, CinderPlayer.DASH_SECONDS, &"dash"):
					push_error("The Grove capture lane could not support the dash.")
					quit(1)
					return
			13:
				started.append(int(game.melee.press(facing, &"keyboard")))
				game.melee.release(&"keyboard")
			78:
				Input.action_press("jump")
			80:
				Input.action_release("jump")
			99:
				started.append(int(game.melee.press(facing, &"mouse")))
				game.melee.release(&"mouse")
		await physics_frame
		if DisplayServer.get_name() == "headless":
			continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(directory.path_join("%03d.jpg" % frame), .90)
	print("Grove sword inputs ", started, " contacts ", swung)
	quit(0 if swung == PackedInt32Array([CinderMelee.ATTACKS.DASH_CUT, CinderMelee.ATTACKS.DESCENT]) else 1)
