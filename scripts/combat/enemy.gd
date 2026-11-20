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
const ATTACK_INTERVAL := 1.15
var attack_timer := 0.5
var gait_weight := 0.0
var breath := 0.0
var strike := 0.0
var windup := 0.0
var model: Node3D
var base_scale := Vector3.ONE
var last_hit := 0.0
var separation := Vector3.ZERO
var limbs: Array[Node3D] = []
var phases := PackedFloat32Array()
var rest_heights := PackedFloat32Array()
var fissure: StandardMaterial3D

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
	# Vary breathing independently from locomotion without consuming wave RNG.
	breath = fmod(get_instance_id() * 0.63, TAU)
	var marking := model.find_child("Cyan_fissure*" if stats.height < 1.0 else "Violet_fissure*", true, false) as MeshInstance3D
	if marking:
		var source := marking.get_active_material(0) as StandardMaterial3D
		if source:
			fissure = source.duplicate()
			for piece in model.find_children("*fissure*", "MeshInstance3D", true, false):
				(piece as MeshInstance3D).material_override = fissure
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
		rest_heights.append(pivot.position.y)
		phases.append(leg_phase)
		limbs.append(pivot)

func _pose(delta: float, distance: float, near: bool, core_distance: float) -> void:
	var crawler := stats.height < 1.0
	var gait_speed := distance / maxf(delta, 0.001)
	gait_weight = lerpf(gait_weight, clampf(gait_speed / stats.speed, 0.0, 1.0), 1.0 - exp(-12.0 * delta))
	# The feet advance with distance even while slowed by water or a field.
	stride = fmod(stride + distance * (6.2 if crawler else 3.5), TAU)
	breath = fmod(breath + delta * (2.9 if crawler else 1.8), TAU)
	strike = maxf(0.0, strike - delta / (0.24 if crawler else 0.34))
	last_hit = maxf(0.0, last_hit - delta)
	var anticipation := 0.0
	if attack_timer < 0.36 and is_zero_approx(strike):
		anticipation = 1.0 - smoothstep(0.0, 0.36, attack_timer)
		if not near:
			anticipation *= 1.0 - smoothstep(1.4, 2.6, core_distance)
	windup = lerpf(windup, anticipation, 1.0 - exp(-18.0 * delta))
	var hit := sin(PI * clampf(last_hit / 0.15, 0.0, 1.0))
	var thrust := smoothstep(0.0, 0.93, strike)
	if near and attack_timer <= 0.09 and attack_timer >= 0.0:
		thrust = maxf(thrust, 1.0 - smoothstep(0.0, 0.09, attack_timer))
	for i in limbs.size():
		var hinge := limbs[i]
		var phase := stride + phases[i]
		var swing := sin(phase) * gait_weight
		var lift := pow(maxf(0.0, cos(phase)), 1.4) * gait_weight
		if crawler:
			var side := signf(hinge.position.x)
			hinge.rotation.y = swing * 0.43 * side
			hinge.rotation.z = (lift * 0.34 + windup * 0.18 - thrust * 0.23) * side
		else:
			var arm := i >= 2
			hinge.position.y = rest_heights[i] + (0.0 if arm else lift * 0.13)
			hinge.rotation.x = swing * (0.33 if arm else 0.56)
			if arm:
				hinge.rotation.x += 0.15 + windup * (0.38 if i == 2 else 0.83) - thrust * (0.62 if i == 2 else 1.32)
	var bob := (1.0 - cos(stride * 2.0)) * gait_weight
	model.position.y = 0.015 + sin(breath) * 0.012 + bob * (0.026 if crawler else 0.045) - windup * 0.07
	model.position.z = thrust * (0.36 if crawler else 0.24) - windup * 0.10 - hit * 0.10
	model.rotation.x = thrust * 0.24 - windup * 0.14 - hit * 0.15
	model.rotation.z = sin(stride) * gait_weight * (0.060 if crawler else 0.12) + hit * 0.12
	if fissure:
		fissure.emission_energy_multiplier = 1.15 + 0.25 * sin(breath) + windup * 1.8 + hit * 2.0

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
	attack_timer -= delta
	if near and target.distance_squared_to(global_position) > 0.001:
		var aim := target - global_position
		rotation.y = lerp_angle(rotation.y, atan2(aim.x, aim.z), 1.0 - exp(-10.0 * delta))
	var connected := false
	if near and attack_timer <= 0.0:
		var from := body_center()
		var to := Vector3(target.x, maxf(from.y, target.y + 0.25), target.z)
		var sight := PhysicsRayQueryParameters3D.create(from, to, 1)
		if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			attack_timer = ATTACK_INTERVAL
			strike = 1.0
			connected = true
	_pose(delta, flat_distance(before, global_position), near, flat_distance(global_position, target))
	return connected

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

func withdraw(defeated := false) -> void:
	if fading:
		return
	fading = true
	var tween := create_tween()
	if defeated:
		var crawler := stats.height < 1.0
		# Break the silhouette first, then let the fallen shell sink into the ground.
		tween.set_parallel(true)
		tween.tween_property(model, "rotation:z", 0.62 if crawler else -0.94, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(model, "position:y", 0.02 if crawler else -0.16, 0.24)
		for hinge in limbs:
			tween.tween_property(hinge, "rotation:x", -0.72 if crawler else 0.59, 0.18)
		if fissure:
			tween.tween_property(fissure, "emission_energy_multiplier", 0.0, 0.36)
		tween.chain().tween_property(model, "scale", base_scale * 0.03, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(model, "scale", Vector3.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
