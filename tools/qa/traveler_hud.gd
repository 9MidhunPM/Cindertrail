extends "res://tools/qa/runtime.gd"
## Use an isolated XDG_DATA_HOME. --out=/absolute/folder enables native color captures.

const COMPASS := preload("res://scripts/ui/journey_compass.gd")
const SIZES := [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(1920,810)]

func _run() -> void:
	start_usec = Time.get_ticks_usec()
	use_window = DisplayServer.get_name() != "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output_dir = arg.trim_prefix("--out=")
	if not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Supply --out=/absolute/path after --")
		quit(2)
		return
	route_case = "traveler-hud"
	var display := SubViewportContainer.new()
	root.add_child(display)
	var native := SubViewport.new()
	native.size = SIZES[0]
	native.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	native.screen_space_aa = ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa")
	display.add_child(native)
	viewport = native
	set_meta(&"direct_journey", true)
	set_meta(&"journey_seed", 517)
	set_meta(&"world_layout_version", CinderJourneyLayout.VERSION)
	game = load(MAIN).instantiate()
	viewport.add_child(game)
	if not _check(is_instance_valid(game.get("grove")), "Load the complete gameplay scene"):
		_finish()
		return
	# Direct launch keeps this QA journey out of the player's save and achievements.
	game.arts.profile_enabled = false
	await _physics_frames(12)
	var hud: CinderHUD = game.hud
	var sun: int = game.core.get_instance_id()
	_check(hud._compass.camera == game.camera and hud._compass.traveler == game.player, "Compass uses live journey camera and traveler")
	_check(is_equal_approx(COMPASS.relative_bearing(Vector3.FORWARD.rotated(Vector3.UP, .02),
			Vector3.FORWARD.rotated(Vector3.UP,-.02)), .04), "Compass takes the short way across north")
	_check(is_equal_approx(absf(COMPASS.relative_bearing(Vector3.FORWARD, Vector3.BACK)), PI), "Behind-camera bearing stays at an edge")
	_check(hud._art_dock.slots.size() == 7 and hud._art_dock.slots.all(func(row): return not row.owned and row.icon is Texture2D),
		"Seven imported locked arts at the beginning of a journey")
	_check(hud.minimap.objective != Vector3.INF and hud.minimap.objective == hud._big_map.objective, "Both maps carry the final destination")
	await _screens("exploration")
	_key_action("toggle_hud")
	_key_action("map")
	await _physics_frames(2)
	_check(paused and hud._full_map.is_visible_in_tree(), "F10 followed by M still opens a visible map")
	_key_action("map")
	_key_action("cancel")
	await _physics_frames(2)
	_check(paused and hud._buttons[&"achievements"].is_visible_in_tree(), "F10 followed by Escape leaves pause actions accessible")
	_key_action("cancel")
	_check(not hud._vitals_panel.visible, "Closing modal restores hidden readouts")
	_key_action("toggle_hud")
	_position_player(game.grove.anchor.global_position + Vector3(0,.12,1.5))
	await _physics_frames(5)
	game.interact()
	await _physics_frames(22)
	if use_window:
		await _photo("transition")
	if not await _wait_mode("Prepare", 190):
		_finish()
		return
	game.arts.restore([&"flooded_grove",&"broken_quarry"], &"flooded_grove",
		{&"flooded_grove": 6., &"broken_quarry": 8.}, 0.)
	game.battle.place(0,0)
	_key_action("start_wave")
	await _physics_frames(72)
	_check(_mode() == "Defend" and hud._wave_panel.visible and not hud._objective_panel.visible, "Defense replaces travel compass with a wave strip")
	_check(game.core.get_instance_id() == sun and hud._art_dock.slots.any(func(row): return row.selected and row.cooldown > 0.),
		"Single sun readouts and selected art cooldown survive deployment")
	_check(hud._art_dock.slots.any(func(row): return row.owned and not row.selected and row.cooldown > 0.),
		"Independent recovering art remains in the dock")
	await _screens("defense")
	if use_window:
		# Freeze the live battle without opening the pause menu for matched render samples.
		game.set_physics_process(false)
		paused = true
		hud.hide()
		measurements["defense_without_hud"] = await _profile(32, 16)
		hud.show()
		measurements["defense_with_hud"] = await _profile(32, 16)
		paused = false
		game.set_physics_process(true)
	game.core.damage(74)
	hud.announce_ability("Faultline", load("res://art/ui/arts/broken_quarry.svg"), 3, true)
	game._render_hud()
	await _physics_frames(6)
	_check(hud._reward_panel.visible and not hud._toast_box.visible, "One reward panel replaces combat notices")
	if use_window:
		await _photo("low-integrity-reward")
	Input.action_press("pack")
	await _physics_frames(38)
	_check(hud._pack.visible and hud._pack.value > 0., "Hold-to-pack shows actual progress")
	if use_window:
		await _photo("packing")
	Input.action_release("pack")
	_finish()

func _screens(label: String) -> void:
	for extent: Vector2i in SIZES:
		viewport.size = extent
		var display := viewport.get_parent() as SubViewportContainer
		display.scale = Vector2.ONE * minf(float(root.size.x) / extent.x, float(root.size.y) / extent.y)
		await _physics_frames(4)
		var hud: CinderHUD = game.hud
		var primary := hud._wave_panel if label == "defense" else hud._objective_panel
		_check(not primary.get_global_rect().intersects(hud._vitals_panel.get_global_rect())
			and not primary.get_global_rect().intersects(hud._map_frame.get_global_rect()),
			"Top readouts fit at %s in %s" % [extent,label])
		if label == "defense":
			_check(not hud._art_dock.get_global_rect().intersects(hud._tactical.get_global_rect()),
				"Tower selection clears all seven arts at %s" % extent)
		if use_window:
			await _photo("%s-%dx%d" % [label,extent.x,extent.y])
	viewport.size = Vector2i(1920,1080)
	await _physics_frames(4)

func _photo(label: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var frame := viewport.get_texture().get_image()
	_check(frame.get_size() == viewport.size and frame.save_png(output_dir.path_join(label + ".png")) == OK,
		"Captured " + label)
