class_name CinderShotEffect
extends MeshInstance3D

signal landed
var start: Vector3
var finish: Vector3
var arc: float
var duration: float
var elapsed := 0.0

func launch(from: Vector3, to: Vector3, lob: bool, tint: Color) -> void:
	start = from
	finish = to
	arc = 3.1 if lob else 0.0
	duration = 0.78 if lob else clampf(from.distance_to(to) * 0.018, 0.09, 0.22)
	var shape := SphereMesh.new()
	shape.radius = 0.16 if lob else 0.067
	shape.height = shape.radius * 2.0
	shape.radial_segments = 8
	shape.rings = 3
	mesh = shape
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	global_position = start
	if not lob and from.distance_squared_to(to) > 0.0001:
		look_at(to, Vector3.FORWARD if absf(from.direction_to(to).y) > 0.99 else Vector3.UP)
		scale.z = 4.0

func _physics_process(delta: float) -> void:
	elapsed += delta
	var t := minf(elapsed / duration, 1.0)
	global_position = start.lerp(finish, t) + Vector3.UP * (4.0 * arc * t * (1.0 - t))
	if t >= 1.0:
		landed.emit()
		queue_free()
