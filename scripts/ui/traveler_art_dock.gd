extends Control
## The seven bronze settings fill as the traveler recovers the valley's arts.
const GOLD := Color("#f8c773")
const CREAM := Color("#f3e7d1")
const TEAL := Color("#83c5be")
const SLOT := 36.
const GAP := 4.
const COUNT := 7

var slots: Array = []
var caption := ""
var readiness := ""
var _remaining := 0.0
var _feedback := ""
var _feedback_left := 0.0
var _selected_id := &""
var _feedback_label := Label.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(COUNT * (SLOT + GAP) - GAP, SLOT + 42)
	accessibility_name = "Traveler arts"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color("#ffb29d"))
	_feedback_label.add_theme_color_override("font_outline_color", Color("#102029"))
	_feedback_label.add_theme_constant_override("outline_size", 4)
	_feedback_label.add_theme_constant_override("line_spacing", 0)
	add_child(_feedback_label)
	_feedback_label.anchor_right = 1.0
	_feedback_label.offset_bottom = 36.0
	_feedback_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feedback_label.hide()

func update_slots(rows: Array) -> void:
	slots = rows
	var selected: Dictionary = {}
	var unlocked := 0
	for row: Dictionary in rows:
		if row.get("owned", false):
			unlocked += 1
		if row.get("selected", false):
			selected = row
	var current := StringName(selected.get("id", ""))
	var cooldown := float(selected.get("cooldown", 0.0))
	if current != _selected_id or cooldown > _remaining or (cooldown <= 0.0 and _remaining > 0.0):
		_feedback_left = 0.0
		_feedback_label.hide()
		_selected_id = current
	caption = str(selected.get("name", "Shrine arts"))
	if unlocked > 1:
		caption += "    Q  Cycle"
	_remaining = cooldown
	if selected.is_empty():
		readiness = ""
	elif cooldown > 0.0:
		readiness = "Recharges in %d s" % ceili(cooldown)
	else:
		readiness = "Ready   ·   G to cast"
	accessibility_description = caption + "  " + (_feedback if _feedback_left > 0.0 else readiness)
	queue_redraw()

func show_feedback(reason: String) -> void:
	_feedback = reason.strip_edges()
	_feedback_left = clampf(1.0 + _feedback.length() / 22.0, 2.0, 4.0) if not _feedback.is_empty() else 0.0
	_feedback_label.text = _feedback
	_feedback_label.visible = _feedback_left > 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if _feedback_left > 0.0 and is_visible_in_tree():
		_feedback_left = maxf(0.0, _feedback_left - delta)
		if _feedback_left <= 0.0:
			_feedback_label.hide()
			queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var row_y := 38.0
	if not _feedback_label.visible:
		var title_y := 14.0 if not readiness.is_empty() else 31.0
		draw_string_outline(font, Vector2(0, title_y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("#102029"))
		draw_string(font, Vector2(0, title_y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
		if not readiness.is_empty():
			var color := GOLD if _remaining > 0.0 else TEAL
			draw_string_outline(font, Vector2(0, 32), readiness, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, 4, Color("#102029"))
			draw_string(font, Vector2(0, 32), readiness, HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, color)
	for i in mini(COUNT, slots.size()):
		var row: Dictionary = slots[i]
		var owned := bool(row.get("owned", false))
		var selected := bool(row.get("selected", false))
		var rect := Rect2(Vector2(i * (SLOT + GAP), row_y), Vector2.ONE * SLOT)
		var center := rect.get_center()
		draw_rect(rect, Color("#102731ed"))
		draw_rect(rect, GOLD if selected else (TEAL if owned else Color("#617075")), false, 2. if selected else 1.)
		var icon := row.get("icon") as Texture2D
		if icon:
			draw_texture_rect(icon, rect.grow(-2.), false, Color.WHITE if owned else Color(.43, .50, .52, .55))
		if not owned:
			var lock := rect.end - Vector2(7, 6)
			draw_rect(Rect2(lock - Vector2(4, 1), Vector2(8, 6)), CREAM)
			draw_arc(lock - Vector2(0, 1), 2.8, PI, TAU, 8, CREAM, 1.5, true)
		else:
			var cooldown := float(row.get("cooldown", 0.))
			if cooldown > .01:
				var fraction := clampf(cooldown / maxf(.01, float(row.get("cooldown_max", 1.))), 0., 1.)
				var shade := Color(.02,.06,.08,.76)
				if fraction >= .999:
					draw_circle(center, SLOT * .47, shade)
				else:
					var wedge := PackedVector2Array([center])
					for step in 25:
						wedge.append(center + Vector2.from_angle(-PI / 2. + TAU * fraction * step / 24.) * (SLOT * .47))
					draw_colored_polygon(wedge, shade)
				var seconds := str(ceili(cooldown))
				draw_string_outline(font, rect.position + Vector2(0,25), seconds, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 19, 5, Color("#101a21"))
				draw_string(font, rect.position + Vector2(0,25), seconds, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 19, CREAM)
			elif selected:
				draw_line(rect.position + Vector2(4,SLOT-3), rect.end - Vector2(4,3), GOLD, 2.)
