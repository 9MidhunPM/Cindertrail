class_name CinderHUD
extends CanvasLayer

signal action_requested(action: StringName)

const CREAM := Color("#f7e9c9")
const MUTED := Color("#a7bfc2")
const GOLD := Color("#ffce83")
const TEAL := Color("#64e2d9")
const PALE_RED := Color("#f08a79")
const PANEL := Color(0.022, 0.063, 0.092, 0.9)
const BORDER := Color(0.63, 0.50, 0.31, 0.57)
const MODULES := ["Bolt turret", "Slowing field", "Mortar"]
const ROLE_TEXT := ["Single target", "Slows enemies", "Area damage"]

var _root: Control
var _vitals_panel: PanelContainer
var _location_panel: PanelContainer
var _health: ProgressBar
var _restoration: ProgressBar
var _health_value: Label
var _restoration_value: Label
var _scrap: Label
var _site: Label
var _energy: Label
var _reserve: ProgressBar
var _threat: Label
var _forecast: Label
var _tactical: VBoxContainer
var _module_cards: Array[PanelContainer] = []
var _module_values: Array[Label] = []
var _hint: Label
var _hint_panel: PanelContainer
var _keys: Label
var _keys_panel: PanelContainer
var _pack: ProgressBar
var _status_panel: PanelContainer
var _status: Label
var _overlay: CenterContainer
var _veil: ColorRect
var _title: Label
var _detail: Label
var _buttons: Dictionary[StringName, Button] = {}
var _modal := &""
var _normal_card: StyleBoxFlat
var _selected_card: StyleBoxFlat

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Interface"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme()
	_normal_card = _style(PANEL.darkened(0.08), Color(0.31, 0.48, 0.48, 0.80), Vector2(9, 6))
	_selected_card = _style(Color(0.18, 0.15, 0.10, 0.98), GOLD, Vector2(9, 6))
	_build_vitals()
	_build_location()
	_build_controls()
	_build_status()
	_build_overlay()
	render({})

func render(state: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	var mode := String(state.get("mode", "Explore"))
	var paused := bool(state.get("paused", false))
	var settings_open := bool(state.get("settings_open", false))
	var ended := mode == "Win" or mode == "Lose"
	_vitals_panel.visible = not ended and not paused
	_location_panel.visible = not ended and not paused
	var anchored := mode in ["Prepare", "Defend", "Pack"]
	var selected := int(state.get("selected", -1))
	var socket := int(state.get("socket", -1))
	var health := clampf(float(state.get("health", 100.0)), 0.0, 100.0)
	var restoration := clampf(float(state.get("restoration", 0.0)), 0.0, 100.0)
	_health.value = health
	_restoration.value = restoration
	_health.modulate = Color.WHITE if health > 28.0 else PALE_RED
	_health_value.text = "%d / 100" % ceili(health)
	_restoration_value.text = "%d%%" % floori(restoration)
	_scrap.text = "%d  SCRAP" % int(state.get("scrap", 0))

	var site := String(state.get("site", "")).strip_edges()
	if site.is_empty():
		site = "The valley"
	_site.text = site
	_energy.visible = anchored
	var energy := maxf(float(state.get("energy", 0.0)), 0.0)
	_energy.text = "RESERVE   %.1f%%" % energy
	_reserve.visible = anchored
	_reserve.max_value = maxf(float(state.get("site_energy_max", 100.0)), 1.0)
	_reserve.value = energy
	var threat := maxi(int(state.get("threat", 0)), 0)
	_threat.visible = anchored
	_threat.text = "THREAT  %d  /  %s" % [threat, _threat_label(threat)]
	_threat.modulate = GOLD if threat < 4 else PALE_RED
	var forecast := String(state.get("forecast", "")).strip_edges()
	_forecast.visible = anchored and not forecast.is_empty()
	_forecast.text = forecast

	_tactical.visible = anchored and not ended and not paused
	var module_values: Variant = state.get("modules", PackedStringArray())
	for index in MODULES.size():
		var style := _selected_card if selected == index else _normal_card
		if _module_cards[index].get_theme_stylebox("panel") != style:
			_module_cards[index].add_theme_stylebox_override("panel", style)
		if (module_values is PackedStringArray or module_values is Array) and index < module_values.size():
			_module_values[index].text = str(module_values[index])
		else:
			_module_values[index].text = ROLE_TEXT[index]

	var hint := String(state.get("hint", "")).strip_edges()
	if (mode == "Prepare" or mode == "Defend") and selected >= 0:
		hint = _default_hint(mode, selected, socket, restoration)
	_hint.text = hint if not hint.is_empty() else _default_hint(mode, selected, socket, restoration)
	_hint_panel.visible = not ended and not paused and not _hint.text.is_empty()
	_keys.text = _control_hints(mode, selected)
	_keys_panel.visible = not ended and not paused and not _keys.text.is_empty()
	_pack.visible = mode == "Pack" and not paused
	_pack.value = clampf(float(state.get("pack_progress", 0.0)), 0.0, 1.0) * 100.0
	_status.text = String(state.get("status", "")).strip_edges()
	var repeats_forecast := _forecast.visible and _status.text.contains(forecast)
	_status_panel.visible = not ended and not paused and not _status.text.is_empty() and not repeats_forecast
	_show_overlay(
		mode, paused, settings_open,
		bool(state.get("checkpoint_available", false)),
		String(state.get("checkpoint_hint", ""))
	)

func modal_open() -> bool:
	return visible and _modal != &""

func _build_vitals() -> void:
	_vitals_panel = _panel(Vector2(16, 10))
	var shell := _vitals_panel
	_pin(shell, 0.0, 0.0, 24.0, 24.0)
	shell.custom_minimum_size.x = 254
	var stack := _vertical(shell, 8)
	var seal := _horizontal(stack, 10)
	var glyph := HudGlyph.new()
	glyph.kind = HudGlyph.Kind.SUN
	glyph.custom_minimum_size = Vector2(23, 24)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(glyph)
	var heading := _label("Sun shrine", &"Title")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.add_child(heading)
	_scrap = _label("0  SCRAP", &"Accent")
	seal.add_child(_scrap)
	_health_value = _label("100 / 100", &"Value")
	_health = _stat(stack, "INTEGRITY", _health_value, &"Health")
	_restoration_value = _label("0%", &"Value")
	_restoration = _stat(stack, "RESTORATION", _restoration_value, &"Restoration")

func _build_location() -> void:
	_location_panel = _panel(Vector2(14, 9))
	var shell := _location_panel
	_pin(shell, 1.0, 0.0, -24.0, 24.0)
	shell.custom_minimum_size.x = 228
	var stack := _vertical(shell, 5)
	_site = _label("The valley", &"Location")
	_site.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack.add_child(_site)
	_energy = _label("", &"Caption")
	_energy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack.add_child(_energy)
	_reserve = _meter(&"Restoration")
	_reserve.custom_minimum_size.y = 4.0
	_reserve.accessibility_name = "Site energy reserve"
	stack.add_child(_reserve)
	_threat = _label("", &"Value")
	_threat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack.add_child(_threat)
	_forecast = _label("", &"Body")
	_forecast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_forecast.custom_minimum_size.x = 240.0
	stack.add_child(_forecast)

func _build_controls() -> void:
	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 8)
	_pin(footer, 0.5, 1.0, 0.0, -22.0)
	_tactical = _vertical(footer, 0)
	var rack := _horizontal(_tactical, 8)
	rack.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in MODULES.size():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(158, 68)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _normal_card)
		rack.add_child(card)
		_module_cards.append(card)
		var card_row := _horizontal(card, 7)
		var glyph := HudGlyph.new()
		glyph.kind = index + 1
		glyph.custom_minimum_size = Vector2(42, 45)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_child(glyph)
		var card_text := _vertical(card_row, 0)
		card_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_text.add_child(_label("%d   %s" % [index + 1, MODULES[index]], &"Module"))
		var subtitle := _label(ROLE_TEXT[index], &"Caption")
		card_text.add_child(subtitle)
		_module_values.append(subtitle)

	_hint_panel = _panel(Vector2(15, 7), footer)
	_hint = _label("", &"Body")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)
	_keys_panel = _panel(Vector2(13, 5), footer)
	_keys = _label("", &"Caption")
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys_panel.add_child(_keys)
	_pack = _meter(&"Health")
	footer.add_child(_pack)

func _build_status() -> void:
	_status_panel = _panel(Vector2(11, 6))
	_pin(_status_panel, 0.5, 0.0, 0.0, 26.0)
	_status = _label("", &"Accent")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_panel.add_child(_status)

func _build_overlay() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.012, 0.032, 0.05, 0.64)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.hide()
	_overlay = CenterContainer.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	var panel := _panel(Vector2(38, 26), _overlay)
	panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.062, 0.083, 0.97), BORDER, Vector2(38, 26), 3))
	panel.custom_minimum_size.x = 428
	var stack := _vertical(panel, 14)
	var ornament := HudGlyph.new()
	ornament.kind = HudGlyph.Kind.SUN
	ornament.custom_minimum_size.y = 43.0
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(ornament)
	_title = _label("", &"Ending")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_title)
	_detail = _label("", &"Body")
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_detail)
	var actions := _vertical(stack, 7)
	_add_action(actions, &"resume", "Resume journey")
	_add_action(actions, &"settings", "Settings")
	_add_action(actions, &"checkpoint", "Retry from checkpoint")
	_add_action(actions, &"restart", "Start a fresh journey")
	_add_action(actions, &"title", "Return to title")

func _add_action(container: VBoxContainer, action: StringName, text: String) -> void:
	var button := Button.new()
	button.name = String(action).capitalize()
	button.text = text
	button.custom_minimum_size.y = 44.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: action_requested.emit(action))
	_buttons[action] = button
	container.add_child(button)

func _show_overlay(
	mode: String, paused: bool, settings_open: bool, checkpoint_available: bool, checkpoint_hint: String
) -> void:
	var next := &""
	if not settings_open:
		match mode:
			"Win":
				next = &"victory"
			"Lose":
				next = &"defeat_checkpoint" if checkpoint_available else &"defeat"
			_:
				if paused:
					next = &"pause"
	if next == &"pause":
		_detail.text = checkpoint_hint
		_detail.visible = not checkpoint_hint.is_empty()
	if next == _modal:
		return
	_modal = next
	_overlay.visible = _modal != &""
	_veil.visible = _overlay.visible and _modal != &"victory"
	_overlay.anchor_top = 0.58 if _modal == &"victory" else 0.0
	_overlay.offset_top = 0.0
	var actions: Array[StringName] = []
	match _modal:
		&"victory":
			_title.text = "The last sunrise"
			_detail.text = "Dawn returns to the valley."
			actions = [&"title"]
		&"defeat", &"defeat_checkpoint":
			_title.text = "The light went out"
			_detail.text = "The shrine has fallen."
			actions = [&"restart", &"title"]
			if checkpoint_available:
				actions.push_front(&"checkpoint")
		&"pause":
			_title.text = "Journey paused"
			actions = [&"resume", &"settings", &"title"]
	_detail.visible = not _detail.text.is_empty()
	for action in _buttons:
		_buttons[action].visible = actions.has(action)
	if not actions.is_empty():
		_focus_actions(actions)

func _focus_actions(actions: Array[StringName]) -> void:
	for index in actions.size():
		var button := _buttons[actions[index]]
		var previous := _buttons[actions[posmod(index - 1, actions.size())]]
		var next := _buttons[actions[(index + 1) % actions.size()]]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
	var first := _buttons[actions[0]]
	first.grab_focus.call_deferred()

func _default_hint(mode: String, selected: int, socket: int, restoration: float) -> String:
	match mode:
		"Deploy":
			return "Unfolding the shrine"
		"Pack":
			return "Keep holding R to recall the towers and carry the shrine."
		"Prepare", "Defend":
			if selected >= 0 and selected < MODULES.size():
				if socket >= 0:
					return "LMB  Place %s on socket %d" % [MODULES[selected], socket + 1]
				return "Choose a dry socket for %s." % MODULES[selected].to_lower()
			return "SPACE  Start the wave" if mode == "Prepare" else ""
		_:
			return "Carry the restored sun to the hilltop beacon." if restoration >= 100.0 else ""

func _control_hints(mode: String, selected: int) -> String:
	match mode:
		"Prepare", "Defend":
			var keys := "1–3 Select  ·  U Upgrade  ·  E Repair  ·  RMB Fire  ·  Hold R Pack"
			if selected >= 0:
				keys += "  ·  Esc Cancel"
			return keys
		"Explore", "Transit":
			return "WASD Move  ·  Ctrl Walk  ·  Shift Sprint  ·  Mouse Look  ·  E Interact  ·  LMB Fire  ·  Esc Pause"
		_:
			return ""

func _threat_label(level: int) -> String:
	if level >= 6:
		return "SEVERE"
	if level >= 4:
		return "HIGH"
	if level >= 2:
		return "RISING"
	return "LOW"

func _pin(control: Control, horizontal: float, vertical: float, x: float, y: float) -> void:
	if control.get_parent() == null:
		_root.add_child(control)
	control.anchor_left = horizontal
	control.anchor_right = horizontal
	control.anchor_top = vertical
	control.anchor_bottom = vertical
	control.offset_left = x
	control.offset_right = x
	control.offset_top = y
	control.offset_bottom = y
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH if horizontal == 0.5 else (
		Control.GROW_DIRECTION_BEGIN if horizontal == 1.0 else Control.GROW_DIRECTION_END
	)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if vertical == 1.0 else Control.GROW_DIRECTION_END

func _panel(padding: Vector2, parent: Control = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER, padding))
	if parent != null:
		parent.add_child(panel)
	return panel

func _horizontal(parent: Control, gap: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _vertical(parent: Control, gap: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _label(value: String, variation: StringName) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = variation
	label.text = value
	return label

func _stat(parent: Control, caption: String, value: Label, color_profile: StringName) -> ProgressBar:
	var block := _vertical(parent, 3)
	var row := _horizontal(block, 6)
	row.add_child(_label(caption, &"Caption"))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var meter := _meter(color_profile)
	meter.accessibility_name = caption.capitalize()
	block.add_child(meter)
	return meter

func _meter(variation: StringName) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = 6.0
	bar.show_percentage = false
	bar.theme_type_variation = variation
	return bar

func _theme() -> Theme:
	var theme := Theme.new()
	var body := SystemFont.new()
	body.font_names = PackedStringArray(["Adwaita Sans", "Liberation Sans", "DejaVu Sans"])
	body.font_weight = 500
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Cinzel", "Cormorant Garamond", "Liberation Serif", "DejaVu Serif"])
	serif.font_weight = 600
	theme.default_font = body
	for entry in [
		[&"Caption", 14, MUTED], [&"Module", 17, CREAM], [&"Body", 17, CREAM],
		[&"Value", 15, CREAM], [&"Accent", 15, GOLD], [&"Title", 22, CREAM],
		[&"Location", 27, CREAM], [&"Ending", 47, CREAM]
	]:
		var variation: StringName = entry[0]
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size("font_size", variation, entry[1])
		theme.set_color("font_color", variation, entry[2])
		if variation in [&"Title", &"Location", &"Ending"]:
			theme.set_font("font", variation, serif)
	for entry in [[&"Health", GOLD], [&"Restoration", TEAL]]:
		var variation: StringName = entry[0]
		theme.set_type_variation(variation, &"ProgressBar")
		theme.set_stylebox("background", variation, _style(Color("#1b3037"), Color("#547179"), Vector2.ZERO, 2))
		theme.set_stylebox("fill", variation, _style(entry[1], Color.TRANSPARENT, Vector2.ZERO, 2))
	var buttons := &"Button"
	theme.set_font_size("font_size", buttons, 19)
	theme.set_color("font_color", buttons, CREAM)
	theme.set_color("font_focus_color", buttons, CREAM)
	theme.set_color("font_hover_color", buttons, Color("#0b1928"))
	theme.set_color("font_pressed_color", buttons, Color("#0b1928"))
	theme.set_color("font_hover_pressed_color", buttons, Color("#0b1928"))
	theme.set_stylebox("normal", buttons, _style(Color("#102c38"), BORDER, Vector2(12, 6), 3))
	theme.set_stylebox("hover", buttons, _style(GOLD, GOLD, Vector2(12, 6), 3))
	theme.set_stylebox("pressed", buttons, _style(Color("#c59a61"), GOLD, Vector2(12, 6), 3))
	var focus := _style(Color.TRANSPARENT, GOLD, Vector2.ZERO, 3)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", buttons, focus)
	return theme

func _style(fill: Color, border: Color, margin: Vector2, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style

class HudGlyph extends Control:
	enum Kind { SUN, BOLT, FIELD, MORTAR }

	const BRONZE := Color("#977147")
	const BRASS := Color("#e6b674")
	const AMBER := Color("#ffdf92")
	const AQUA := Color("#67eddf")
	const TEAL_DARK := Color("#208d91")

	var kind: int

	func _draw() -> void:
		var center := size * 0.5
		var scale_factor := minf(size.x, size.y) / 32.0
		draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
		match kind:
			Kind.SUN:
				draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, BRASS, 1.5, true)
				draw_circle(Vector2.ZERO, 5.4, AMBER, true, -1.0, true)
				for index in 8:
					var ray := Vector2.from_angle(index * TAU / 8.0)
					draw_line(ray * 11.0, ray * 14.0, BRASS, 1.5, true)
			Kind.BOLT:
				_shape([Vector2(-13, 12), Vector2(12, 12), Vector2(15, 8), Vector2(-9, 8)], BRONZE)
				_shape([Vector2(-9, 8), Vector2(-5, -4), Vector2(0, -4), Vector2(-2, 8)], BRASS)
				_shape([Vector2(5, 9), Vector2(-3, -1), Vector2(1, -7), Vector2(9, 8)], BRONZE)
				_shape([Vector2(-10, -3), Vector2(-5, -10), Vector2(11, -9), Vector2(7, -3)], BRASS)
				draw_line(Vector2(-6, -4), Vector2(12, -8), AMBER, 2.3, true)
				draw_line(Vector2(10, -12), Vector2(14, -9), AMBER, 1.5, true)
			Kind.FIELD:
				_shape([Vector2(-11, 12), Vector2(11, 12), Vector2(13, 8), Vector2(-10, 8)], BRONZE)
				_shape([Vector2(-7, 8), Vector2(-4, -3), Vector2(4, -3), Vector2(7, 8)], TEAL_DARK)
				_shape([Vector2(-12, -3), Vector2(-9, -8), Vector2(-3, -12), Vector2(5, -12),
					Vector2(11, -7), Vector2(13, -2), Vector2(7, 0), Vector2(-7, 0)], AQUA)
				draw_line(Vector2(-12, -2), Vector2(12, -2), Color("#c4fff2"), 1.25, true)
			Kind.MORTAR:
				_shape([Vector2(-12, 12), Vector2(12, 12), Vector2(14, 8), Vector2(-10, 8)], BRONZE)
				_shape([Vector2(-8, 8), Vector2(-5, 1), Vector2(5, 1), Vector2(8, 8)], BRASS)
				_shape([Vector2(-11, -8), Vector2(10, -8), Vector2(7, 1), Vector2(3, 4), Vector2(-6, 3)],
					Color("#e9d9bd"))
				_shape([Vector2(-11, -8), Vector2(-7, -11), Vector2(6, -11), Vector2(10, -8),
					Vector2(6, -5), Vector2(-7, -5)], Color("#51402b"))
				draw_line(Vector2(-7, -11), Vector2(6, -11), Color("#fff2d8"), 1.4, true)

	func _shape(points: Array[Vector2], color: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), color)
