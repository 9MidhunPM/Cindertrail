extends SceneTree
## Use temporary XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1.
## A native run with -- --out=/absolute/path also captures all twelve pages.

const FRONT := preload("res://scenes/ui/front_end.tscn")
const PROLOGUE := preload("res://scripts/ui/prologue_pages.gd")
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2520, 1080)]

var _front: CinderFrontEnd
var _view: SubViewport
var _started := 0
var _resumed := 0
var _returned := 0
var _failures := 0
var _output := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not OS.has_environment("CINDERTRAIL_TEST_SAVE"):
		push_error("Use an isolated XDG_DATA_HOME and CINDERTRAIL_TEST_SAVE=1")
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_output = argument.trim_prefix("--out=")
	if not _output.is_empty() and (DisplayServer.get_name() == "headless" or not _output.is_absolute_path()
			or DirAccess.make_dir_recursive_absolute(_output) != OK):
		push_error("Image capture requires a native display and an absolute output folder")
		quit(2)
		return
	var checkpoint := {"restoration": 43.0, "scrap": 24, "position": Vector3(-3.4, .73, 16.0)}
	_expect(JourneyCheckpoint.write(checkpoint), "Write an isolated checkpoint")
	var container := SubViewportContainer.new()
	root.add_child(container)
	_view = SubViewport.new()
	_view.size = RESOLUTIONS[0]
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_view)
	_front = FRONT.instantiate() as CinderFrontEnd
	_view.add_child(_front)
	_front.begin_journey.connect(func(): _started += 1)
	_front.continue_journey.connect(func(): _resumed += 1)
	_front.settings_closed.connect(func(): _returned += 1)
	_front.reduced_motion = true
	_front.show_menu(true)
	await process_frame
	_button("ReplayPrologue").pressed.emit()
	_expect(_front.panel_index == 0 and _front.stage == &"comic", "Read Prologue opens page one")
	_key(KEY_RIGHT)
	_expect(_front.panel_index == 1, "Right arrow advances")
	_key(KEY_LEFT)
	_expect(_front.panel_index == 0, "Left arrow returns")
	_button("Chapter2").pressed.emit()
	_expect(_front.panel_index == 4 and _button("Chapter2").button_pressed, "The second chapter opens at page five")
	_button("Chapter3").pressed.emit()
	_expect(_front.panel_index == 8 and _button("Chapter3").button_pressed, "The final chapter opens at page nine")
	_expect(PROLOGUE.PAGES.size() == 12, "The narrative has twelve pages")
	var plates := {}
	for index in PROLOGUE.PAGES.size():
		var page: Dictionary = PROLOGUE.PAGES[index]
		plates[page.image] = true
		var words := String(page.caption).split(" ", false).size()
		_expect(words >= 30 and words <= 55, "Page %d caption length" % (index + 1))
		_expect(ResourceLoader.exists(page.image, "Texture2D"), "Page %d illustration imports" % (index + 1))
	_expect(plates.size() == 12, "Each page has a distinct illustration")
	for resolution in RESOLUTIONS:
		_view.size = resolution
		await process_frame
		for index in PROLOGUE.PAGES.size():
			_front._show_panel(index)
			await process_frame
			_expect(_fits(), "Page %d fits %d×%d" % [index + 1, resolution.x, resolution.y], false)
			if resolution == RESOLUTIONS[0]:
				_expect(_front._image.texture.resource_path == PROLOGUE.PAGES[index].image,
					"Page %d displays its own full-size artwork" % (index + 1), false)
			if resolution == RESOLUTIONS[0] and not _output.is_empty():
				await RenderingServer.frame_post_draw
				var frame := _view.get_texture().get_image()
				_expect(frame.save_png(_output.path_join("prologue-%02d.png" % (index + 1))) == OK,
					"Capture page %d" % (index + 1))
	_expect(_front._image.scale == Vector2.ONE and _front._air.still
		and not bool(_front._ink.get_shader_parameter("motion_enabled")), "Reduced motion holds illustration and particles still")
	_button("NextPanel").grab_focus()
	_key(KEY_SPACE)
	_expect(_front.stage == &"menu" and _started == 0 and JourneyCheckpoint.read() == checkpoint,
		"Finishing a Replay returns to title and preserves the checkpoint")
	_button("NewJourney").pressed.emit()
	_expect(_front.stage == &"confirm", "New Journey prompts before replacing a checkpoint")
	_button("StartNew").pressed.emit()
	_key(KEY_ESCAPE)
	_expect(_front.stage == &"menu" and _started == 0 and JourneyCheckpoint.read() == checkpoint,
		"Backing out of the prologue preserves the checkpoint")
	_button("NewJourney").pressed.emit()
	_button("StartNew").pressed.emit()
	_button("SkipIntro").pressed.emit()
	_front._finish_comic()
	_expect(_front.stage == &"hidden" and _started == 1, "Skipping starts gameplay once")
	_front.show_menu(true)
	_button("ContinueJourney").pressed.emit()
	_expect(_front.stage == &"hidden" and _resumed == 1 and _started == 1, "Continue resumes directly")
	_front.reduced_motion = false
	_front.show_comic()
	_front._show_panel(PROLOGUE.PAGES.size() - 1)
	_expect(bool(_front._ink.get_shader_parameter("motion_enabled")), "Standard motion animates the final plate")
	_button("NextPanel").grab_focus()
	_key(KEY_SPACE)
	_expect(_front.stage == &"hidden" and _started == 2, "Keyboard begins the journey from the last panel")
	var dissolve := _view.get_node_or_null("PrologueDissolve")
	_expect(dissolve != null and dissolve.get_child(0).get_child_count() == 1,
		"The final illustration stays visible during the dissolve")
	_front.reduced_motion = true
	_front.achievement_rows = func() -> Array:
		return [{"title": "Reed Snare", "description": "Fully drain Flooded Grove.",
			"unlocked": true, "icon": load(PROLOGUE.PAGES.back().image)}]
	_front.show_menu(true)
	_button("ReadAchievements").pressed.emit()
	_expect(_front.stage == &"achievements" and _front._items.get_child_count() == 1,
		"Title shows records from the profile provider")
	_front.show_achievements(true)
	_button("BackToTitle").pressed.emit()
	_expect(_front.stage == &"hidden" and _returned == 1, "Closing achievements returns to pause")
	_front.queue_free()
	await process_frame
	print("PROLOGUE_SMOKE failures=", _failures)
	quit(1 if _failures else 0)

func _button(button_name: String) -> Button:
	return _front.find_child(button_name, true, false) as Button

func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	_view.push_input(press)
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	_view.push_input(release)

func _fits() -> bool:
	var viewport_bounds := Rect2(Vector2.ZERO, Vector2(_view.size))
	for item: Control in [_front._art_frame, _front._card, _front._previous, _front._next, _front._skip]:
		if not viewport_bounds.encloses(item.get_global_rect()):
			return false
	return _front._caption.get_combined_minimum_size().y <= _front._card.size.y - 30.0

func _expect(condition: bool, detail: String, report := true) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL " + detail)
	elif report:
		print("PASS ", detail)
