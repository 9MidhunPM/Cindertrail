extends SceneTree
## Windowed capture of the traveler model, idle guard and each melee swing.
## godot --script tools/qa/traveler_poses.gd -- --out=/absolute/folder

const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const SIZE := Vector2i(640, 720)

var out := ""
var record_motion := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
		record_motion = record_motion or argument == "--motion"
	DirAccess.make_dir_recursive_absolute(out)
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#d9cdb2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#a9b6c8")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#cbbd9c")
	floor_mesh.material_override = floor_material
	viewport.add_child(floor_mesh)
	var traveler := TRAVELER.instantiate() as TravelerVisual
	viewport.add_child(traveler)
	var camera := Camera3D.new()
	camera.fov = 38
	viewport.add_child(camera)
	var views := {"front": 0.0, "three-quarter": -0.7, "side": -PI * 0.5, "back": PI}
	for view: String in views:
		_aim(camera, views[view], 4.2)
		for frame in 30:
			traveler.animate(1.0 / 60.0, 0.0, false)
			await process_frame
		await _save(viewport, "model-" + view)
	_aim(camera, -0.55, 4.6)
	for swing in 3:
		traveler.attack(swing)
		var stamps := [0.0, 0.08, 0.15, 0.24, 0.42] if swing < 2 else [0.0, 0.14, 0.3, 0.42, 0.6]
		var elapsed := 0.0
		for stamp: float in stamps:
			while elapsed < stamp:
				traveler.animate(1.0 / 120.0, 0.0, false)
				elapsed += 1.0 / 120.0
			await process_frame
			await _save(viewport, "swing%d-%03d" % [swing, roundi(stamp * 100)])
		for frame in 120:
			traveler.animate(1.0 / 60.0, 0.0, false)
	await _save(viewport, "guard")
	if record_motion:
		await _record_stride(viewport, traveler, camera)
	quit()

func _record_stride(viewport: SubViewport, traveler: TravelerVisual, camera: Camera3D) -> void:
	var directory := out.path_join("stride")
	DirAccess.make_dir_recursive_absolute(directory)
	_aim(camera, -1.2, 3.5)
	for frame in 108:
		var time := frame / 24.0
		var speed := lerpf(2.05, 6.1, smoothstep(0.65, 2.65, time))
		speed *= 1.0 - smoothstep(3.55, 3.9, time)
		traveler.rotation.y = smoothstep(2.0, 3.0, time) * 0.9
		for tick in 5:
			traveler.animate(1.0 / 120.0, speed, false)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(directory.path_join("%03d.jpg" % frame), 0.92)

func _aim(camera: Camera3D, yaw: float, distance: float) -> void:
	var target := Vector3(0, 1.0, 0)
	camera.position = target + Vector3(sin(yaw), 0.18, -cos(yaw)) * distance
	camera.look_at(target)

func _save(viewport: SubViewport, label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out.path_join(label + ".png"))
