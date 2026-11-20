class_name CinderShotEffect
extends Node3D

signal landed

const RING_SHADER := preload("res://scripts/combat/mortar_ring.gdshader")

static var ember_mesh: SphereMesh
static var trail_mesh: CylinderMesh
static var ground_mesh: PlaneMesh
static var inks: Dictionary[Color, StandardMaterial3D] = {}

var start: Vector3
var finish: Vector3
var arc: float
var duration: float
var elapsed := 0.0
var ember: MeshInstance3D
var tail: MeshInstance3D
var ring: MeshInstance3D
var ring_ink: ShaderMaterial
var arrived := false

static func _ink(tint: Color) -> StandardMaterial3D:
	if not inks.has(tint):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = tint
		inks[tint] = mat
	return inks[tint]

func _piece(shape: Mesh, ink: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = shape
	piece.material_override = ink
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	return piece

func launch(from: Vector3, to: Vector3, lob: bool, tint: Color) -> void:
	start = from
	finish = to
	arc = 3.1 if lob else 0.0
	duration = 0.78 if lob else clampf(from.distance_to(to) * 0.018, 0.09, 0.22)
	if not ember_mesh:
		ember_mesh = SphereMesh.new()
		ember_mesh.radius = 1.0
		ember_mesh.height = 2.0
		ember_mesh.radial_segments = 8
		ember_mesh.rings = 4
		trail_mesh = CylinderMesh.new()
		trail_mesh.top_radius = 1.0
		trail_mesh.bottom_radius = 0.02
		trail_mesh.height = 1.0
		trail_mesh.radial_segments = 6
		trail_mesh.rings = 0
	ember = _piece(ember_mesh, _ink(tint.lerp(Color.WHITE, 0.66)))
	ember.scale = Vector3.ONE * (0.17 if lob else 0.078)
	ember.global_position = start
	tail = _piece(trail_mesh, _ink(tint))
	tail.visible = false

func set_blast_radius(radius: float) -> void:
	if not ground_mesh:
		ground_mesh = PlaneMesh.new()
		ground_mesh.size = Vector2(2, 2)
	ring_ink = ShaderMaterial.new()
	ring_ink.shader = RING_SHADER
	ring = _piece(ground_mesh, ring_ink)
	ring.scale = Vector3(radius, 1.0, radius)
	var ray := PhysicsRayQueryParameters3D.create(finish + Vector3.UP * 0.3, finish + Vector3.DOWN * 4.0, 1)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(ray)
	ring.global_position = (floor_hit.position as Vector3 if not floor_hit.is_empty() else finish) + Vector3.UP * 0.055

func _point(t: float) -> Vector3:
	return start.lerp(finish, t) + Vector3.UP * (4.0 * arc * t * (1.0 - t))

func _physics_process(delta: float) -> void:
	elapsed += delta
	if arrived:
		var impact := clampf((elapsed - duration) / 0.34, 0.0, 1.0)
		ring_ink.set_shader_parameter("impact", impact)
		if impact >= 1.0:
			queue_free()
		return
	var t := minf(elapsed / duration, 1.0)
	var point := _point(t)
	var previous := _point(maxf(0.0, t - (0.10 if arc > 0.0 else 0.22)))
	var path := point - previous
	ember.global_position = point
	if path.length_squared() > 0.00001:
		var axis := path.normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
		var radius := 0.12 if arc > 0.0 else 0.055
		tail.global_transform = Transform3D(Basis(side * radius, path, side.cross(axis) * radius), point.lerp(previous, 0.5))
		tail.visible = true
	if ring_ink:
		ring_ink.set_shader_parameter("flight", t)
	if t >= 1.0:
		arrived = true
		ember.hide()
		tail.hide()
		landed.emit()
		if not ring:
			set_physics_process(false)
			queue_free()
		else:
			ring_ink.set_shader_parameter("impact", 0.0)
