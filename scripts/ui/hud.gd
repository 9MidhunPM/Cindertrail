class_name CinderHUD
extends CanvasLayer
## In-game interface. Observes the run through render(state); never owns gameplay truth.
## Exploration and defense share the same core readouts and contextual action area.

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
const COMPASS := preload("res://scripts/ui/journey_compass.gd")
const ART_DOCK := preload("res://scripts/ui/traveler_art_dock.gd")

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
var _dash_readout: Label
var _compass: COMPASS
var _art_dock: ART_DOCK
var _gameplay_hidden := false
var _last_state: Dictionary = {}
var _navigation: VBoxContainer
var _objective_panel: PanelContainer
var _objective: Label
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
var _upgrade_cap_label: Label
var _prompt_panel: PanelContainer
var _prompt_key: Label
var _prompt_key_panel: PanelContainer
var _prompt_text: Label
var _pack: ProgressBar
var _toast_box: VBoxContainer
var _last_status := ""
var _reward_panel: PanelContainer
var _reward_icon: TextureRect
var _reward_name: Label
var _reward_effect: Label
var _reward_detail: Label
var _guide_panel: PanelContainer
var _guide_text: Label
var _guide_seconds := 0.0
var _reward_seconds := 0.0
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
	_build_full_map()
	_build_overlay()
	_root.resized.connect(_size_panels)
	_size_panels()
	render({})

## Attach world readers once the run exists: minimap, full map and world labels.
func bind(world: Node) -> void:
	game = world
	minimap.bind(world)
	_big_map.bind(world)
	overlay.bind(world)
	_compass.camera = world.camera
	_compass.traveler = world.player

func render(state: Dictionary) -> void:
	if not is_instance_valid(_root):
		return
	_last_state = state
	var mode := String(state.get("mode", "Explore"))
	var paused := bool(state.get("paused", false))
	var settings_open := bool(state.get("settings_open", false))
	var ended := mode == "Win" or mode == "Lose"
	var map_open := bool(state.get("map_open", false))
	var calm := not ended and not paused and not map_open and not _gameplay_hidden
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
	var recovery := float(state.get("dash_cooldown", 0.))
	_dash_readout.visible = not anchored and recovery > .0
	_dash_readout.text = "Dash ready in %.1f s" % recovery
	var slots: Array = state.get("ability_slots", [])
	_art_dock.visible = calm and not slots.is_empty()
	_art_dock.update_slots(slots)
	if health < _last_health - 0.01:
		_hurt = minf(1.0, _hurt + (_last_health - health) * 0.09 + 0.25)
	_last_health = health

	var objective := String(state.get("objective", "")).strip_edges()
	var destination: Vector3 = state.get("objective_point", Vector3.INF)
	var distance := float(state.get("compass_distance", state.get("objective_distance", -1.)))
	_compass.waypoint = state.get("compass_point", destination)
	_objective_panel.visible = calm and not anchored and not objective.is_empty() and mode != "Deploy"
	_compass.visible = _objective_panel.visible
	_objective.text = objective
	if destination != Vector3.INF and distance >= 1.:
		_objective.text += "   ·   %d m" % roundi(distance)
	minimap.objective = destination
	_big_map.objective = destination

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
			_wave_detail.text = "%d / %d hostiles" % [left, total]
			var lanes := PackedStringArray(state.get("wave_lanes", PackedStringArray()))
			if not lanes.is_empty():
				_wave_detail.text += "   ·   " + " / ".join(lanes)
			_wave_bar.value = 100.0 * (1.0 - float(left) / total)
		elif next >= 0.0 and bool(state.get("engaged", false)):
			_wave_title.text = "NEXT WAVE IN %d" % ceili(next)
			_wave_detail.text = forecast
			_wave_bar.value = 100.0 * (1.0 - next / maxf(float(state.get("breather", 5.0)), 0.1))
		else:
			_wave_title.text = "Prepare  ·  T to start"
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

	var building := calm and anchored and mode != "Pack"
	if building != _tactical.visible:
		_tactical.visible = building
		_size_panels()
	var prices: Array = state.get("prices", [])
	var owned: Array = state.get("owned", [])
	var summaries: Array = state.get("summaries", [])
	var upgrade_cap := int(state.get("upgrade_cap", CinderBattle.BASE_UPGRADE_CAP))
	_upgrade_cap_label.text = "U   Upgrade at a tower   ·   Rank limit %d" % upgrade_cap
	_upgrade_cap_label.visible = int(state.get("socket", -1)) >= 0 and selected < 0
	for index in MODULES.size():
		var price := int(prices[index]) if index < prices.size() else 0
		var level := int(owned[index]) if index < owned.size() else 0
		var affordable := level > 0 or scrap >= price
		var style := _selected_card if selected == index else (_normal_card if affordable else _poor_card)
		if _module_cards[index].get_theme_stylebox("panel") != style:
			_module_cards[index].add_theme_stylebox_override("panel", style)
		_module_cards[index].modulate = Color.WHITE if affordable or selected == index else Color(.90, .93, .94, .96)
		if level > 0:
			_module_values[index].text = "Lv %d/%d  ·  free" % [level, upgrade_cap]
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
		hint = "LMB  Build on a socket   ·   Esc to cancel"
	_set_prompt(hint)
	_prompt_panel.visible = calm and not hint.is_empty()
	_pack.visible = calm and mode == "Pack"
	_toast_box.visible = calm and _reward_seconds <= 0.
	_reward_panel.visible = calm and _reward_seconds > 0.
	_guide_panel.visible = calm and _reward_seconds <= 0. and not _guide_text.text.is_empty()
	_pack.value = clampf(float(state.get("pack_progress", 0.0)), 0.0, 1.0) * 100.0

	var status := String(state.get("status", "")).strip_edges()
	if status != _last_status:
		_last_status = status
		if not status.is_empty() and calm and _reward_seconds <= 0. and not (anchored and status.begins_with("Wave ")):
			_toast(status)
	_full_map.visible = map_open
	overlay.visible = calm
	overlay.socket_text = String(state.get("socket_text", ""))
	overlay.socket_ok = bool(state.get("socket_ok", true))
	overlay.socket_point = state.get("socket_point", Vector3.INF)
	_show_overlay(mode, paused, settings_open, bool(state.get("checkpoint_available", false)),
		String(state.get("checkpoint_hint", "")), String(state.get("summary", "")))

## F10 hides the play readouts while map, settings and pause remain accessible.
func toggle_gameplay_hud() -> void:
	_gameplay_hidden = not _gameplay_hidden
	render(_last_state)

func announce_ability(title: String, icon: Texture2D, cap: int, first_achievement: bool, description := "") -> void:
	_reward_icon.texture = icon
	_reward_name.text = title
	if description.is_empty():
		for slot: Dictionary in _last_state.get("ability_slots", []):
			if slot.get("name") == title:
				description = str(slot.get("description", ""))
				break
	_reward_effect.text = description
	_reward_effect.visible = not description.is_empty()
	_reward_detail.text = "Defense rank limit %d" % cap
	if first_achievement:
		_reward_detail.text += "   ·   Achievement earned"
	_reward_seconds = 6.0
	_guide_panel.hide()
	for child in _toast_box.get_children():
		child.queue_free()
	_toast_box.hide()
	_reward_panel.modulate.a = 1.
	_reward_panel.visible = overlay.visible

## A persistent line stays until the guide replaces or clears it. A modal suspends reading time.
func guide_line(text: String, persistent := false) -> void:
	_guide_text.text = text.strip_edges()
	_guide_seconds = -1.0 if persistent else clampf(2.5 + text.length() / 15.0, 4.5, 10.0)
	_guide_panel.visible = overlay.visible and _reward_seconds <= 0.0 and not _guide_text.text.is_empty()

func art_feedback(reason: String) -> void:
	_art_dock.show_feedback(reason)

func modal_open() -> bool:
	return visible and _modal != &""

func _process(delta: float) -> void:
	if _reward_seconds > 0. and _reward_panel.is_visible_in_tree():
		_reward_seconds = maxf(0., _reward_seconds - delta)
		_reward_panel.modulate.a = clampf(_reward_seconds / .22, 0., 1.)
		if _reward_seconds <= 0.:
			_reward_panel.hide()
	if _guide_seconds > 0.0 and _guide_panel.is_visible_in_tree():
		_guide_seconds = maxf(0.0, _guide_seconds - delta)
		if _guide_seconds == 0.0:
			_guide_text.text = ""
			_guide_panel.hide()
	_hurt = maxf(0.0, _hurt - delta * 1.6)
	_vignette.material.set_shader_parameter("strength", _hurt)
	_vignette.visible = _hurt > 0.01 and overlay.visible

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
	_vitals_panel = _panel(Vector2(12, 8))
	_pin(_vitals_panel, 0.0, 0.0, 24.0, 22.0)
	_vitals_panel.custom_minimum_size.x = 205
	var stack := _vertical(_vitals_panel, 4)
	var seal := _horizontal(stack, 10)
	seal.add_child(_glyph(HudGlyph.Kind.SUN, Vector2(26, 26)))
	var heading := _label("Sun core", &"Title")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.add_child(heading)
	var purse := _horizontal(seal, 5)
	purse.add_child(_glyph(HudGlyph.Kind.SCRAP, Vector2(18, 18)))
	_scrap = _label("0", &"Accent")
	purse.add_child(_scrap)
	purse.add_child(_label("scrap", &"Caption"))
	_health_value = _label("100 / 100", &"Value")
	_health = _stat(stack, "Integrity", _health_value, &"Health")
	_health.custom_minimum_size.y = 9.0
	_restoration_value = _label("0%", &"Value")
	_restoration = _stat(stack, "Restoration", _restoration_value, &"Restoration")
	_restoration.custom_minimum_size.y = 9.0
	_dash_readout = _label("", &"Caption")
	stack.add_child(_dash_readout)

func _build_objective() -> void:
	_navigation = VBoxContainer.new()
	_navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(_navigation, .5, 0., 0., 20.)
	_objective_panel = _panel(Vector2(12, 4), _navigation)
	var objective_stack := _vertical(_objective_panel, 2)
	_compass = COMPASS.new()
	objective_stack.add_child(_compass)
	_objective = _label("", &"Objective")
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_stack.add_child(_objective)
	_wave_panel = _panel(Vector2(14, 6), _navigation)
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
	_reserve_bar = _meter(&"Reserve")
	_reserve_bar.custom_minimum_size.y = 5.0
	wave.add_child(_reserve_bar)

func _build_map() -> void:
	_map_frame = VBoxContainer.new()
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_frame.add_theme_constant_override("separation", 6)
	_pin(_map_frame, 1.0, 0.0, -24.0, 20.0)
	minimap = CinderMinimap.new()
	minimap.custom_minimum_size = Vector2(136, 136)
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
	_guide_panel = _panel(Vector2(14, 7), footer)
	_guide_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_guide_panel.accessibility_name = "Mote"
	var guide_style := _style(Color("#10232bee"), Color("#5f8789"), Vector2(14, 7), 3)
	guide_style.border_width_left = 3
	_guide_panel.add_theme_stylebox_override("panel", guide_style)
	var guide_words := _vertical(_guide_panel, 1)
	var speaker := _label("Mote", &"Accent")
	speaker.add_theme_color_override("font_color", TEAL)
	guide_words.add_child(speaker)
	_guide_text = _label("", &"Body")
	_guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_words.add_child(_guide_text)
	_guide_panel.hide()
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
	_upgrade_cap_label = _label("", &"Caption")
	_upgrade_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tactical.add_child(_upgrade_cap_label)
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
	_art_dock = ART_DOCK.new()
	_pin(_art_dock, 0., 1., 24., -22.)

func _size_panels() -> void:
	var width := _root.size.x
	var narrow := width < 1100.
	minimap.custom_minimum_size = Vector2.ONE * (100. if narrow else 136.)
	var available := clampf(width - (435. if narrow else 590.), 250., 450.)
	_navigation.custom_minimum_size.x = available
	_objective_panel.custom_minimum_size.x = available
	_wave_panel.custom_minimum_size.x = available
	_vitals_panel.custom_minimum_size.x = 171. if narrow else 205.
	_guide_text.custom_minimum_size.x = clampf(width * .40, 220., 470.)
	_reward_effect.custom_minimum_size.x = clampf(width * .33, 210., 385.)
	for card in _module_cards:
		card.custom_minimum_size = Vector2(133. if narrow else 161., 53.)
	# On narrow targets the art settings sit above the tower rack.
	_art_dock.offset_bottom = -126. if width < 1480. and _tactical.visible else -22.
	_art_dock.offset_top = _art_dock.offset_bottom - _art_dock.custom_minimum_size.y

func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 6)
	_pin(_toast_box, 0.5, 0.0, 0.0, 142.0)
	_reward_panel = _panel(Vector2(16, 9))
	_pin(_reward_panel, .5, 0., 0., 142.)
	_reward_panel.add_theme_stylebox_override("panel", _style(Color("#172a2df5"), GOLD.darkened(.28), Vector2(16, 9), 3))
	var row := _horizontal(_reward_panel, 12)
	_reward_icon = TextureRect.new()
	_reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reward_icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(_reward_icon)
	var words := _vertical(row, 1)
	words.add_child(_label("Art recovered", &"Accent"))
	_reward_name = _label("", &"Title")
	words.add_child(_reward_name)
	_reward_effect = _label("", &"Body")
	_reward_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_reward_effect)
	words.add_child(_label("Q  Cycle arts     ·     G  Cast equipped art", &"Accent"))
	_reward_detail = _label("", &"Caption")
	words.add_child(_reward_detail)
	_reward_panel.hide()

func _toast(text: String) -> void:
	var note := _panel(Vector2(14, 6), _toast_box)
	note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := _label(text, &"Accent")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(460., _root.size.x * .42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_child(label)
	while _toast_box.get_child_count() > 1:
		_toast_box.get_child(0).free()
	note.modulate.a = 0.0
	var fade := note.create_tween()
	fade.tween_property(note, "modulate:a", 1.0, 0.18)
	fade.tween_interval(3.4)
	fade.tween_property(note, "modulate:a", 0.0, 0.5)
	fade.tween_callback(note.queue_free)

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
	_add_action(actions, &"achievements", "Achievements")
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
			actions = [&"resume", &"achievements", &"settings", &"title"]
	_detail.visible = not _detail.text.is_empty()
	for action in _buttons:
		_buttons[action].visible = actions.has(action)
	if not actions.is_empty():
		_focus_actions(actions)

func _pause_text(checkpoint_hint: String) -> String:
	var lines := [
		"WASD move  ·  Shift dash  ·  Space jump  ·  Mouse look",
		"LMB or F  tap for cuts, hold and release to spin  ·  RMB  sun spark",
		"G  cast equipped ability  ·  Q  cycle unlocked abilities",
		"E  interact  ·  M  map  ·  Hold R  pack the shrine",
		"Defense:  1 / 2 / 3 choose a tower  ·  click a socket  ·  U upgrade  ·  T start wave",
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
		[&"Location", 19, CREAM, serif], [&"Ending", 47, CREAM, serif], [&"Objective", 17, CREAM, bold],
		[&"Wave", 21, CREAM, serif], [&"Prompt", 20, CREAM, bold], [&"Key", 19, Color("#1b2630"), bold],
	]:
		var variation: StringName = entry[0]
		theme.set_type_variation(variation, &"Label")
		theme.set_font_size("font_size", variation, entry[1])
		theme.set_color("font_color", variation, entry[2])
		if entry[3] != null:
			theme.set_font("font", variation, entry[3])
	for entry in [[&"Health", Color("#e39a77")], [&"Restoration", GOLD], [&"Reserve", TEAL]]:
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
