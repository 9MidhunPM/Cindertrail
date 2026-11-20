extends Control

const INK := Color("#091c2a")
const BRASS := Color("#d7ae75")

var comic := false
var _veil: GradientTexture2D

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.48, 0.70, 1.0])
	gradient.colors = PackedColorArray([
		Color(INK, 0.02), Color(INK, 0.07), Color(INK, 0.66),
		Color(INK, 0.98), Color(INK, 0.98)])
	_veil = GradientTexture2D.new()
	_veil.gradient = gradient
	_veil.width = 512
	_veil.height = 4
	_veil.fill_to = Vector2.RIGHT

func _draw() -> void:
	if comic:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1c27"))
	else:
		if size.x < 1060.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.75))
		if _veil:
			draw_texture_rect(_veil, Rect2(Vector2.ZERO, size), false)
	# A pair of short brass marks registers the page like a bound atlas.
	var inset := 22.0
	for point in [Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(inset, size.y - inset), size - Vector2(inset, inset)]:
		var inward := Vector2(signf(size.x * 0.5 - point.x), signf(size.y * 0.5 - point.y))
		draw_line(point, point + Vector2(inward.x * 40, 0), Color(BRASS, 0.56), 1.0, true)
		draw_line(point, point + Vector2(0, inward.y * 19), Color(BRASS, 0.56), 1.0, true)
