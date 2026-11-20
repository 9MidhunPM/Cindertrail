extends "res://tools/qa/runtime.gd"
## godot --fixed-fps 30 -s tools/qa/bell_road_capture.gd -- --out=/absolute/path [--record-transition]

func _run() -> void:
	start_usec = Time.get_ticks_usec()
	route_case = "bell-road"
	use_window = DisplayServer.get_name() != "headless"
	var record := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
		elif arg == "--record-transition":
			record = true
	if not use_window or not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Run with a native display and --out=/absolute/path")
		quit(2)
		return
	# A fixed-size viewport keeps the output 1080p on tiled or scaled desktops.
	var display := SubViewportContainer.new()
	root.add_child(display)
	var capture := SubViewport.new()
	capture.size = SIZE
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.screen_space_aa = ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa")
	display.add_child(capture)
	display.scale = Vector2.ONE * minf(float(root.size.x) / SIZE.x, float(root.size.y) / SIZE.y)
	viewport = capture
	set_meta(&"direct_journey", true)
	game = load(MAIN).instantiate()
	viewport.add_child(game)
	await _physics_frames(10)
	var road: Node3D = game.bell_road
	var entry := road.to_global(road.route[0])
	var crest := road.to_global(road.route[1])
	var exit_point := road.to_global(road.route[-1])
	var forward := (exit_point - entry).slide(Vector3.UP).normalized()
	var bell_focus := crest + Vector3(forward.z, 0, -forward.x) * 1.92
	_frame_crossing(entry, bell_focus)
	game.hud.hide()
	await _physics_frames(12)
	await _capture("01-submerged-exploration.png")
	_position_player(game.grove.anchor.global_position + Vector3(0, .12, 1.7))
	await _physics_frames(8)
	game.interact()
	if not await _wait_mode("Prepare", 180):
		_finish()
		return
	await _capture("02-submerged-defense.png")
	_check(game.battle.place(0, 0), "Install a bolt turret from starting supplies")
	game.hud.show()
	if not _check(game.start_wave(), "Begin a real Grove defense for the reveal"):
		_finish()
		return
	# Skip the first 40 seconds of extraction to keep this visual fixture short.
	# The last second and the whole reveal run through the normal physics loop.
	game._extract((game.grove.remaining_energy - 12.89) / game.grove.spec.rate)
	physics_frame.connect(_assist_target)
	frame_recording = record
	if record:
		_record_clip()
	for i in 90:
		if road.awakened:
			break
		await physics_frame
	if _check(road.awakened, "The active defense triggers the threshold"):
		game.hud.hide()
		await _physics_frames(46)
		await _capture("03a-light-crosses-water.png")
		await _physics_frames(62)
		await _capture("03b-rising-defense-clean.png")
		game.hud.show()
		await _capture("03-rising-defense.png")
		for i in 180:
			if road.walkable:
				break
			await physics_frame
	await _physics_frames(26)
	frame_recording = false
	_check(road.walkable, "The causeway settles while the attack continues")
	await _capture("04-raised-defense.png")
	game.hud.hide()
	await _capture("05-raised-defense-clean.png")
	print("BELL_CAPTURE_RETREAT health=", game.core.health, " mode=", _mode())
	if await _pack():
		_frame_crossing(entry, bell_focus)
		await _physics_frames(12)
		await _capture("06-raised-exploration.png")
		var midway := entry.lerp(crest, .62)
		if await _walk_to(midway):
			_look_at(bell_focus)
			await _physics_frames(5)
			await _capture("07-traveler-crossing.png")
		if await _walk_to(crest):
			_look_at(exit_point)
			await _physics_frames(12)
			await _capture("08-crest-exploration.png")
			measurements["raised_grove_exploration"] = await _profile(24, 6)
	physics_frame.disconnect(_assist_target)
	_finish()

func _record_clip() -> void:
	# Sample by simulation ticks so both 30 and 60 fps capture runs encode at 30 fps.
	var folder := output_dir.path_join("transition_frames")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create reveal frame directory"):
		return
	var previous := -2
	while frame_recording:
		await RenderingServer.frame_post_draw
		var tick := Engine.get_physics_frames()
		if not frame_recording or tick - previous < 2:
			continue
		previous = tick
		var frame := viewport.get_texture().get_image()
		frame.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		if frame.save_jpg(folder.path_join("%04d.jpg" % clip_frames), .90) != OK:
			_check(false, "Write reveal frame")
			return
		clip_frames += 1

func _frame_crossing(position: Vector3, target: Vector3) -> void:
	_position_player(position + Vector3.UP * .09)
	_look_at(target)

func _look_at(point: Vector3) -> void:
	var direction: Vector3 = point - game.player.global_position
	game.director.yaw = atan2(-direction.x, -direction.z)
	game.director.pitch = .13
	game.director.reset_pose()
