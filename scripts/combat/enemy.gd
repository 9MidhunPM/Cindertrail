class_name CinderEnemy
extends CharacterBody3D

var stats: CinderEnemyStats
var health: float
var site_of_origin: CinderSite
var route: PackedVector3Array
var pursuing := false
var fading := false
var step := 0
var stride := 0.0
var attack_timer := 0.5
var model: Node3D
var base_scale := Vector3.ONE
var last_hit := 0.0
var separation := Vector3.ZERO
var limbs: Array[Node3D] = []
var phases := PackedFloat32Array()

func configure(spec: CinderEnemyStats, path: PackedVector3Array, camp: CinderSite) -> void:
	stats = spec
	health = stats.health
	site_of_origin = camp
	route = path.duplicate()
	model = stats.model.instantiate() as Node3D
	add_child(model)
	base_scale = Vector3.ONE * (1.28 if stats.height < 1.0 else 1.18)
	_rig_limbs()
	model.scale = base_scale
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.55
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26 if stats.height < 1.0 else 0.43
	capsule.height = maxf(stats.height, capsule.radius * 2.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5 + 0.02
	add_child(shape)
	global_position = route[0] + Vector3.UP * 0.09
	step = 1

# The starter meshes have separate rigid leg pieces. Pair them at each hip or
# shoulder and rotate the joints in alternating phases as the creature moves.
func _rig_limbs() -> void:
	var crawler := stats.height < 1.0
	if crawler:
		_pair_limbs("Leg_upper*", "Leg_lower*", Vector3(0.22,0.42,0), true)
	else:
		_pair_limbs("Shin*", "Foot*", Vector3(0.3,0.68,0), false)
		_pair_limbs("Arm*", "Fist*", Vector3(0.58,1.55,0), false)

func _pair_limbs(upper_name: String, lower_name: String, joint: Vector3, crawler: bool) -> void:
	var upper := model.find_children(upper_name, "MeshInstance3D", true, false)
	var lower := model.find_children(lower_name, "MeshInstance3D", true, false)
	for i in mini(upper.size(), lower.size()):
		var segment := upper[i] as MeshInstance3D
		var pivot := Node3D.new()
		segment.get_parent().add_child(pivot)
		pivot.position = Vector3(signf(segment.position.x)*joint.x, joint.y, segment.position.z - 0.04 if crawler else joint.z)
		segment.reparent(pivot, true)
		lower[i].reparent(pivot, true)
		var leg_phase := PI * (i % 2)
		if upper_name == "Arm*":
			leg_phase += PI
		phases.append(leg_phase)
		limbs.append(pivot)

func _pose_limbs(walking: bool) -> void:
	var amplitude := 1.0 if walking else 0.12
	for i in limbs.size():
		var phase := stride + phases[i]
		if stats.height < 1.0:
			var side := signf(limbs[i].position.x)
			limbs[i].rotation.y = sin(phase)*0.25*side*amplitude
			limbs[i].rotation.z = maxf(0.0, cos(phase))*0.20*side*amplitude
		else:
			limbs[i].rotation.x = sin(phase)*0.33*amplitude

func wound(amount: float) -> void:
	health -= amount
	last_hit = 0.15

func body_center() -> Vector3:
	return global_position + Vector3.UP * stats.height * 0.7

func follow_trail(point: Vector3) -> void:
	if route.is_empty() or route[-1].distance_squared_to(point) >= 0.65:
		if step > 24:
			route = route.slice(step)
			step = 0
		route.append(point)

func advance(core: SunCore, delta: float, field_factor: float) -> bool:
	var target := core.global_position
	while step < route.size() and flat_distance(global_position, route[step]) < 0.6:
		step += 1
	var waypoint := route[step] if step < route.size() else target
	var direction := waypoint - global_position
	direction.y = 0
	var close_to_target := flat_distance(global_position, target) < 1.35 and absf(target.y - global_position.y) < 2.5
	var near := close_to_target and step >= route.size() - 1
	var speed := stats.speed * field_factor
	if site_of_origin.wet_depth_at(global_position):
		speed *= 0.53
	var movement := Vector3.ZERO
	if not near:
		movement = (direction.normalized() + separation.limit_length(0.55)).normalized() * speed
		if movement.length_squared() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(movement.x, movement.z), 1.0-exp(-10*delta))
	velocity.x = movement.x
	velocity.z = movement.z
	velocity.y = maxf(velocity.y - 18.0 * delta, -14.0)
	var before := global_position
	move_and_slide()
	if is_on_floor() and movement.length_squared() > 0.1 and flat_distance(before, global_position) < speed * delta * 0.35:
		_climb_step(movement.normalized())
	stride += delta * (stats.speed * 3.2 if not near else 2.0)
	_pose_limbs(not near)
	last_hit = maxf(last_hit - delta, 0.0)
	model.position.y = absf(sin(stride)) * 0.06
	model.rotation.z = sin(stride) * 0.055 + last_hit * 0.6
	attack_timer -= delta
	if near and attack_timer <= 0.0:
		var from := body_center()
		var to := Vector3(target.x, maxf(from.y, target.y + 0.25), target.z)
		if not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty():
			return false
		attack_timer = 1.15
		model.rotation.x = -0.15
		return true
	model.rotation.x = move_toward(model.rotation.x, 0.0, 1.8 * delta)
	return false

# Jolt slides capsules against vertical risers. Only step onto a verified floor
# within one low stone course; solid walls and gaps keep blocking movement.
func _climb_step(forward: Vector3) -> void:
	var lift := Vector3.UP * 0.33
	if test_move(global_transform, lift):
		return
	var lifted := global_transform.translated(lift)
	var advance_by := forward * 0.24
	if test_move(lifted, advance_by):
		return
	var landing := KinematicCollision3D.new()
	if not test_move(lifted.translated(advance_by), -lift - Vector3.UP * 0.04, landing):
		return
	if landing.get_normal().y < 0.70:
		return
	global_position += lift + advance_by + landing.get_travel()
	velocity.y = 0.0

func withdraw() -> void:
	fading = true
	var tween := create_tween()
	tween.tween_property(model, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
