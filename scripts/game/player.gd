class_name CinderPlayer
extends CharacterBody3D

var move_enabled := true
var tactical := false
var camera: Camera3D
var visual: TravelerVisual
var recovery_point: Vector3
## Seconds of committed swing: steering is reduced and the facing is held.
var attack_hold := 0.0
var _aim_target: CinderEnemy
var _aim_heading := 0.0
var _windup_left := 0.0
## Short forward burst from a swing, decaying each physics step.
var lunge := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(47.0)
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.65
	capsule.radius = 0.29
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.83
	add_child(collider)

func commit_swing(target: CinderEnemy, fallback: Vector3, windup: float, duration: float) -> void:
	_aim_target = target
	_aim_heading = atan2(-fallback.x, -fallback.z)
	_windup_left = windup
	attack_hold = duration

func clear_swing() -> void:
	_aim_target = null
	_windup_left = 0.0
	attack_hold = 0.0
	lunge = Vector3.ZERO

func _turn_into_swing(delta: float) -> void:
	if _windup_left <= 0.0:
		return
	if is_instance_valid(_aim_target) and not _aim_target.fading:
		var offset := (_aim_target.global_position - global_position).slide(Vector3.UP)
		if offset.length_squared() > 0.0025:
			_aim_heading = atan2(-offset.x, -offset.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, _aim_heading, minf(delta / _windup_left, 1.0))
	_windup_left = maxf(0.0, _windup_left - delta)

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	var input := Vector2.ZERO
	if move_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := camera.global_basis.x
	right.y = 0.0
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var direction := right.normalized() * input.x - forward.normalized() * input.y
	var speed := 6.1 if Input.is_action_pressed("sprint") else 3.65
	if Input.is_action_pressed("walk"):
		speed = 2.05
	if attack_hold > 0.0:
		_turn_into_swing(delta)
		attack_hold = maxf(0.0, attack_hold - delta)
		speed *= 0.28
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 31.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 31.0)
	velocity.y = maxf(-24.0, velocity.y - delta * 21.0)
	velocity += lunge
	move_and_slide()
	velocity -= lunge
	lunge = lunge.move_toward(Vector3.ZERO, delta * 22.0)
	if direction.length_squared() > 0.01 and attack_hold <= 0.0:
		var heading := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, heading, 1.0 - exp(-13.0 * delta))
	if visual != null:
		visual.animate(delta, get_real_velocity().slide(Vector3.UP).length(), tactical)
	if global_position.y < -4.5:
		global_position = recovery_point
		velocity = Vector3.ZERO
