extends CanvasLayer

signal exit_requested

var _card: PanelContainer
var _headline: Label
var _text: Label
var _animation: Tween

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var frame := MarginContainer.new()
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	frame.add_theme_constant_override("margin_top", 132)
	frame.add_theme_constant_override("margin_left", 32)
	frame.add_theme_constant_override("margin_right", 32)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	frame.add_child(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	center.add_child(_card)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#10222e")
	surface.border_color = Color("#98764e")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(7)
	surface.content_margin_left = 20
	surface.content_margin_right = 20
	surface.content_margin_top = 10
	surface.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", surface)
	var words := VBoxContainer.new()
	_card.add_child(words)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_headline = _label(words, Color("#efbe76"), 15)
	_text = _label(words, Color("#f6e7cb"), 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = minf(550.0, get_viewport().get_visible_rect().size.x - 100.0)
	_card.hide()

func _label(parent: Control, color: Color, size: int) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func narrate(headline: String, text: String, seconds := 5.0) -> void:
	if _animation:
		_animation.kill()
	_headline.text = headline
	_text.text = text
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * .97
	_card.show()
	_animation = create_tween().set_ignore_time_scale()
	_animation.tween_property(_card, "modulate:a", 1.0, .30)
	_animation.parallel().tween_property(_card, "scale", Vector2.ONE, .35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation.tween_interval(maxf(.1, seconds - .8))
	_animation.tween_property(_card, "modulate:a", 0.0, .45)
	_animation.tween_callback(_card.hide)

func clear() -> void:
	if _animation:
		_animation.kill()
	_card.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
