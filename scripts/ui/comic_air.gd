extends Control

var page := 0
var clock := 0.0
var still := false
var aspect := 16.0 / 9.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

func _draw() -> void:
	if still:
		return
	var extent := Vector2(minf(size.x, size.y * aspect), minf(size.y, size.x / aspect))
	var origin := (size - extent) * 0.5
	var wind := 1.0 if page % 2 == 0 else -1.0
	for i in 7:
		var seed_angle := i * 2.399 + page * 1.31
		var speed := 0.033 + 0.004 * (i % 4)
		var depth := 0.66 + 0.16 * (i % 3)
		var y := fposmod(i * 0.173 + page * 0.11 + clock * speed * depth, 1.0)
		var x := fposmod(i * 0.287 + page * 0.169 + wind * y * 0.23 + sin(clock * 0.67 + seed_angle) * 0.014, 1.0)
		var envelope := smoothstep(0.01, 0.14, y) * (1.0 - smoothstep(0.84, 0.99, y))
		var p := origin + Vector2(x, y) * extent
		if i % 3 != 0:
			var sparkle := 0.35 + 0.25 * sin(clock * 0.97 + seed_angle)
			draw_circle(p, 1.0 + depth, Color(1.0, 0.83, 0.53, sparkle * envelope), true, -1, true)
			continue
		var length := clampf(extent.x / 142.0, 3.0, 7.0) * depth
		var angle := sin(clock * 0.9 + seed_angle) * 0.94 - 0.6
		var axis := Vector2.from_angle(angle) * length
		var cross_axis := axis.orthogonal() * (0.19 + absf(sin(clock + seed_angle)) * 0.20)
		var tint := Color(0.87, 0.48 + 0.03 * i, 0.18, envelope * 0.88)
		draw_colored_polygon(PackedVector2Array([p - axis, p + cross_axis, p + axis, p - cross_axis]), tint)
