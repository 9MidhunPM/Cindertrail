class_name CinderInstalledModule
extends Node3D

var kind: int
var level: int
var stats: CinderModuleStats
var cooldown := 0.0
var model: Node3D
var field_ring: MeshInstance3D
var ripple := 0.0

func configure(type: int, rank: int, spec: CinderModuleStats) -> void:
	kind = type
	level = rank
	stats = spec
	model = spec.model.instantiate() as Node3D
	add_child(model)
	model.scale = Vector3.ONE * 1.55
	if kind == 1:
		field_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = stats.reach - 0.035
		torus.outer_radius = stats.reach + 0.035
		torus.rings = 56
		torus.ring_segments = 4
		field_ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.25, 0.85, 0.80, 0.42)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		field_ring.material_override = mat
		field_ring.position.y = 0.12
		field_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(field_ring)

func _process(delta: float) -> void:
	if field_ring:
		ripple = fmod(ripple + delta * 0.67, 1.0)
		field_ring.scale = Vector3.ONE * (0.25 + ripple * 0.75)
