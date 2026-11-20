class_name CinderCamera
extends Node3D

var camera: Camera3D
var player: CinderPlayer
var yaw := -0.055
var pitch := 0.19
var tactical := false
var tactical_position := Vector3.ZERO
var tactical_look := Vector3.ZERO
var ending := false
var _blend := 0.0
var _view := Transform3D.IDENTITY

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "JourneyCamera"
	camera.fov = 56.0
	camera.near = 0.075
	camera.far = 320.0
	add_child(camera)
	camera.make_current()

func reset_pose() -> void:
	_view = _explore_pose(false)
	camera.global_transform = _view

func orbit(relative: Vector2) -> void:
	if not tactical and not ending:
		yaw -= relative.x * 0.0027
		pitch = clampf(pitch - relative.y * 0.0027, -0.34, 0.82)

func show_site(view_position: Vector3, view_target: Vector3) -> void:
	tactical_position = view_position
	tactical_look = view_target
	tactical = true

func show_ending(view_position: Vector3, view_target: Vector3) -> void:
	show_site(view_position, view_target)
	ending = true

func settled() -> bool:
	return _blend >= 0.995 if tactical else _blend <= 0.005

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_blend = move_toward(_blend, 1.0 if tactical else 0.0, delta / 1.02)
	var weight := smoothstep(0.0, 1.0, _blend)
	var target := _explore_pose(true)
	if _blend > 0.0:
		target = target.interpolate_with(
			Transform3D(Basis.IDENTITY, tactical_position).looking_at(tactical_look), weight)
	_view = _view.interpolate_with(target, 1.0 - exp(-14.0 * delta))
	camera.global_transform = _view
	camera.fov = lerpf(56.0, 46.0, weight)

func _explore_pose(check_collision: bool) -> Transform3D:
	var heading := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var aim := player.global_position + Vector3(0, 1.35, 0)
	var back := heading.z
	var offset := heading.x * 1.06 + back * 4.4
	var destination := aim + offset
	if check_collision:
		var shape := SphereShape3D.new()
		shape.radius = 0.21
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = aim
		query.motion = offset
		query.collision_mask = 1
		var fraction := get_world_3d().direct_space_state.cast_motion(query)
		if fraction.size() > 0:
			destination = aim + offset * maxf(0.08, fraction[0] - 0.012)
	var look := aim + heading.x * 1.68 + heading.y * 0.12
	return Transform3D(Basis.IDENTITY, destination).looking_at(look)
