class_name CinderMote
extends Node3D
## A cosmetic clockwork guide that hovers near the traveler.

const BRONZE := Color("#936a46")
const BRASS := Color("#d2a66c")
const PATINA := Color("#348e84")
const DARK := Color("#2c3339")
const INLAY := Color("#79e0cd")

var _player: Node3D
var _camera: Camera3D
var _shell := Node3D.new()
var _wings: Array[Node3D] = []
var _lens_material := StandardMaterial3D.new()
var _terrain_ray := PhysicsRayQueryParameters3D.new()
var _anchor := Vector3.ZERO
var _tactical := false
var _reduced_motion := false
var _clock := 0.0
var _speech := 0.0
var _speech_remaining := 0.0
var _tuck := 0.0

func _ready() -> void:
	add_child(_shell)
	_build_moth()
	_terrain_ray.collision_mask = 1
	set_process(false)
	set_physics_process(false)

func configure(player: Node3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera

func set_presence(active: bool, tactical: bool, reduced_motion: bool) -> void:
	_tactical = tactical
	_reduced_motion = reduced_motion
	if active == visible:
		return
	visible = active
	set_process(active)
	set_physics_process(active)
	if active and is_instance_valid(_player) and is_instance_valid(_camera):
		_anchor = _desired_position()
		global_position = _anchor
		rotation.y = _heading()
		_tuck = float(tactical)
		_pose()
	if not active:
		_speech = 0.0
		stop_speech()

func speak(duration := 0.65) -> void:
	if visible and not _reduced_motion:
		_speech_remaining = duration

func stop_speech() -> void:
	_speech_remaining = 0.0

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	_anchor = _desired_position()
	_terrain_ray.from = _player.global_position + Vector3.UP * 1.38
	_terrain_ray.to = _anchor
	var hit := get_world_3d().direct_space_state.intersect_ray(_terrain_ray)
	if not hit.is_empty():
		var distance := _terrain_ray.from.distance_to(hit.position)
		_anchor = _terrain_ray.from.move_toward(_anchor, maxf(0.0, distance - .16))

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_camera):
		return
	var weight := 1.0 - exp(-11.0 * delta)
	if global_position.distance_squared_to(_anchor) > 12.25:
		global_position = _anchor
	else:
		global_position = global_position.lerp(_anchor, weight)
	rotation.y = lerp_angle(rotation.y, _heading(), weight)
	_tuck = lerpf(_tuck, float(_tactical), weight)
	if not _reduced_motion:
		_clock = fmod(_clock + delta, TAU * 100.0)
	_speech_remaining = maxf(_speech_remaining - delta, 0.0)
	_speech = move_toward(_speech, float(_speech_remaining > 0.0), delta * 6.0)
	_pose()

func _desired_position() -> Vector3:
	var right := _camera.global_basis.x.slide(Vector3.UP).normalized()
	var forward := -_camera.global_basis.z.slide(Vector3.UP).normalized()
	var above := 1.64 if _tactical else 1.83
	var beside := .57 if _tactical else .83
	return _player.global_position + Vector3.UP * above + right * beside + forward * .29

func _heading() -> float:
	var forward := -_camera.global_basis.z
	return atan2(-forward.x, -forward.z) - .3

func _pose() -> void:
	var voice := 0.0 if _reduced_motion else _speech * (0.63 + 0.28 * sin(_clock * TAU * 3.7))
	var flutter := 0.0 if _reduced_motion else sin(_clock * TAU * 5.5)
	var wing := lerpf(.34, 1.12, _tuck) + flutter * lerpf(.52, .12, _tuck)
	_wings[0].rotation.z = wing + voice * .17
	_wings[1].rotation.z = -wing - voice * .17
	var hover := 0.0 if _reduced_motion else sin(_clock * 5.2) * lerpf(.064, .024, _tuck)
	_shell.position.y = hover + voice * .07
	_shell.rotation.x = -.11 - voice * .16
	_shell.scale = Vector3.ONE * lerpf(1.0, .8, _tuck)
	_lens_material.emission_energy_multiplier = lerpf(1.35, .77, _tuck) + voice * .72

func _build_moth() -> void:
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.vertex_color_is_srgb = true
	metal.roughness = .6
	metal.metallic = .27
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := _surface()
	_shell_section(body, Vector3(0, -.011, 0), Vector2(.059, .048), .164, BRONZE)
	_shell_section(body, Vector3(0, .001, -.12), Vector2(.053, .041), .068, DARK)
	_shell_section(body, Vector3(0, 0, .108), Vector2(.048, .038), .048, PATINA)
	for side: float in [1.0, -1.0]:
		var start := Vector3(.029 * side, .026, -.144)
		var bend := Vector3(.058 * side, .044, -.193)
		var tip := Vector3(.097 * side, .087, -.223)
		_stem(body, start, bend, .007, BRONZE)
		_stem(body, bend, tip, .0045, BRASS)
		_shell_section(body, Vector3(.061 * side, 0, -.027), Vector2(.024, .021), .068, BRASS)
	_mesh(_shell, body, metal, "ClockworkBody")

	_lens_material.albedo_color = INLAY
	_lens_material.emission_enabled = true
	_lens_material.emission = Color("#38c6ba")
	_lens_material.roughness = .48
	_lens_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lens := _surface()
	_shell_section(lens, Vector3(0, .043, -.064), Vector2(.027, .026), .082, Color.WHITE)
	_mesh(_shell, lens, _lens_material, "WayfinderJewel")

	var panel := _surface()
	_wing_panel(panel, [Vector2(.004, -.032), Vector2(.235, -.137), Vector2(.272, -.058),
		Vector2(.20, .046), Vector2(.093, .094)], Vector2(.122, -.029))
	_wing_panel(panel, [Vector2(.014, .009), Vector2(.127, .056), Vector2(.168, .149),
		Vector2(.097, .184), Vector2(.047, .121)], Vector2(.071, .072))
	var wing_mesh := _commit(panel)
	for side: float in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingR" if side > 0.0 else "WingL"
		pivot.position = Vector3(.049 * side, .016, -.031)
		_shell.add_child(pivot)
		var wing := _mount(pivot, wing_mesh, metal, "LappedBronze")
		wing.scale.x = side
		_wings.append(pivot)

func _surface() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	return tool

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

func _shell_section(tool: SurfaceTool, center: Vector3, radii: Vector2,
		length: float, tint: Color) -> void:
	var nose := center + Vector3.FORWARD * length * .5
	var tail := center + Vector3.BACK * length * .5
	for index in 8:
		var a := TAU * float(index) / 8.0
		var b := TAU * float(index + 1) / 8.0
		var near := center + Vector3(cos(a) * radii.x, sin(a) * radii.y, 0)
		var far := center + Vector3(cos(b) * radii.x, sin(b) * radii.y, 0)
		_triangle(tool, nose, far, near, tint)
		_triangle(tool, tail, near, far, tint.darkened(.15))

func _stem(tool: SurfaceTool, start: Vector3, finish: Vector3, width: float, tint: Color) -> void:
	var offset := (finish - start).normalized().cross(Vector3.UP) * width
	_triangle(tool, start + offset, finish + offset, finish - offset, tint)
	_triangle(tool, start + offset, finish - offset, start - offset, tint)

func _wing_panel(tool: SurfaceTool, edge: Array[Vector2], center: Vector2) -> void:
	var keel := Vector3(center.x, -.014, center.y)
	for index in edge.size():
		var a := edge[index]
		var b := edge[(index + 1) % edge.size()]
		var first := Vector3(a.x, 0, a.y)
		var second := Vector3(b.x, 0, b.y)
		var inset_a := keel.lerp(first, .84)
		var inset_b := keel.lerp(second, .84)
		var rim := BRASS if index == 1 or index == 2 else BRONZE
		_triangle(tool, first, second, inset_b, rim)
		_triangle(tool, first, inset_b, inset_a, rim)
		_triangle(tool, inset_a, inset_b, keel, PATINA.darkened(.11 * float(index % 3)))

func _commit(tool: SurfaceTool) -> ArrayMesh:
	tool.generate_normals()
	return tool.commit()

func _mesh(parent: Node3D, tool: SurfaceTool, material: Material, label: String) -> void:
	_mount(parent, _commit(tool), material, label)

func _mount(parent: Node3D, mesh: Mesh, material: Material, label: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
