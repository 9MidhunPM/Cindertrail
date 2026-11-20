class_name CinderAtmosphere
extends Node3D

const SKY_SHADER := preload("res://scripts/world/night_sky.gdshader")
var sky_material: ShaderMaterial
var environment: Environment
var key: DirectionalLight3D
var sunrise := false
var _dawn := 0.0

func _ready() -> void:
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#7796cb")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.06
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 16.0
	environment.fog_depth_end = 112.0
	environment.fog_depth_curve = 1.3
	environment.fog_density = 0.76
	environment.fog_light_color = Color("#345881")
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_bloom = 0.045
	environment.glow_intensity = 0.52
	environment.glow_hdr_threshold = 1.18
	environment.sky = Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	environment.sky.sky_material = sky_material
	world_environment.environment = environment
	add_child(world_environment)
	key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-29, -41, 0)
	key.light_color = Color("#ffe7c6")
	key.light_energy = 1.32
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 52.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 0.48
	add_child(key)


func _process(delta: float) -> void:
	if not sunrise:
		return
	_dawn = move_toward(_dawn, 1.0, delta * 0.16)
	var light := smoothstep(0.0, 1.0, _dawn)
	sky_material.set_shader_parameter("dawn", light)
	key.light_color = Color("#ffe7c6").lerp(Color("#ffd098"), light)
	key.light_energy = lerpf(1.32, 2.0, light)
	key.rotation_degrees.x = lerpf(-29.0, -14.0, light)
	key.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(-41.0), deg_to_rad(146.0), light))
	environment.ambient_light_color = Color("#7796cb").lerp(Color("#b0c7df"), light)
	environment.fog_light_color = Color("#345881").lerp(Color("#8794a5"), light)
