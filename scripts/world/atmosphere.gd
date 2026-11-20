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
	environment.ambient_light_color = Color("#738ebc")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.06
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 16.0
	environment.fog_depth_end = 112.0
	environment.fog_depth_curve = 1.3
	environment.fog_density = 0.76
	environment.fog_light_color = Color("#2c4767")
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
	key.light_color = Color("#c6d9f1")
	key.light_energy = 1.21
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 52.0
	key.shadow_bias = 0.06
	key.shadow_normal_bias = 0.48
	add_child(key)
	_add_ridges()

func _process(delta: float) -> void:
	if not sunrise:
		return
	_dawn = move_toward(_dawn, 1.0, delta * 0.16)
	var light := smoothstep(0.0, 1.0, _dawn)
	sky_material.set_shader_parameter("dawn", light)
	key.light_color = Color("#c6d9f1").lerp(Color("#ffd098"), light)
	key.light_energy = lerpf(1.21, 2.0, light)
	key.rotation_degrees.x = lerpf(-29.0, -14.0, light)
	key.rotation_degrees.y = rad_to_deg(lerp_angle(deg_to_rad(-41.0), deg_to_rad(146.0), light))
	environment.ambient_light_color = Color("#738ebc").lerp(Color("#b0c7df"), light)
	environment.fog_light_color = Color("#2c4767").lerp(Color("#8794a5"), light)

func _add_ridges() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 4047
	var colors: Array[Color] = [Color("#223755"), Color("#3a5273"), Color("#506887")]
	for layer in range(3):
		var radius := 75.0 + float(layer) * 46.0
		var tools := SurfaceTool.new()
		tools.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.set_smooth_group(-1)
		var profile: Array[PackedVector3Array] = []
		for step in range(81):
			var angle := TAU * float(step) / 80.0
			var ridge_line := 5.0 + absf(sin(angle * 3.0 + layer * 1.4)) * 11.0
			var peak := pow(absf(cos(angle * 5.0 + layer * 0.29)), 7.0) * (10.0 + layer * 4.5)
			var top := ridge_line + peak + layer * 7.0 + random.randf_range(-2.4, 2.4)
			var west := pow(maxf(0.0, -cos(angle)), 6.0) * 38.0
			var north := pow(maxf(0.0, -sin(angle)), 9.0) * 56.0
			var local_radius := radius + west + north
			var direction := Vector3(cos(angle), 0, sin(angle))
			var base := local_radius - 31.0 - absf(sin(angle * 4.0)) * 15.0
			var notch := sin(angle * 7.0 + 0.9) * 4.0
			profile.append(PackedVector3Array([
				direction * base + Vector3.DOWN * 7.0,
				direction * (base + 13.0 + notch) + Vector3.UP * (top * 0.22),
				direction * (local_radius - 7.0 + notch) + Vector3.UP * (top * 0.64),
				direction * (local_radius + notch) + Vector3.UP * top,
			]))
		for step in range(profile.size() - 1):
			var first := profile[step]
			var second := profile[step + 1]
			for row in range(3):
				for point in [first[row], first[row + 1], second[row + 1],
						first[row], second[row + 1], second[row]]:
					var shade := clampf((point.y + 6.0) / 31.0, 0.0, 1.0)
					tools.set_color(colors[layer].darkened(0.31).lerp(colors[layer].lightened(0.17), shade))
					tools.add_vertex(point)
		tools.generate_normals()
		var ridge := MeshInstance3D.new()
		ridge.mesh = tools.commit()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ridge.material_override = material
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ridge)
