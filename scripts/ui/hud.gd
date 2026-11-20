class_name CinderHUD
extends CanvasLayer
## In-game interface. Observes the run through render(state); never owns gameplay truth.
## Layout: shrine vitals top-left, objective and wave status top-centre, minimap
## top-right, context prompt and defense build bar bottom-centre, controls bottom-left.

signal action_requested(action: StringName)

const CREAM := Color("#f7e9c9")
const MUTED := Color("#a7bfc2")
const GOLD := Color("#ffce83")
const TEAL := Color("#64e2d9")
const PALE_RED := Color("#f08a79")
const PANEL := Color(0.022, 0.063, 0.092, 0.88)
const BORDER := Color(0.63, 0.50, 0.31, 0.57)
const MODULES := ["Bolt turret", "Slowing field", "Mortar"]
const ROLE_TEXT := ["Single target", "Slows enemies", "Area damage"]
const PROMPT := "^(Hold [A-Za-z]+|LMB|RMB|Space|Esc|[A-Z0-9])\\s{2,}(.+)$"
const BANNERS := {
	"Prepare": ["DEFENSE", "Place towers on the glowing sockets, then press Space"],
	"Transit": ["ON THE ROAD", "New waves are paused  ·  creatures already hunting you still follow"],
	"Win": ["", ""], "Lose": ["", ""],
}

var game: Node
var minimap: CinderMinimap
var overlay: CinderWorldOverlay
var _root: Control
var _vitals_panel: PanelContainer
var _health: ProgressBar
var _restoration: ProgressBar
var _health_value: Label
var _restoration_value: Label
var _scrap: Label
var _beacon_note: Label
var _objective_panel: PanelContainer
var _objective: Label
var _objective_caption: Label
var _wave_panel: PanelContainer
var _wave_title: Label
var _wave_detail: Label
var _wave_bar: ProgressBar
var _reserve_bar: ProgressBar
var _reserve_label: Label
var _threat: Label
var _map_frame: Control
var _region: Label
var _full_map: PanelContainer
var _big_map: CinderMinimap
var _tactical: VBoxContainer
var _module_cards: Array[PanelContainer] = []
var _module_names: Array[Label] = []
var _module_values: Array[Label] = []
var _module_detail: Label
var _prompt_panel: PanelContainer
var _prompt_key: Label
var _prompt_key_panel: PanelContainer
var _prompt_text: Label
var _keys_panel: PanelContainer
var _keys: Label
var _pack: ProgressBar
var _toast_box: VBoxContainer
var _last_status := ""
var _banner: Control
var _banner_title: Label
var _banner_detail: Label
var _banner_tween: Tween
var _last_mode := ""
var _vignette: ColorRect
var _hurt := 0.0
var _last_health := 100.0
var _overlay: CenterContainer
var _veil: ColorRect
var _title: Label
var _detail: Label
var _buttons: Dictionary[StringName, Button] = {}
var _modal := &""
var _normal_card: StyleBoxFlat
var _selected_card: StyleBoxFlat
var _poor_card: StyleBoxFlat
var _prompt_matcher := RegEx.create_from_string(PROMPT)

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Interface"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme()
	_normal_card = _style(PANEL.darkened(0.08), Color(0.31, 0.48, 0.48, 0.80), Vector2(10, 7))
	_selected_card = _style(Color(0.20, 0.16, 0.09, 0.98), GOLD, Vector2(10, 7))
	_selected_card.set_border_width_all(2)
	_poor_card = _style(Color(0.06, 0.06, 0.07, 0.82), Color(0.45, 0.30, 0.28, 0.7), Vector2(10, 7))
	_build_vignette()
	overlay = CinderWorldOverlay.new()
	_root.add_child(overlay)
	_build_vitals()
	_build_objective()
	_build_map()
	_build_controls()
	_build_toasts()
	_build_banner()
	_build_full_map()
	_build_overlay()
	render({})

## Attach world readers once the run exists: minimap, full map and world labels.
func bind(world: Node) -> void:
	game = world
	minimap.bind(world)
	_big_map.bind(world)
	overlay.bind(world)

func render(state: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	var mode := String(state.get("mode", "Explore"))
	var paused := bool(state.get("paused", false))
	var settings_open := bool(state.get("settings_open", false))
	var ended := mode == "Win" or mode == "Lose"
	var map_open := bool(state.get("map_open", false))
	var calm := not ended and not paused and not map_open
	var anchored := mode in ["Prepare", "Defend", "Pack"]
	var selected := int(state.get("selected", -1))
	var scrap := int(state.get("scrap", 0))
	var health := clampf(float(state.get("health", 100.0)), 0.0, 100.0)
	var restoration := clampf(float(state.get("restoration", 0.0)), 0.0, 100.0)

	_vitals_panel.visible = calm
	_health.value = health
	_restoration.value = restoration
	_health.modulate = Color.WHITE if health > 30.0 else PALE_RED
	_health_value.text = "%d / 100" % ceili(health)
	_restoration_value.text = "%d%%" % floori(restoration)
	_scrap.text = "%d" % scrap
	_beacon_note.text = "Sun restored  ·  Hilltop Beacon" if restoration >= 99.9 else "Restore to 100% to reach the final defense"
	_beacon_note.modulate = GOLD if restoration >= 99.9 else MUTED
	if health < _last_health - 0.01:
		_hurt = minf(1.0, _hurt + (_last_health - health) * 0.09 + 0.25)
	_last_health = health

	var objective := String(state.get("objective", "")).strip_edges()
	var distance := float(state.get("objective_distance", -1.0))
	_objective_panel.visible = calm and not objective.is_empty()
	_objective.text = objective + ("   ·   %d m" % roundi(distance) if distance > 6.0 else "")
	minimap.objective = state.get("objective_point", Vector3.INF)

	_map_frame.visible = calm
	var site := String(state.get("site", "")).strip_edges()
	_region.text = site if not site.is_empty() else String(state.get("region", "The valley"))

	_wave_panel.visible = calm and anchored
	if anchored:
		var wave := int(state.get("wave", 0))
		var active := bool(state.get("wave_active", false))
		var left := int(state.get("wave_left", 0))
		var total := maxi(int(state.get("wave_total", 1)), 1)
		var next := float(state.get("next_wave", -1.0))
		var forecast := String(state.get("forecast", ""))
		var summit := bool(state.get("at_summit", false))
		if summit:
			_wave_title.text = "VESPER COLOSSUS"
			_wave_detail.text = str(state.get("guardian_phase", "Awaiting challenge"))
			_wave_bar.value = float(state.get("guardian_health", 100.0))
		elif active:
			_wave_title.text = "WAVE %d" % wave
			_wave_detail.text = "%d of %d creatures remain" % [left, total]
			_wave_bar.value = 100.0 * (1.0 - float(left) / total)
		elif next >= 0.0 and bool(state.get("engaged", false)):
			_wave_title.text = "NEXT WAVE IN %d" % ceili(next)
			_wave_detail.text = forecast
			_wave_bar.value = 100.0 * (1.0 - next / maxf(float(state.get("breather", 5.0)), 0.1))
		else:
			_wave_title.text = "READY TO DEFEND"
			_wave_detail.text = "Next: " + forecast if not forecast.is_empty() else ""
			_wave_bar.value = 0.0
		_wave_detail.visible = not _wave_detail.text.is_empty()
		var energy := maxf(float(state.get("energy", 0.0)), 0.0)
		var energy_max := maxf(float(state.get("site_energy_max", 25.0)), 1.0)
		_reserve_bar.max_value = energy_max
		_reserve_bar.value = energy
		_reserve_label.text = "SITE ENERGY  %.1f / %.0f" % [energy, energy_max]
		var threat := maxi(int(state.get("threat", 0)), 0)
		_threat.text = "THREAT %s" % _threat_label(threat)
		_threat.modulate = GOLD if threat < 4 else PALE_RED
		_reserve_bar.visible = not summit
		_reserve_label.visible = not summit
		_threat.visible = not summit

	_tactical.visible = calm and anchored and mode != "Pack"
	var prices: Array = state.get("prices", [])
	var owned: Array = state.get("owned", [])
	var summaries: Array = state.get("summaries", [])
	for index in MODULES.size():
		var price := int(prices[index]) if index < prices.size() else 0
		var level := int(owned[index]) if index < owned.size() else 0
		var affordable := level > 0 or scrap >= price
		var style := _selected_card if selected == index else (_normal_card if affordable else _poor_card)
		if _module_cards[index].get_theme_stylebox("panel") != style:
			_module_cards[index].add_theme_stylebox_override("panel", style)
		_module_cards[index].modulate = Color.WHITE if affordable or selected == index else Color(1, 1, 1, 0.62)
		if level > 0:
			_module_values[index].text = "Owned  ·  Lv %d  ·  free" % level
			_module_values[index].modulate = TEAL
		elif price > 0:
			_module_values[index].text = "%d scrap" % price if affordable else "%d scrap  ·  need %d" % [price, price - scrap]
			_module_values[index].modulate = GOLD if affordable else PALE_RED
		else:
			_module_values[index].text = ROLE_TEXT[index]
	var detail_index := selected
	_module_detail.visible = detail_index >= 0 and detail_index < summaries.size()
	if _module_detail.visible:
		_module_detail.text = "%s  —  %s" % [MODULES[detail_index], summaries[detail_index]]

	var hint := String(state.get("hint", "")).strip_edges()
	if anchored and selected >= 0:
		hint = "LMB  Click a glowing socket to build  ·  Esc to cancel"
	_set_prompt(hint)
	_prompt_panel.visible = calm and not hint.is_empty()
	_keys.text = _control_hints(mode, selected)
	_keys_panel.visible = calm and not _keys.text.is_empty()
	_pack.visible = mode == "Pack" and not paused
	_pack.value = clampf(float(state.get("pack_progress", 0.0)), 0.0, 1.0) * 100.0

	var status := String(state.get("status", "")).strip_edges()
	if status != _last_status:
		_last_status = status
		if not status.is_empty() and calm:
			_toast(status)
	if mode != _last_mode:
		if _last_mode != "" and BANNERS.has(mode) and not String(BANNERS[mode][0]).is_empty():
			_show_banner(BANNERS[mode][0], BANNERS[mode][1])
		_last_mode = mode
	_full_map.visible = map_open
	overlay.visible = calm
	overlay.socket_text = String(state.get("socket_text", ""))
	overlay.socket_ok = bool(state.get("socket_ok", true))
	overlay.socket_point = state.get("socket_point", Vector3.INF)
	_show_overlay(mode, paused, settings_open, bool(state.get("checkpoint_available", false)),
		String(state.get("checkpoint_hint", "")), String(state.get("summary", "")))

func modal_open() -> bool:
	return visible and _modal != &""

func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta * 1.6)
	_vignette.material.set_shader_parameter("strength", _hurt)
	_vignette.visible = _hurt > 0.01

func _set_prompt(hint: String) -> void:
	var found := _prompt_matcher.search(hint)
	_prompt_key_panel.visible = found != null
	if found:
		_prompt_key.text = found.get_string(1).to_upper()
		_prompt_text.text = found.get_string(2)
	else:
		_prompt_text.text = hint

# ---------------------------------------------------------------- construction

func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://scripts/ui/hurt_vignette.gdshader")
	_vignette.material = ink
	_root.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.hide()

func _build_vitals() -> void:
	_vitals_panel = _panel(Vector2(16, 12))
	_pin(_vitals_panel, 0.0, 0.0, 24.0, 22.0)
	_vitals_panel.custom_minimum_size.x = 300
	var stack := _vertical(_vitals_panel, 8)
	var seal := _horizontal(stack, 10)
	seal.add_child(_glyph(HudGlyph.Kind.SUN, Vector2(26, 26)))
	var heading := _label("Sun shrine", &"Title")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.add_child(heading)
	var purse := _horizontal(seal, 5)
	purse.add_child(_glyph(HudGlyph.Kind.SCRAP, Vector2(18, 18)))
	_scrap = _label("0", &"Accent")
	purse.add_child(_scrap)
	purse.add_child(_label("scrap", &"Caption"))
	_health_value = _label("100 / 100", &"Value")
	_health = _stat(stack, "SHRINE INTEGRITY", _health_value, &"Health")
	_health.custom_minimum_size.y = 9.0
	_restoration_value = _label("0%", &"Value")
	_restoration = _stat(stack, "SUN RESTORED", _restoration_value, &"Restoration")
	_restoration.custom_minimum_size.y = 9.0
	_beacon_note = _label("", &"Caption")
	stack.add_child(_beacon_note)

func _build_objective() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_pin(column, 0.5, 0.0, 0.0, 22.0)
	_objective_panel = _panel(Vector2(20, 8), column)
	var objective_stack := _vertical(_objective_panel, 1)
	_objective_caption = _label("OBJECTIVE", &"Caption")
	_objective_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_stack.add_child(_objective_caption)
	_objective = _label("", &"Objective")
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_stack.add_child(_objective)
	_wave_panel = _panel(Vector2(18, 10), column)
	_wave_panel.custom_minimum_size.x = 420
	var wave := _vertical(_wave_panel, 5)
	var heading := _horizontal(wave, 10)
	_wave_title = _label("", &"Wave")
	_wave_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_wave_title)
	_threat = _label("", &"Accent")
	heading.add_child(_threat)
	_wave_bar = _meter(&"Health")
	_wave_bar.custom_minimum_size.y = 6.0
	wave.add_child(_wave_bar)
	_wave_detail = _label("", &"Body")
	_wave_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave.add_child(_wave_detail)
	_reserve_label = _label("", &"Caption")
	wave.add_child(_reserve_label)
	_reserve_bar = _meter(&"Restoration")
	_reserve_bar.custom_minimum_size.y = 5.0
	wave.add_child(_reserve_bar)

func _build_map() -> void:
	_map_frame = VBoxContainer.new()
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_frame.add_theme_constant_override("separation", 6)
	_pin(_map_frame, 1.0, 0.0, -24.0, 20.0)
	minimap = CinderMinimap.new()
	minimap.custom_minimum_size = Vector2(212, 212)
	_map_frame.add_child(minimap)
	var caption := _panel(Vector2(10, 4), _map_frame)
	var row := _horizontal(caption, 8)
	_region = _label("The valley", &"Location")
	_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_region)
	var hint := _label("M  map", &"Caption")
	row.add_child(hint)

func _build_full_map() -> void:
	_full_map = _panel(Vector2(18, 14))
	_root.add_child(_full_map)
	_full_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_map.offset_left = 120
	_full_map.offset_right = -120
	_full_map.offset_top = 70
	_full_map.offset_bottom = -70
	var stack := _vertical(_full_map, 8)
	var heading := _horizontal(stack, 14)
	var title := _label("The valley", &"Ending")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_label("◉ camp (ring = energy left)    ★ beacon    ▪ supplies    ● creatures    M / Esc  close", &"Caption"))
	_big_map = CinderMinimap.new()
	_big_map.full = true
	_big_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_big_map)
	_full_map.hide()

func _build_controls() -> void:
	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 8)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_pin(footer, 0.5, 1.0, 0.0, -22.0)
	_prompt_panel = _panel(Vector2(14, 8), footer)
	_prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var prompt := _horizontal(_prompt_panel, 12)
	_prompt_key_panel = PanelContainer.new()
	_prompt_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap := _style(Color("#f3e3c0"), Color("#8f7350"), Vector2(9, 1), 5)
	cap.border_width_bottom = 3
	_prompt_key_panel.add_theme_stylebox_override("panel", cap)
	_prompt_key = _label("E", &"Key")
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key_panel.add_child(_prompt_key)
	prompt.add_child(_prompt_key_panel)
	_prompt_text = _label("", &"Prompt")
	prompt.add_child(_prompt_text)
	_pack = _meter(&"Health")
	_pack.custom_minimum_size = Vector2(320, 8)
	_pack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.add_child(_pack)
	_tactical = _vertical(footer, 6)
	_module_detail = _label("", &"Body")
	_module_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tactical.add_child(_module_detail)
	var rack := _horizontal(_tactical, 10)
	rack.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in MODULES.size():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(196, 72)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _normal_card)
		rack.add_child(card)
		_module_cards.append(card)
		var card_row := _horizontal(card, 9)
		var key := PanelContainer.new()
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.add_theme_stylebox_override("panel", cap)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var digit := _label(str(index + 1), &"Key")
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_child(digit)
		card_row.add_child(key)
		card_row.add_child(_glyph(index + 1, Vector2(40, 44)))
		var card_text := _vertical(card_row, 1)
		card_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var title := _label(MODULES[index], &"Module")
		card_text.add_child(title)
		_module_names.append(title)
		var subtitle := _label(ROLE_TEXT[index], &"Caption")
		card_text.add_child(subtitle)
		_module_values.append(subtitle)
	_keys_panel = _panel(Vector2(14, 9))
	_pin(_keys_panel, 0.0, 1.0, 24.0, -22.0)
	_keys = _label("", &"Legend")
	_keys_panel.add_child(_keys)

func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 6)
	_pin(_toast_box, 0.5, 0.0, 0.0, 190.0)

func _toast(text: String) -> void:
	var note := _panel(Vector2(14, 6), _toast_box)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := _label(text, &"Accent")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_child(label)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).free()
	note.modulate.a = 0.0
	var fade := note.create_tween()
	fade.tween_property(note, "modulate:a", 1.0, 0.18)
	fade.tween_interval(3.4)
	fade.tween_property(note, "modulate:a", 0.0, 0.5)
	fade.tween_callback(note.queue_free)

func _build_banner() -> void:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := _style(Color(0.015, 0.04, 0.06, 0.78), Color(GOLD, 0.45), Vector2(46, 12), 4)
	fill.border_width_left = 0
	fill.border_width_right = 0
	plate.add_theme_stylebox_override("panel", fill)
	_pin(plate, 0.5, 0.33, 0.0, 0.0)
	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(_banner)
	_banner_title = _label("", &"Banner")
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_detail = _label("", &"Body")
	_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_detail)
	_banner = plate
	_banner.modulate.a = 0.0

func _show_banner(title: String, detail: String) -> void:
	_banner_title.text = title
	_banner_detail.text = detail
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)

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
	panel.custom_minimum_size.x = 460
	var stack := _vertical(panel, 14)
	var ornament := _glyph(HudGlyph.Kind.SUN, Vector2(0, 43))
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

func _show_overlay(mode: String, paused: bool, settings_open: bool, checkpoint_available: bool,
		checkpoint_hint: String, summary: String) -> void:
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
		_detail.text = _pause_text(checkpoint_hint)
	if next == _modal:
		return
	_modal = next
	_overlay.visible = _modal != &""
	_veil.visible = _overlay.visible and _modal != &"victory"
	_overlay.anchor_top = 0.55 if _modal == &"victory" else 0.0
	_overlay.offset_top = 0.0
	var actions: Array[StringName] = []
	match _modal:
		&"victory":
			_title.text = "The last sunrise"
			_detail.text = "Dawn returns to the valley." + ("\n" + summary if not summary.is_empty() else "")
			actions = [&"title"]
		&"defeat", &"defeat_checkpoint":
			_title.text = "The light went out"
			_detail.text = "The shrine has fallen." + ("\n" + summary if not summary.is_empty() else "")
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

func _pause_text(checkpoint_hint: String) -> String:
	var lines := [
		"WASD move  ·  Shift sprint  ·  Ctrl walk  ·  Mouse look",
		"LMB or F  sword combo (3 hits)  ·  RMB  sun spark",
		"E  interact  ·  M  map  ·  Hold R  pack the shrine",
		"Defense:  1 / 2 / 3 choose a tower  ·  click a socket  ·  U upgrade  ·  Space start wave",
	]
	if not checkpoint_hint.is_empty():
		lines.append("")
		lines.append(checkpoint_hint)
	return "\n".join(lines)

func _focus_actions(actions: Array[StringName]) -> void:
	for index in actions.size():
		var button := _buttons[actions[index]]
		var previous := _buttons[actions[posmod(index - 1, actions.size())]]
		var next := _buttons[actions[(index + 1) % actions.size()]]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
	_buttons[actions[0]].grab_focus.call_deferred()

func _control_hints(mode: String, selected: int) -> String:
	match mode:
		"Prepare", "Defend":
			var keys := "1 2 3   choose tower\nLMB   build / sword\nRMB   sun spark\nU   upgrade hovered\nE   repair (8 scrap)\nHold R   pack up"
			if selected >= 0:
				keys += "\nEsc   cancel building"
			return keys
		"Explore", "Transit":
			return "WASD   move\nShift   sprint\nLMB / F   sword\nRMB   sun spark\nE   interact\nM   map    Esc   pause"
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

# ---------------------------------------------------------------- widgets

func _glyph(kind: int, minimum: Vector2) -> HudGlyph:
	var glyph := HudGlyph.new()
	glyph.kind = kind
	glyph.custom_minimum_size = minimum
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph

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
		Control.GROW_DIRECTION_BEGIN if horizontal == 1.0 else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if vertical == 1.0 else (
		Control.GROW_DIRECTION_BOTH if vertical > 0.0 else Control.GROW_DIRECTION_END)

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
	var bold := SystemFont.new()
	bold.font_names = body.font_names
	bold.font_weight = 700
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Cinzel", "Cormorant Garamond", "Liberation Serif", "DejaVu Serif"])
	serif.font_weight = 600
	theme.default_font = body
	for entry in [
		[&"Caption", 14, MUTED, null], [&"Module", 18, CREAM, bold], [&"Body", 17, CREAM, null],
		[&"Value", 16, CREAM, bold], [&"Accent", 16, GOLD, bold], [&"Title", 22, CREAM, serif],
		[&"Location", 19, CREAM, serif], [&"Ending", 47, CREAM, serif], [&"Objective", 21, CREAM, bold],
		[&"Wave", 21, CREAM, serif], [&"Prompt", 20, CREAM, bold], [&"Key", 19, Color("#1b2630"), bold],
		[&"Legend", 15, CREAM, null], [&"Banner", 54, GOLD, serif],
	]:
		var variation: StringName = entry[0]
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size("font_size", variation, entry[1])
		theme.set_color("font_color", variation, entry[2])
		if entry[3] != null:
			theme.set_font("font", variation, entry[3])
		theme.set_color("font_outline_color", variation, Color(0.01, 0.03, 0.05, 0.9))
		theme.set_constant("outline_size", variation, 6 if variation == &"Banner" else 0)
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

func _style(fill: Color, border: Color, margin: Vector2, radius: int = 6) -> StyleBoxFlat:
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
	enum Kind { SUN, BOLT, FIELD, MORTAR, SCRAP }

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
			Kind.SCRAP:
				var gear := PackedVector2Array()
				for index in 16:
					gear.append(Vector2.from_angle(index * TAU / 16.0) * (13.0 if index % 2 == 0 else 9.5))
				draw_colored_polygon(gear, BRASS)
				draw_circle(Vector2.ZERO, 4.0, BRONZE.darkened(0.4))
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
