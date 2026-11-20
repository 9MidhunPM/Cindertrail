extends "res://tools/qa/runtime.gd"
## Native proof runner. Pass --seed=N and --out=/absolute/directory after --.
## Use --map-only for a second layout, --profile for real-time measurements,
## or --fixed-fps 60 before -- to record the two combat sequences at 20 fps.

var journey_seed := 427
var stages: Array[int] = []

func _run() -> void:
	start_usec = Time.get_ticks_usec()
	use_window = DisplayServer.get_name() != "headless"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			journey_seed = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--out="):
			output_dir = argument.trim_prefix("--out=")
	if not use_window or not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Provide a native display and --out=/absolute/directory")
		quit(2)
		return
	route_case = "remix-%d" % journey_seed
	if OS.get_cmdline_user_args().has("--compare"):
		route_case += "-compare"
	elif OS.get_cmdline_user_args().has("--map-only"):
		route_case += "-map"
	elif OS.get_cmdline_user_args().has("--profile"):
		route_case += "-profile"
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", journey_seed)
	set_meta(&"world_layout_version", 1)
	var container := SubViewportContainer.new()
	root.add_child(container)
	var capture := SubViewport.new()
	capture.size = SIZE
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	capture.screen_space_aa = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0))
	container.add_child(capture)
	container.scale = Vector2.ONE * minf(float(root.size.x) / SIZE.x, float(root.size.y) / SIZE.y)
	viewport = capture
	if OS.get_cmdline_user_args().has("--compare"):
		await _compare_rendering()
		_finish()
		return
	game = load(MAIN).instantiate()
	viewport.add_child(game)
	await _physics_frames(60)
	if not _check(game.get("layout") != null and game.layout.version == 1, "Generated journey active"):
		_finish()
		return
	measurements["journey_seed"] = journey_seed
	measurements["layout_id"] = game.layout.layout_id
	measurements["clearings"] = game.layout.clearings
	var landmark: Vector3 = game.grove_terrain.bell_road_sockets().ruin
	var sightline := PhysicsRayQueryParameters3D.create(game.camera.global_position, landmark + Vector3.UP * 0.8, 1)
	measurements["grove_ruin_in_frustum"] = game.camera.is_position_in_frustum(landmark)
	measurements["grove_ruin_sightline_open"] = game.player.get_world_3d().direct_space_state.intersect_ray(sightline).is_empty()
	_key_action("map")
	await _capture("valley-map.png")
	_key_action("map")
	game.hud.hide()
	await _capture("grove-approach.png")
	if OS.get_cmdline_user_args().has("--map-only"):
		_finish()
		return
	if OS.get_cmdline_user_args().has("--profile"):
		game.hud.show()
		measurements["opening"] = await _profile(240, 60)
		await _relay_profile()
		_finish()
		return
	game.melee.swung.connect(func(index: int, _hits: int) -> void: stages.append(index))
	await _film("exploration")
	_position_player(game.grove.anchor.global_position + Vector3(0, .15, 1.35))
	await _physics_frames(8)
	if not await _interact_at_pad():
		_finish()
		return
	game.battle.place(0, 0)
	if not _check(game.start_wave(), "Grove wave started"):
		_finish()
		return
	await _physics_frames(110)
	await _capture("grove-defense.png")
	await _film("defense")
	_finish()

func _sword(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = pressed
	viewport.push_input(event, true)

func _film(label: String) -> void:
	# Stage one visible opponent alongside the ordinary running scene. Only the
	# viewport's bound attack action drives the traveler and its damage windows.
	var crawler := CinderEnemy.new()
	game.battle.add_child(crawler)
	var ahead: Vector3 = -game.player.visual.global_basis.z
	var side: Vector3 = game.player.visual.global_basis.x
	var spot: Vector3 = game.player.global_position + ahead * 1.7 + side * 0.8
	crawler.configure(game.battle.BRUTE, PackedVector3Array([spot, spot]), game.grove)
	game.battle.enemies.append(crawler)
	var frames := _clip_directory(label)
	stages.clear()
	for tick in 260:
		match tick:
			10, 30, 52, 157:
				_sword(true)
			13, 33, 55, 222:
				_sword(false)
		await RenderingServer.frame_post_draw
		if tick % 3 == 0:
			var frame := viewport.get_texture().get_image()
			frame.resize(960, 540, Image.INTERPOLATE_BILINEAR)
			if not _check_frame(frame, frames, tick / 3):
				return
	_encode_clip(frames, label + "-sword.mp4")
	measurements[label + "_strikes"] = stages.duplicate()
	_check(stages.has(0) and stages.has(1) and stages.has(2) and stages.has(3), "Three combo strikes and spin in " + label)

func _check_frame(frame: Image, directory: String, index: int) -> bool:
	if frame.save_jpg(directory.path_join("%03d.jpg" % index), .92) != OK:
		return _check(false, "Write sword motion frame")
	return true

## The same process, viewport, cache, camera transform relative to the local
## landmark, and staged cast across the original and generated valley.
func _compare_rendering() -> void:
	for version in [0, 1]:
		set_meta(&"world_layout_version", version)
		game = load(MAIN).instantiate()
		viewport.add_child(game)
		await _physics_frames(20)
		var label := "legacy" if version == 0 else "remix"
		var scenes := {}
		measurements[label] = scenes
		game.hud.hide()
		for site_id in ["grove", "relay"]:
			var site: CinderSite = game.grove if site_id == "grove" else _find_site("Fallen Relay")
			if site_id == "relay":
				_position_player(site.anchor.global_position + Vector3(0, .12, 1.2))
				game.interact()
				if not await _wait_mode("Prepare", 150):
					return
				game.battle.scrap = 100
				for index in 4:
					game.battle.place(index, index % 3)
				for index in 14:
					var actor := CinderEnemy.new()
					game.battle.add_child(actor)
					var point := site.anchor.global_position + Vector3((index % 7) - 3, 0, (index / 7) * 3.0 - 1.5)
					actor.configure(game.battle.CRAWLER, PackedVector3Array([point, point]), site)
					game.battle.enemies.append(actor)
			paused = true
			if site_id == "relay":
				var at := site.anchor.global_position
				game.camera.global_transform = Transform3D(Basis.IDENTITY, at + Vector3(12, 17, 18)).looking_at(at, Vector3.UP)
				game.camera.fov = 46.0
			else:
				game.director.reset_pose()
			var sample := {}
			scenes[site_id] = sample
			for shadows in [true, false]:
				game.atmosphere.key.shadow_enabled = shadows
				var record := await _profile(160, 35)
				for kind in [[RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "visible"], [RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, "shadow"]]:
					for count in [[RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME, "objects"], [RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME, "draws"], [RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME, "primitives"]]:
						record["%s_%s" % [kind[1], count[1]]] = RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), kind[0], count[0])
				sample["shadow_on" if shadows else "shadow_off"] = record
			game.atmosphere.key.shadow_enabled = true
			paused = false
		game.free()
		game = null
		await process_frame
