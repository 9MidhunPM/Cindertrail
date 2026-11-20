extends Control

const BRASS := Color("#d7ae75")

var phase := 0.0
var still := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if still or not is_visible_in_tree():
		return
	phase = fmod(phase + delta, 1200.0)
	queue_redraw()

func _draw() -> void:
	draw_solar_seal(size * 0.5, minf(size.y * 0.34, 42), phase)

func draw_solar_seal(center: Vector2, radius: float, clock: float) -> void:
	var pale := Color("#efd2a2")
	draw_arc(center, radius, PI * 0.09, PI * 0.91, 50, Color(BRASS, 0.8), 1.4, true)
	draw_arc(center, radius, PI * 1.08, PI * 1.92, 50, Color(BRASS, 0.8), 1.4, true)
	for i in 16:
		var ray := Vector2.from_angle(TAU * i / 16.0)
		var length := 7.0 if i % 4 == 0 else 3.0
		draw_line(center + ray * (radius + 4.0), center + ray * (radius + 4.0 + length), BRASS, 1.0, true)
	for tilt in [-0.88, 0.28, 1.48]:
		var orbit := PackedVector2Array()
		for n in 65:
			var a := TAU * n / 64.0
			orbit.append(center + Vector2(cos(a) * radius * 0.78, sin(a) * radius * 0.32).rotated(tilt + sin(clock * 0.19) * 0.10))
		draw_polyline(orbit, Color(pale, 0.85), 1.4, true)
	draw_circle(center, radius * 0.19, Color("#ffd182"), true, -1, true)
	for side in [-1.0, 1.0]:
		var end := center + Vector2(side * (radius + 18), 0)
		draw_line(end, end + Vector2(side * radius, 0), Color(BRASS, 0.72), 1.0, true)
		draw_circle(end + Vector2(side * radius, 0), 1.8, BRASS, true, -1, true)
