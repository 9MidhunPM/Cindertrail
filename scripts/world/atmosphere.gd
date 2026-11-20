class_name CinderAtmosphere
extends Node3D

const SKY_SHADER := preload("res://scripts/world/night_sky.gdshader")
const MOON_DIRECTION := Vector3(0.49, 0.25, -0.91)
const SUN_DIRECTION := Vector3(-0.42, 0.185, -0.91)
const MOONLIGHT := Color("#b1c7ff")
const SKY_FILL := Color("#6d93d7")
const NIGHT_HAZE := Color("#233e6a")
const MOON_ENERGY := 0.60
const NIGHT_FILL := 0.29
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
	environment.ambient_light_color = SKY_FILL
	environment.ambient_light_energy = NIGHT_FILL
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.06
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 16.0
	environment.fog_depth_end = 112.0
	environment.fog_depth_curve = 1.3
	environment.fog_density = 0.76
	environment.fog_light_color = NIGHT_HAZE
	environment.fog_sky_affect = 0.0
	environment.glow_enabled = true
	environment.glow_bloom = 0.045
	environment.glow_intensity = 0.52
	environment.glow_hdr_threshold = 1.18
	environment.sky = Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("moon_direction", MOON_DIRECTION.normalized())
	sky_material.set_shader_parameter("sun_direction", SUN_DIRECTION.normalized())
	environment.sky.sky_material = sky_material
	world_environment.environment = environment
	add_child(world_environment)
	key = DirectionalLight3D.new()
	key.name = "MoonAndDawn"
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 52.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 0.48
	add_child(key)
	set_dawn_fraction(0.0)


func _process(delta: float) -> void:
	if not sunrise or _dawn >= 1.0:
		return
	set_dawn_fraction(move_toward(_dawn, 1.0, delta * 0.16))

func set_dawn_fraction(value: float) -> void:
	_dawn = clampf(value, 0.0, 1.0)
	var light := smoothstep(0.0, 1.0, _dawn)
	sky_material.set_shader_parameter("dawn", light)
	key.look_at(-MOON_DIRECTION.normalized().slerp(SUN_DIRECTION.normalized(), light))
	key.light_color = MOONLIGHT.lerp(Color("#ffd098"), light)
	key.light_energy = lerpf(MOON_ENERGY, 2.0, light)
	environment.ambient_light_color = SKY_FILL.lerp(Color("#b0c7df"), light)
	environment.ambient_light_energy = lerpf(NIGHT_FILL, 0.56, light)
	environment.fog_light_color = NIGHT_HAZE.lerp(Color("#8794a5"), light)
