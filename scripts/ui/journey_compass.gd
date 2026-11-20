extends Control
## A bearing measured from the actual gameplay camera, including its orbit and blend.
const INK := Color("#102531")
const GOLD := Color("#ffd37a")
const CREAM := Color("#efe2c7")

var camera: Camera3D
var traveler: Node3D
var waypoint := Vector3.INF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(240, 34)
	accessibility_name = "Trail compass"

static func relative_bearing(forward: Vector3, direction: Vector3) -> float:
	return wrapf(atan2(direction.x, -direction.z) - atan2(forward.x, -forward.z), -PI, PI)

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera):
		return
	var forward := -camera.global_basis.z
	var center := size.x * .5
	var half := center - 12.
	var span := deg_to_rad(72.)
	var labels := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var font := get_theme_default_font()
	draw_line(Vector2(7, 24), Vector2(size.x-7, 24), Color("#546468"), 1)
	for i in 32:
		var absolute := i * TAU / 32.
		var angle := relative_bearing(forward, Vector3(sin(absolute), 0, -cos(absolute)))
		if absf(angle) > span:
			continue
		var x := center + angle / span * half
		var major := i % 4 == 0
		draw_line(Vector2(x, 19 if major else 22), Vector2(x, 26), CREAM if major else Color("#84918b"), 1.3)
		if major:
			draw_string(font, Vector2(x-15, 16), labels[i / 4], HORIZONTAL_ALIGNMENT_CENTER, 30, 13, CREAM)
	draw_colored_polygon(PackedVector2Array([Vector2(center-3, 32), Vector2(center, 28), Vector2(center+3, 32)]), CREAM)
	if waypoint == Vector3.INF or not is_instance_valid(traveler):
		return
	var direction := waypoint - traveler.global_position
	if direction.slide(Vector3.UP).length_squared() < .05:
		return
	var target_angle := relative_bearing(forward, direction)
	var marker := Vector2(center + clampf(target_angle / span, -1., 1.) * half, 23.)
	if absf(target_angle) <= span:
		draw_colored_polygon(PackedVector2Array([marker + Vector2.UP*8, marker + Vector2.RIGHT*5,
			marker + Vector2.DOWN*6, marker + Vector2.LEFT*5]), GOLD)
		draw_circle(marker, 1.8, INK)
	else:
		var side := signf(target_angle)
		draw_colored_polygon(PackedVector2Array([marker + Vector2(6*side,0),
			marker + Vector2(-3*side,-5), marker + Vector2(-3*side,5)]), GOLD)
