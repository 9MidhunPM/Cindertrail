extends "res://tools/qa/runtime.gd"
## Native 1080p. Pass --out=/absolute/folder and optionally --light-only or --towns-only. Add --repeat to repeat town timings in reverse order.

const LAYOUT := preload("res://scripts/world/journey_layout.gd")
const TOWNS := [&"western_arcade", &"bellmakers_steps", &"mineral_ward"]

func _run() -> void:
	start_usec = Time.get_ticks_usec()
	use_window = DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
	if not use_window or not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Run with a native display and --out=/absolute/directory")
		quit(2)
		return
	var display := SubViewportContainer.new()
	root.add_child(display)
	var native_view := SubViewport.new()
	native_view.size = SIZE
	native_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	native_view.screen_space_aa = ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa")
	display.add_child(native_view)
	display.scale = Vector2.ONE * minf(float(root.size.x) / SIZE.x, float(root.size.y) / SIZE.y)
	viewport = native_view
	route_case = "moonlit-towns" if args.has("--towns-only") else "moonlit-valley"
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", 517)
	set_meta(&"world_layout_version", LAYOUT.VERSION)
	game = load(MAIN).instantiate()
	viewport.add_child(game)
	if not _check(is_instance_valid(game.get("player")) and is_instance_valid(game.get("grove")),
			"Load the playable valley"):
		_finish()
		return
	await _physics_frames(36)
	game.hud.hide()
	measurements["journey_seed"] = game.layout.journey_seed
	if not args.has("--towns-only"):
		await _lighting_pair("grove-approach")
		_position_player(game.grove.anchor.global_position + Vector3(0, .12, 1.5))
		await _physics_frames(8)
		game.interact()
		if not await _wait_mode("Prepare", 180):
			_finish()
			return
		_check(game.battle.place(0, 0), "Install a tower at the Grove")
		_check(game.start_wave(), "Start the defense on the real tactical camera")
		await _physics_frames(115)
		await _lighting_pair("grove-defense")
		if not args.has("--light-only") and not await _pack():
			_finish()
			return
	if not args.has("--light-only"):
		await _photograph_towns()
	_finish()

func _lighting_pair(label: String) -> void:
	# Hold the scene and both camera transforms for an A/B comparison of rendered cost.
	game._set_paused(true)
	game.hud.hide()
	var camera_pose: Transform3D = game.camera.global_transform
	var env: CinderAtmosphere = game.atmosphere
	var sky_low: Variant = env.sky_material.get_shader_parameter(&"night_low")
	env.environment.ambient_light_color = Color("#7796cb")
	env.environment.ambient_light_energy = .56
	env.environment.fog_light_color = Color("#345881")
	env.key.rotation_degrees = Vector3(-29, -41, 0)
	env.key.light_color = Color("#ffe7c6")
	env.key.light_energy = 1.32
	env.sky_material.set_shader_parameter(&"night_low", Color(.11, .28, .46))
	await _capture(label + "-before.png")
	measurements[label + "_before"] = await _profile(32, 12)

	env.sky_material.set_shader_parameter(&"night_low", sky_low)
	env.set_dawn_fraction(0.)
	await _capture(label + "-moonlit.png")
	measurements[label + "_moonlit"] = await _profile(32, 12)
	_check(game.camera.global_transform.is_equal_approx(camera_pose), "Matched camera transform for " + label)
	game._set_paused(false)
	game.hud.hide()

func _photograph_towns() -> void:
	var district = game.outer_valley.get("abandoned_towns")
	if not _check(district != null, "Town districts are populated in the selected journey"):
		return
	measurements["town_variants"] = game.layout.town_variants.duplicate()
	for id in TOWNS:
		var town: Node3D = district.settlement_at(id)
		if not _check(is_instance_valid(town), "Find " + String(id)):
			continue
		var standing := Vector3(-1.7, 0, 4.5)
		var focus := Vector3(1.3, 2.8, -6.0)
		var pitch := .05
		if id != &"western_arcade" and not town.discovery_points.is_empty():
			var niche := town.to_local(town.discovery_points[0])
			if id == &"bellmakers_steps":
				standing = Vector3(0, 0, 7.5)
				focus = niche + Vector3(0, 4.2, -2.8)
				pitch = -.28
			else:
				standing = Vector3(niche.x * .38, 0, niche.z + 2.4)
				focus = niche + Vector3(0, .2, -2.55)
				pitch = .24
		var point := town.to_global(standing)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.8, point - Vector3.UP * 5., 1)
		var floor: Dictionary = town.get_world_3d().direct_space_state.intersect_ray(query)
		if not _check(not floor.is_empty(), "Find the street surface at " + String(id)):
			continue
		_position_player(Vector3(floor.position) + Vector3.UP * .09)
		var direction: Vector3 = town.to_global(focus) - game.player.global_position
		game.director.yaw = atan2(-direction.x, -direction.z) + (.13 if id != &"western_arcade" else 0.)
		game.director.pitch = pitch
		game.player.visual.rotation.y = game.director.yaw
		game.director.reset_pose()
		await _physics_frames(24)
		_check(game.player.is_on_floor() and not game.director.tactical, "Standing exploration view inside " + String(id))
		await _settlement_pair(id, district)

func _settlement_pair(id: StringName, district: Node3D) -> void:
	game._set_paused(true)
	game.hud.hide()
	var pose: Transform3D = game.camera.global_transform
	# Keep the selected terrain, global moonlight, active town placement and camera.
	# Hide only the new town meshes, their lamps and the forest dressing for the prior view.
	district.hide()
	await _capture(String(id) + "-before.png")
	var before := await _profile(48, 48)
	district.show()
	await _capture(String(id) + ".png")
	var after := await _profile(48, 48)
	measurements[String(id)] = {
		"without_towns_and_forest": before, "with_towns_and_forest": after,
		"p95_change_percent": 100.0 * (after.p95_frame_ms / before.p95_frame_ms - 1.0),
		"traveler": var_to_str(game.player.global_position), "camera": var_to_str(game.camera.global_position)
	}
	if OS.get_cmdline_user_args().has("--repeat"):
		# Reverse the sampling order to expose heat, compositor load or a first-frame hitch.
		var repeated_after := await _profile(48, 48)
		district.hide()
		var repeated_before := await _profile(48, 48)
		district.show()
		measurements[String(id)]["repeat_with"] = repeated_after
		measurements[String(id)]["repeat_without"] = repeated_before
		measurements[String(id)]["repeat_p95_change_percent"] = 100.0 * (
			repeated_after.p95_frame_ms / repeated_before.p95_frame_ms - 1.0)
	_check(game.camera.global_transform.is_equal_approx(pose), "Matched camera transform for " + String(id))
	game._set_paused(false)
	game.hud.hide()
