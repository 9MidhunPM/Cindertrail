extends SceneTree
## Renders the six combat rigs at the same live gait/attack beats in a neutral model-review scene.
## godot --script tools/qa/bestiary_poses.gd -- --out=/absolute/folder

const MEMBERS := [
	preload("res://data/enemies/crawler.tres"), preload("res://data/enemies/brute.tres"),
	preload("res://data/enemies/ford_skimmer.tres"), preload("res://data/enemies/quarry_ram.tres"),
	preload("res://data/enemies/splinterback.tres"), preload("res://data/enemies/bell_warden.tres"),
]
const FRAMES := [35, 42, 28, 86, 92, 99]
var destination := ""
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var battle: CinderBattle
var camp: CinderSite

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			destination = arg.trim_prefix("--out=")
	if destination == "" or DisplayServer.get_name() == "headless":
		push_error("The pose review needs a graphical renderer and --out=/absolute/folder")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	_stage()
	for i in MEMBERS.size():
		var member: CinderEnemyStats = MEMBERS[i]
		camp.wet = member.species == &"ford_skimmer"
		var enemy := battle.spawn_enemy(member, PackedVector3Array([Vector3(0,0,-7.5), Vector3.ZERO]), camp)
		if member.species == &"bell_warden":
			# The ally triggers the actual ward animation. Keep it off the portrait side.
			var ally := battle.spawn_enemy(MEMBERS[1], PackedVector3Array([Vector3(-3.5,0,-6), Vector3.ZERO]), camp)
			ally.model.hide()
		for n in FRAMES[i]:
			await physics_frame
		battle.set_physics_process(false)
		var bounds := _bounds(enemy.model)
		var target := bounds.get_center()
		var width := maxf(bounds.size.x * 1.2, bounds.size.z)
		camera.size = maxf(bounds.size.y * 1.45, width * 0.80)
		camera.position = target + Vector3(4.1, 2.12, 6.1)
		camera.look_at(target)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png(destination.path_join(String(member.species) + ".png"))
		if error != OK:
			quit(1)
			return
		for item in battle.enemies.duplicate():
			battle.enemies.erase(item)
			item.free()
		battle.set_physics_process(true)
	quit()

func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_bounds: AABB = part.global_transform * part.get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	return bounds

func _stage() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 420)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#e1d0aa")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8c6de")
	env.ambient_light_energy = 0.85
	world.environment = env
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-43,-34,0)
	key.light_color = Color("#fff1cf")
	key.light_energy = 1.48
	key.shadow_enabled = true
	stage.add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80,80)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#c2b59a")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var ground := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,1,80)
	floor_collision.shape = box
	ground.position.y = -0.5
	ground.add_child(floor_collision)
	stage.add_child(ground)
	var light := preload("res://scenes/core/sun_core.tscn").instantiate() as SunCore
	stage.add_child(light)
	light.hide()
	battle = CinderBattle.new()
	stage.add_child(battle)
	battle.bind_carried_core(light)
	camp = CinderSite.new()
	stage.add_child(camp)
	camp.configure(preload("res://data/sites/grove.tres"), Vector3.ZERO, PackedVector3Array(), [], Vector3.ZERO, Vector3.ZERO)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
