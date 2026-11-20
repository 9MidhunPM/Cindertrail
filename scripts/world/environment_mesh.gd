extends RefCounted
## Faceted, vertex-painted masonry and vegetation batches.

const PIGMENT := preload("res://art/outer_valley/valley_pigment.gdshader")
const ROUTE_PAINT := preload("res://art/textures/stylized/route_paint.png")
const BRUSH := preload("res://art/textures/stylized/valley_brush.png")

var _tool := SurfaceTool.new()
var _vertex_count := 0

func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

static func pigment(family := 0, wind := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PIGMENT
	material.set_shader_parameter("route_paint", ROUTE_PAINT)
	material.set_shader_parameter("brush_detail", BRUSH)
	material.set_shader_parameter("family", family)
	material.set_shader_parameter("moves_in_wind", wind)
	return material

func face(a: Vector3, b: Vector3, c: Vector3, tint: Color, facing: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.is_zero_approx():
		return
	var winding := [a, b, c] if normal.dot(facing) >= 0.0 else [a, c, b]
	if normal.dot(facing) < 0.0:
		normal = -normal
	for vertex: Vector3 in winding:
		_tool.set_color(tint.srgb_to_linear())
		_tool.set_normal(normal)
		_tool.add_vertex(vertex)
	_vertex_count += 3

func panel(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color, facing: Vector3) -> void:
	face(a, b, c, tint, facing)
	face(a, c, d, tint, facing)

func block(center: Vector3, half: Vector3, tint: Color, yaw := 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var x := basis.x * half.x
	var y := basis.y * half.y
	var z := basis.z * half.z
	for axes: Array in [[x, y, z], [-x, z, y], [y, z, x], [-y, x, z], [z, x, y], [-z, y, x]]:
		var out: Vector3 = axes[0]
		var u: Vector3 = axes[1]
		var v: Vector3 = axes[2]
		var p := center + out
		var tone := tint.darkened(.08 + .09 * maxf(0.0, -out.normalized().y))
		if out.y > .001:
			tone = tint.lightened(.065)
		panel(p - u - v, p + u - v, p + u + v, p - u + v, tone, out)

func tapered(a: Vector3, b: Vector3, start_radius: float, end_radius: float, sides: int, tint: Color) -> void:
	var axis := a.direction_to(b)
	var right := axis.cross(Vector3.FORWARD).normalized() if absf(axis.z) < .91 else axis.cross(Vector3.UP).normalized()
	var front := right.cross(axis).normalized()
	for i in sides:
		var first := TAU * i / sides
		var last := TAU * (i + 1) / sides
		var p := right * cos(first) + front * sin(first)
		var q := right * cos(last) + front * sin(last)
		panel(a + p * start_radius, a + q * start_radius, b + q * end_radius, b + p * end_radius,
			tint.lightened((float(i % 3) - 1.0) * .065), p + q)

func facets(center: Vector3, half: Vector3, sides: int, tint: Color, phase := .18) -> void:
	var crest := center + Vector3.UP * half.y
	var root := center + Vector3.DOWN * half.y * .78
	for i in sides:
		var a := TAU * (i + phase) / sides
		var b := TAU * (i + phase + 1.0) / sides
		var p := center + Vector3(cos(a) * half.x, sin(a * 2.0) * half.y * .21, sin(a) * half.z)
		var q := center + Vector3(cos(b) * half.x, sin(b * 2.0) * half.y * .21, sin(b) * half.z)
		face(p, q, crest, tint.lightened(.065 + .08 * sin(a)), Vector3.UP)
		face(q, p, root, tint.darkened(.13 + .10 * cos(a)), Vector3.DOWN)

func mount(parent: Node3D, label: String, material: Material, shadows := true) -> MeshInstance3D:
	if _vertex_count == 0:
		return null
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = _tool.commit()
	view.material_override = material
	if not shadows:
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view
