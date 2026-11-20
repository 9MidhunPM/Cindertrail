class_name CinderFrontEnd
extends CanvasLayer

signal begin_journey
signal continue_journey
signal quit_requested
signal settings_closed
signal preferences_changed

const BACKDROP := preload("res://scripts/ui/front_ornament.gd")
const SEAL := preload("res://scripts/ui/front_seal.gd")
const AIR := preload("res://scripts/ui/comic_air.gd")
const COMIC_SHADER := preload("res://scripts/ui/comic_motion.gdshader")
const INK := Color("#102735")
const CREAM := Color("#f7e9ce")
const GOLD := Color("#eac28b")
const MUTED := Color("#acbbc0")
const PAPER := Color("#e9dab9")
const PREFS_PATH := "user://presentation.cfg"
const IMAGES := [
	"res://art/comic/01_valley.webp", "res://art/comic/02_discovery.webp",
	"res://art/comic/03_harness.webp", "res://art/comic/04_crossing.webp"]
const TITLES := ["The long night", "A sun in the ruins", "The traveler’s oath", "The flooded road"]
const CAPTIONS := [
	"First the mornings paled. Then one morning never came. Down in the valley, the old beacons went cold.",
	"Under a fallen arch, something still burned. Three broken rings circled a sun small enough to carry.",
	"The bronze frame folded against the traveler’s back. Through the cloth came the faint warmth of a last ember.",
	"Beyond the flooded grove stood the hilltop beacon. If the old shrines could wake this sun, the valley might see morning again."]
const FOLIOS := ["I", "II", "III", "IV"]

var stage: StringName = &"hidden"
var panel_index := 0
var mouse_sensitivity := 1.0
var reduced_motion := false
var _volume := 0.82
var _has_checkpoint := false
var _replay := false
var _from_pause := false
var _root := Control.new()
var _design := Control.new()
var _back := BACKDROP.new()
var _seal := SEAL.new()
var _menu := VBoxContainer.new()
var _utility := VBoxContainer.new()
var _comic := Control.new()
var _card := Panel.new()
var _caption := VBoxContainer.new()
var _art_frame := Panel.new()
var _image := TextureRect.new()
var _air := AIR.new()
var _ink := ShaderMaterial.new()
var _thumbnails: Array[Button] = []
var _pictures: Array[Texture2D] = []
var _motion_tween: Tween
var _panel_tween: Tween
var _folio: Label
var _heading: Label
var _body: Label
var _next: Button
var _previous: Button
var _skip: Button
var _continue: Button
var _new: Button
var _controls: Button
var _settings: Button
var _back_button: Button
var _serif := SystemFont.new()
var _sans := SystemFont.new()
var _tracked := FontVariation.new()
var _page_title: Label
var _items: VBoxContainer
var _audio := AudioStreamPlayer.new()
var _tone: AudioStreamWAV

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 30
	_serif.font_names = PackedStringArray(["Liberation Serif", "Georgia", "DejaVu Serif"])
	_sans.font_names = PackedStringArray(["Liberation Sans", "Arial", "DejaVu Sans"])
	_tracked.base_font = _sans
	_tracked.spacing_glyph = 3
	_load_settings()
	_tone = _make_chime()
	_audio.stream = _tone
	_audio.volume_db = -13
	add_child(_audio)
	add_child(_root)
	_root.owner = self
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_attach(_root, _design)
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(_design, _back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for path in IMAGES:
		_pictures.append(load(path) as Texture2D)
	_build_menu()
	_build_utility()
	_build_comic()
	_root.resized.connect(_layout)
	_layout()
	show_menu()

func _attach(parent: Node, item: Node) -> void:
	parent.add_child(item)
	item.owner = self

func _text(parent: Control, wording: String, font: Font, pixels: int, tint: Color, center := false) -> Label:
	var label := Label.new()
	label.text = wording
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	if center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach(parent, label)
	return label

func _box(color: Color, border: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.content_margin_left = 15
	box.content_margin_right = 15
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box

func _button(parent: Control, node_name: String, wording: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = wording
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 46
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", _sans)
	b.add_theme_font_size_override("font_size", 21)
	var base := _box(Color("#dcb881"), Color("#f3d69c")) if primary else _box(Color("#142e3b"), Color("#52646a"))
	var active := _box(Color("#f2d4a2"), CREAM)
	if node_name in ["Settings", "Controls", "ReplayPrologue", "Quit"]:
		base = _box(Color("#102735a3"), Color("#9e927b80"), 0)
		base.border_width_bottom = 1
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", active)
	b.add_theme_stylebox_override("pressed", _box(Color("#ca9b61"), CREAM))
	b.add_theme_stylebox_override("disabled", _box(Color("#182d37"), Color("#394b50")))
	var focus := _box(Color.TRANSPARENT, Color("#ffe5b2"), 2)
	focus.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
	b.add_theme_color_override("font_focus_color", INK if primary else CREAM)
	b.add_theme_color_override("font_disabled_color", MUTED)
	_attach(parent, b)
	b.pressed.connect(func() -> void:
		_chime()
		action.call())
	return b

func _gap(parent: Control, height: int) -> void:
	var blank := Control.new()
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blank.custom_minimum_size.y = height
	_attach(parent, blank)

func _rule(parent: Control, tint: Color) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = tint
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(parent, line)

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_attach(parent, row)
	return row

func _build_menu() -> void:
	_attach(_design, _menu)
	_menu.add_theme_constant_override("separation", 7)
	_seal.custom_minimum_size.y = 115
	_attach(_menu, _seal)
	var masthead := _text(_menu, "CINDERTRAIL", _serif, 81, CREAM, true)
	masthead.add_theme_constant_override("outline_size", 2)
	masthead.add_theme_color_override("font_outline_color", Color("#26333b"))
	_text(_menu, "CARRY THE LAST SUNRISE", _tracked, 17, GOLD, true)
	_gap(_menu, 22)
	_rule(_menu, Color(GOLD, 0.48))
	_gap(_menu, 7)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 11)
	_attach(_menu, stack)
	_continue = _button(stack, "ContinueJourney", "Continue journey", _resume, true)
	_new = _button(stack, "NewJourney", "New journey    →", request_new_journey, true)
	var tools := _row(stack)
	_controls = _button(tools, "Controls", "Controls", _show_controls)
	_settings = _button(tools, "Settings", "Settings", show_settings)
	var exits := _row(stack)
	_button(exits, "ReplayPrologue", "Read prologue", _replay_comic)
	_button(exits, "Quit", "Quit", func() -> void: quit_requested.emit())

func _build_utility() -> void:
	_attach(_design, _utility)
	_utility.add_theme_constant_override("separation", 16)
	_text(_utility, "C I N D E R T R A I L", _sans, 15, GOLD)
	_page_title = _text(_utility, "", _serif, 58, CREAM)
	_rule(_utility, Color(GOLD, 0.6))
	_items = VBoxContainer.new()
	_items.add_theme_constant_override("separation", 11)
	_attach(_utility, _items)
	_gap(_utility, 4)
	_back_button = _button(_utility, "BackToTitle", "Back", _exit_utility)

func _build_comic() -> void:
	_attach(_design, _comic)
	_comic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_frame.add_theme_stylebox_override("panel", _box(Color("#122b39"), Color("#a78d67")))
	_attach(_comic, _art_frame)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attach(_art_frame, _image)
	_ink.shader = COMIC_SHADER
	_image.material = _ink
	_attach(_image, _air)
	_card.add_theme_stylebox_override("panel", _box(PAPER, Color("#f6e5c5"), 2))
	_attach(_comic, _card)
	_attach(_card, _caption)
	_caption.add_theme_constant_override("separation", 14)
	_folio = _text(_caption, "", _tracked, 15, Color("#735735"))
	_rule(_caption, Color("#9e855e"))
	_heading = _text(_caption, "", _serif, 49, INK)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body = _text(_caption, "", _serif, 26, Color("#293d43"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 3)
	var strip := _row(_caption)
	strip.add_theme_constant_override("separation", 5)
	for i in _pictures.size():
		var thumb := Button.new()
		thumb.name = "ReadPanel%d" % (i + 1)
		thumb.tooltip_text = TITLES[i]
		thumb.accessibility_name = TITLES[i]
		thumb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		thumb.custom_minimum_size.y = 49
		thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thumb.add_theme_stylebox_override("normal", _box(INK, INK, 1))
		var focus_box := _box(Color.TRANSPARENT, INK, 2)
		focus_box.set_expand_margin_all(3)
		thumb.add_theme_stylebox_override("focus", focus_box)
		_attach(strip, thumb)
		var preview := TextureRect.new()
		preview.texture = _pictures[i]
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attach(thumb, preview)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.offset_left = 3
		preview.offset_top = 3
		preview.offset_right = -3
		preview.offset_bottom = -3
		thumb.pressed.connect(func() -> void:
			_chime()
			_show_panel(i)
			_next.grab_focus())
		_thumbnails.append(thumb)
	var nav := Control.new()
	nav.name = "PageNavigation"
	_attach(_comic, nav)
	_previous = _button(nav, "PreviousPanel", "←  Back", _comic_back)
	_next = _button(nav, "NextPanel", "Next  →", _comic_next, true)
	_skip = _button(nav, "SkipIntro", "Skip prologue", _finish_comic)

func _layout() -> void:
	if _root.size.x < 1.0 or _root.size.y < 1.0:
		return
	var unit := minf(_root.size.y / 850.0, _root.size.x / 650.0)
	_design.scale = Vector2.ONE * unit
	_design.size = _root.size / unit
	var s := _design.size
	var column_x := s.x * 0.751 if s.x >= 1060.0 else s.x * 0.5
	var column_w := minf(544, s.x - 90)
	_center_box(_menu, column_x, column_w)
	_center_box(_utility, column_x, minf(580, s.x - 90))
	var inset := 44.0
	var max_width := minf(s.x - inset * 2, (s.y - inset * 2 - 75) * 2.7)
	var content := Rect2(Vector2((s.x - max_width) * 0.5, inset), Vector2(max_width, s.y - inset * 2 - 75))
	if s.x > s.y * 1.14:
		var paper_width := clampf(content.size.x * 0.30, 365, 475)
		var spread_height := clampf((content.size.x - paper_width - 21) * 9.0 / 16.0 + 14, 490, content.size.y)
		content.position.y += (content.size.y - spread_height) * 0.5
		content.size.y = spread_height
		_art_frame.position = content.position
		_art_frame.size = Vector2(content.size.x - paper_width - 7, content.size.y)
		_card.position = Vector2(_art_frame.position.x + _art_frame.size.x + 7, content.position.y)
		_card.size = Vector2(paper_width, content.size.y)
	else:
		var art_height := minf(content.size.x * 9.0 / 16.0 + 14, content.size.y * 0.53)
		_art_frame.position = content.position
		_art_frame.size = Vector2(content.size.x, art_height)
		_card.position = Vector2(inset, inset + art_height + 7)
		_card.size = Vector2(content.size.x, content.size.y - art_height - 7)
	_caption.size.x = _card.size.x - 64
	_caption.reset_size()
	_caption.size.x = _card.size.x - 64
	_caption.position = Vector2(32, maxf(16, (_card.size.y - _caption.get_combined_minimum_size().y) * 0.5))
	_image.size = _art_frame.size - Vector2.ONE * 14
	_image.position = Vector2.ONE * 7
	_image.pivot_offset = _image.size * 0.5
	var nav := _previous.get_parent() as Control
	nav.position = Vector2(content.position.x, content.end.y + 20)
	nav.size = Vector2(content.size.x, 49)
	_skip.position = Vector2.ZERO
	_skip.size = Vector2(168, 49)
	_next.size = Vector2(198, 49)
	_next.position = Vector2(nav.size.x - _next.size.x, 0)
	_previous.size = Vector2(127, 49)
	_previous.position = Vector2(_next.position.x - _previous.size.x - 12, 0)

func _center_box(box: Control, cx: float, width: float) -> void:
	box.size.x = width
	box.size.y = box.get_combined_minimum_size().y
	box.position = Vector2(roundf(clampf(cx - width * 0.5, 36, _design.size.x - width - 36)), roundf((_design.size.y - box.size.y) * 0.5))

func _switch(which: StringName) -> void:
	stage = which
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_back.comic = which == &"comic"
	_back.queue_redraw()
	_menu.visible = which == &"menu"
	_comic.visible = which == &"comic"
	_utility.visible = which in [&"settings", &"controls", &"confirm"]
	var page: Control = _menu if _menu.visible else (_comic if _comic.visible else _utility)
	if _panel_tween:
		_panel_tween.kill()
	page.modulate.a = 1 if reduced_motion else 0.35
	if not reduced_motion:
		_panel_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_panel_tween.tween_property(page, "modulate:a", 1.0, 0.32)
	_layout()
	_layout.call_deferred()

func show_menu(checkpoint_available: bool = false) -> void:
	_has_checkpoint = checkpoint_available
	_continue.visible = _has_checkpoint
	_from_pause = false
	_switch(&"menu")
	var first := _continue if _has_checkpoint else _new
	first.grab_focus()

func request_new_journey() -> void:
	if not _has_checkpoint:
		show_comic()
		return
	_clear_items()
	_page_title.text = "Begin again?"
	_back_button.text = "Keep current journey"
	var note := _text(_items, "Your saved journey will be replaced when you finish or skip the prologue and enter the valley.", _serif, 27, CREAM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gap(_items, 10)
	_button(_items, "StartNew", "Start a new journey", show_comic, true)
	_switch(&"confirm")
	_back_button.grab_focus()

func show_comic() -> void:
	_open_comic(false)

func _replay_comic() -> void:
	_open_comic(true)

func _open_comic(replay: bool) -> void:
	_replay = replay
	_switch(&"comic")
	_show_panel(0)
	_next.grab_focus()

func _show_panel(index: int) -> void:
	panel_index = index
	_folio.text = "PROLOGUE     /     " + FOLIOS[index] + " OF IV"
	_heading.text = TITLES[index]
	_body.text = CAPTIONS[index]
	_next.text = ("Return to title" if _replay else "Begin journey") if index == 3 else "Next   →"
	_previous.text = "←  Title" if index == 0 else "←  Back"
	_skip.text = "Close prologue" if _replay else "Skip prologue"
	_image.texture = _pictures[index]
	_air.page = index
	_air.clock = 0
	_air.still = reduced_motion
	_air.aspect = float(_image.texture.get_width()) / _image.texture.get_height()
	_air.queue_redraw()
	_ink.set_shader_parameter("page", index)
	_ink.set_shader_parameter("motion_enabled", not reduced_motion)
	_ink.set_shader_parameter("age", 0.0)
	for i in _thumbnails.size():
		var is_current := i == index
		_thumbnails[i].modulate = Color.WHITE if is_current else Color("#afac9f")
		_thumbnails[i].add_theme_stylebox_override("normal", _box(Color("#a36a34") if is_current else INK, INK))
		_thumbnails[i].get_child(0).modulate.a = 1.0 if is_current else 0.74
	_layout()
	_layout.call_deferred()
	if _motion_tween:
		_motion_tween.kill()
	_image.modulate.a = 1.0
	_image.scale = Vector2.ONE
	if not reduced_motion:
		_image.modulate.a = 0.28
		_image.scale = Vector2.ONE * 0.966
		_motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_motion_tween.tween_property(_image, "modulate:a", 1.0, 0.38)
		_motion_tween.tween_property(_image, "scale", Vector2.ONE, 7.0)

func _process(delta: float) -> void:
	if stage == &"comic" and not reduced_motion:
		_air.clock += delta
		_air.queue_redraw()
		_ink.set_shader_parameter("age", _air.clock)

func _comic_next() -> void:
	if panel_index < TITLES.size() - 1:
		_show_panel(panel_index + 1)
	else:
		_finish_comic()

func _comic_back() -> void:
	if panel_index == 0:
		show_menu(_has_checkpoint)
	else:
		_show_panel(panel_index - 1)

func _finish_comic() -> void:
	if _replay:
		show_menu(_has_checkpoint)
	else:
		if not reduced_motion:
			_reveal_valley()
		hide_all()
		begin_journey.emit()

func _reveal_valley() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = layer + 1
	overlay.process_mode = PROCESS_MODE_ALWAYS
	get_parent().add_child(overlay)
	var veil := ColorRect.new()
	veil.color = Color("#101c26")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reveal := veil.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(veil, "modulate:a", 0.0, 0.48)
	reveal.tween_callback(overlay.queue_free)

func _resume() -> void:
	hide_all()
	continue_journey.emit()

func hide_all() -> void:
	stage = &"hidden"
	visible = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus and _root.is_ancestor_of(focus):
		focus.release_focus()

func _clear_items() -> void:
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()

func _show_controls() -> void:
	_clear_items()
	_page_title.text = "Controls"
	_back_button.text = "Back to title"
	for entry in [
		["W A S D", "Move"], ["Ctrl   ·   Shift", "Hold to walk  /  sprint"],
		["Left click   ·   F", "Sunsteel sword: tap for a three-strike combo"],
		["Right click   ·   M", "Sun spark at range  /  open the valley map"],
		["E", "Unfold shrine, repair, open cache, deliver"],
		["1   2   3   ·   Left click", "Select module  /  place on socket"],
		["Space   ·   U", "Start wave  /  upgrade pointed tower"],
		["Hold R", "Recall towers and pack the shrine"],
		["Esc   ·   F10", "Pause  /  toggle HUD"]]:
		var row := _row(_items)
		var keys := _text(row, entry[0], _sans, 19, GOLD)
		keys.custom_minimum_size.x = 214
		var action := _text(row, entry[1], _sans, 19, CREAM)
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_switch(&"controls")
	_back_button.grab_focus()

func show_settings(from_pause: bool = false) -> void:
	_from_pause = from_pause
	_clear_items()
	_page_title.text = "Settings"
	_back_button.text = "Back to pause" if from_pause else "Back to title"
	var volume := _slider("MasterVolume", "Master volume", 0, 1, 0.01, _volume,
		func(value: float) -> String: return "%d%%" % roundi(value * 100))
	volume.value_changed.connect(func(value: float) -> void:
		_volume = value
		_apply_settings()
		_save_settings())
	var sensitivity := _slider("Sensitivity", "Look sensitivity", 0.5, 2.0, 0.05, mouse_sensitivity,
		func(value: float) -> String: return "%.2f×" % value)
	sensitivity.value_changed.connect(func(value: float) -> void:
		mouse_sensitivity = value
		_save_settings()
		preferences_changed.emit())
	_gap(_items, 3)
	var toggle := _button(_items, "ReducedMotion", "", _toggle_motion)
	toggle.text = _motion_label()
	_switch(&"settings")
	volume.grab_focus()

func _slider(node_name: String, label: String, low: float, high: float, step_size: float, initial: float, formatter: Callable) -> HSlider:
	var header := _row(_items)
	var title := _text(header, label, _sans, 22, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var number := _text(header, formatter.call(initial), _sans, 21, GOLD)
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.value = initial
	slider.custom_minimum_size.y = 32
	slider.accessibility_name = label
	slider.add_theme_stylebox_override("slider", _box(Color("#304651"), Color("#59696b")))
	slider.add_theme_stylebox_override("grabber_area", _box(GOLD, GOLD))
	_attach(_items, slider)
	slider.value_changed.connect(func(v: float) -> void: number.text = formatter.call(v))
	return slider

func _motion_label() -> String:
	return "Reduced motion     On" if reduced_motion else "Reduced motion     Off"

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	(_items.get_node("ReducedMotion") as Button).text = _motion_label()
	_apply_settings()
	_save_settings()
	preferences_changed.emit()

func _exit_utility() -> void:
	if _from_pause:
		hide_all()
		settings_closed.emit()
	else:
		var opener := _settings if stage == &"settings" else (_new if stage == &"confirm" else _controls)
		show_menu(_has_checkpoint)
		opener.grab_focus()

func _input(event: InputEvent) -> void:
	if stage == &"hidden" or not event.is_pressed() or event.is_echo():
		return
	if stage == &"comic" and event.is_action_pressed("ui_right"):
		_chime()
		_comic_next()
	elif stage == &"comic" and event.is_action_pressed("ui_left"):
		_chime()
		_comic_back()
	elif event.is_action_pressed("ui_cancel") and stage == &"comic":
		show_menu(_has_checkpoint)
	elif event.is_action_pressed("ui_cancel") and _utility.visible:
		_exit_utility()
	else:
		return
	get_viewport().set_input_as_handled()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		_volume = clampf(float(cfg.get_value("audio", "volume", _volume)), 0, 1)
		mouse_sensitivity = clampf(float(cfg.get_value("controls", "sensitivity", mouse_sensitivity)), 0.5, 2)
		reduced_motion = bool(cfg.get_value("display", "reduced_motion", false))
	_apply_settings()

func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, _volume)))
	AudioServer.set_bus_mute(0, _volume <= 0.0)
	_seal.still = reduced_motion

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", _volume)
	cfg.set_value("controls", "sensitivity", mouse_sensitivity)
	cfg.set_value("display", "reduced_motion", reduced_motion)
	cfg.save(PREFS_PATH)

func _chime() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_audio.pitch_scale = 1.0 + panel_index * 0.025 if stage == &"comic" else 1.0
	_audio.play()

func _make_chime() -> AudioStreamWAV:
	# An original, damped brass dyad for a page turn or menu selection.
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 22050
	var count := roundi(tone.mix_rate * 0.55)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for n in count:
		var t := float(n) / tone.mix_rate
		var env := minf(t * 100.0, 1.0) * exp(-t * 10.5) * minf((0.55 - t) * 50.0, 1.0)
		var sound := sin(TAU * 392.0 * t) + 0.27 * sin(TAU * 587.3 * t)
		pcm.encode_s16(n * 2, roundi(sound * env * 12500.0))
	tone.data = pcm
	return tone
