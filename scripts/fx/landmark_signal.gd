extends RefCounted

const TRACE := preload("res://art/materials/stylized/landmark_trace.gdshader")

static func ring(host: Node3D, point: Vector3, radius: float, tint: Color,
		duration: float, expanding: bool = false) -> MeshInstance3D:
	var band := TorusMesh.new()
	band.inner_radius = radius - .065
	band.outer_radius = radius + .065
	band.rings = 48
	band.ring_segments = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = tint
	var visual := MeshInstance3D.new()
	visual.name = "LandmarkRing"
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.mesh = band
	visual.material_override = material
	host.add_child(visual)
	visual.global_position = point
	var tween := visual.create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if expanding:
		visual.scale = Vector3(.14, 1, .14)
		tween.parallel().tween_property(visual, "scale", Vector3.ONE, duration).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, duration * .35).set_delay(duration * .65)
	tween.tween_callback(visual.queue_free)
	return visual

static func trace_lane(host: Node3D, lane: PackedVector3Array, tint: Color,
		half_width: float, duration: float, toward_shrine: bool) -> void:
	if lane.size() < 2:
		return
	var strip := ImmediateMesh.new()
	var material := ShaderMaterial.new()
	material.shader = TRACE
	material.set_shader_parameter(&"tint", tint)
	var distance := 0.0
	for i in range(1, lane.size()):
		distance += lane[i - 1].distance_to(lane[i])
	if is_zero_approx(distance):
		return
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var traveled := 0.0
	for i in range(1, lane.size()):
		var a := host.to_local(lane[i - 1] + Vector3.UP * .19)
		var b := host.to_local(lane[i] + Vector3.UP * .19)
		var sideways := Vector3.UP.cross(b - a).normalized() * half_width
		var start := traveled / distance
		traveled += a.distance_to(b)
		var end := traveled / distance
		_corner(strip, a - sideways, Vector2(0, start))
		_corner(strip, b - sideways, Vector2(0, end))
		_corner(strip, b + sideways, Vector2(1, end))
		_corner(strip, a - sideways, Vector2(0, start))
		_corner(strip, b + sideways, Vector2(1, end))
		_corner(strip, a + sideways, Vector2(1, start))
	strip.surface_end()
	var visual := MeshInstance3D.new()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.mesh = strip
	visual.material_override = material
	host.add_child(visual)
	var tween := visual.create_tween()
	var from := -.2 if toward_shrine else 1.2
	var to := 1.2 if toward_shrine else -.2
	tween.tween_method(func(phase: float) -> void: material.set_shader_parameter(&"phase", phase),
		from, to, duration)
	tween.tween_callback(visual.queue_free)

static func _corner(mesh: ImmediateMesh, point: Vector3, uv: Vector2) -> void:
	mesh.surface_set_uv(uv)
	mesh.surface_add_vertex(point)
