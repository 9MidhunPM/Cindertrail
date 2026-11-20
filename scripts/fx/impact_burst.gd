class_name CinderImpactBurst
extends Node3D
## One-shot amber sparks and a flat shock ring at a blade impact.

static var _spark_mesh: QuadMesh
static var _spark_process: ParticleProcessMaterial
static var _ring_mesh: PlaneMesh

var _ring: MeshInstance3D
var _ring_ink: ShaderMaterial
var _radius := 1.0
var _age := 0.0
var _life := 0.32

static func spawn(parent: Node, point: Vector3, sparks: int, ring_radius := 0.0) -> CinderImpactBurst:
	var burst := CinderImpactBurst.new()
	parent.add_child(burst)
	burst.global_position = point
	burst._emit(sparks, ring_radius)
	return burst

func _emit(sparks: int, ring_radius: float) -> void:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.05, 0.16)
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ink.vertex_color_use_as_albedo = true
		ink.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		ink.albedo_color = Color(1.0, 0.75, 0.38) * 2.5
		_spark_mesh.material = ink
		_spark_process = ParticleProcessMaterial.new()
		_spark_process.direction = Vector3.UP
		_spark_process.spread = 180.0
		_spark_process.initial_velocity_min = 2.5
		_spark_process.initial_velocity_max = 6.5
		_spark_process.gravity = Vector3(0, -11, 0)
		_spark_process.scale_min = 0.6
		_spark_process.scale_max = 1.3
		_spark_process.particle_flag_align_y = true
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
		fade.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		_spark_process.color_ramp = ramp
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(2, 2)
	var emitter := GPUParticles3D.new()
	emitter.amount = maxi(1, sparks)
	emitter.lifetime = 0.42
	emitter.one_shot = true
	emitter.explosiveness = 0.96
	emitter.process_material = _spark_process
	emitter.draw_pass_1 = _spark_mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	emitter.emitting = true
	if ring_radius > 0.0:
		_radius = ring_radius
		_life = 0.45
		_ring = MeshInstance3D.new()
		_ring.mesh = _ring_mesh
		_ring_ink = ShaderMaterial.new()
		_ring_ink.shader = preload("res://scripts/combat/mortar_ring.gdshader")
		_ring.material_override = _ring_ink
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.position.y = 0.06
		add_child(_ring)

func _process(delta: float) -> void:
	_age += delta
	if _ring:
		var t := clampf(_age / 0.34, 0.0, 1.0)
		_ring.scale = Vector3.ONE * _radius
		_ring_ink.set_shader_parameter("impact", t)
	if _age > maxf(_life, 0.5):
		queue_free()
