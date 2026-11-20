class_name CinderPlayer
extends CharacterBody3D

signal movement_used(action: StringName)
signal dash_segment(kind: StringName, from: Vector3, to: Vector3)
signal recovered(from: Vector3, to: Vector3)

const FOOTING := preload("res://scripts/game/traveler_footing.gd")
const DASH_SPEED := 13.0
const DASH_SECONDS := .18
const DASH_COOLDOWN := .8
const JUMP_SPEED := 5.8
const COYOTE_SECONDS := .10
const BUFFER_SECONDS := .12
const GRAVITY := 21.0

var move_enabled := true:
	set(value):
		if value and not move_enabled:
			_input_after_frame = Engine.get_physics_frames() + 1
		move_enabled = value
		if not value:
			_jump_buffer = 0.0
			_stop_dash()
var tactical := false
var camera: Camera3D
var visual: TravelerVisual
var recovery_point := Vector3.INF
var footing_filter: Callable:
	set(value):
		footing_filter = value
		if _footing:
			_footing.dry_filter = value
var _footing: FOOTING
var _jump_buffer := 0.0
var _coyote := 0.0
var _dash_time := 0.0
var _dash_speed := 0.0
var _dash_dir := Vector3.ZERO
var _dash_kind: StringName
var _dash_recovery := 0.0
var _stagger := 0.0
var _safe_time := 0.0
var _safe_probe := 0.0
var _safe_now := false
var _deferred_restore := Vector3.INF
var _input_after_frame := -1
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
	_footing = FOOTING.new(self, capsule, collider.position.y)
	_footing.dry_filter = footing_filter
	_footing.opening = recovery_point if recovery_point.is_finite() else global_position

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

func is_dashing() -> bool:
	return _dash_time > 0.0

func dash_cooldown_remaining() -> float:
	return _dash_recovery

func is_staggered() -> bool:
	return _stagger > 0.0

func guardian_stagger(seconds: float) -> bool:
	if is_dashing() or not move_enabled:
		return false
	_stagger = maxf(_stagger, seconds)
	_jump_buffer = 0.0
	clear_swing()
	return true

## Both dash actions pass through this controller's single swept physics move.
func begin_swept_dash(direction: Vector3, distance: float, duration: float, kind: StringName = &"sluice") -> bool:
	if not move_enabled or is_staggered() or is_dashing() or not is_on_floor() or duration <= 0 or distance <= 0:
		return false
	if attack_hold > 0.0 or (visual and not visual.can_cast_art()):
		return false
	var heading := direction.slide(Vector3.UP).normalized()
	if heading.is_zero_approx() or not _dash_step_clear(heading * minf(.20, distance)):
		return false
	_dash_dir = heading
	_dash_speed = distance / duration
	_dash_time = duration
	_dash_kind = kind
	_jump_buffer = 0.0
	lunge = Vector3.ZERO
	if visual:
		visual.rotation.y = atan2(-heading.x, -heading.z)
	movement_used.emit(kind)
	return true

func _dash_step_clear(step: Vector3) -> bool:
	# Short intermediate tests also cover throttled physics and long art casts.
	var count := maxi(1, ceili(step.length() / .17))
	var start := global_position
	for i in range(1, count + 1):
		var at := global_position + step * float(i) / count
		at.y = start.y
		var supported := _footing.snap(at, false, .46, .58)
		if not supported.is_finite() or absf(supported.y - start.y) > .35:
			return false
		var shape_start := global_transform
		shape_start.origin = start + Vector3.UP * .015
		var hit := KinematicCollision3D.new()
		if test_move(shape_start, supported - start, hit) and hit.get_normal().y < cos(floor_max_angle):
			return false
		start = supported
	return true

func _stop_dash() -> void:
	if is_dashing():
		velocity.x = 0.0
		velocity.z = 0.0
	_dash_time = 0.0

func configure_recovery(opening: Vector3, authored: PackedVector3Array) -> void:
	_footing.opening = opening
	_footing.authored = authored.duplicate()
	_footing.history.clear()
	_safe_now = false

func set_recovery_context(site_anchor: Vector3 = Vector3.INF) -> void:
	if _footing.camp == site_anchor:
		return
	_footing.camp = site_anchor
	_footing.history.clear()
	_safe_now = false
	_safe_time = 0.0
	if site_anchor.is_finite():
		recovery_point = site_anchor

func has_safe_footing() -> bool:
	return _safe_now and is_on_floor() and _safe_time >= .22 and not is_dashing()

func restore_position(saved: Vector3) -> void:
	if not saved.is_finite():
		saved = _footing.opening
	_footing.history.clear()
	if not _try_reposition(saved, saved):
		# Freshly instantiated static bodies may join the physics space next tick.
		_deferred_restore = saved

func _try_reposition(origin: Vector3, saved: Vector3 = Vector3.INF) -> bool:
	var place := _footing.anchor_for(origin, saved)
	if not place.is_finite():
		return false
	var from := global_position
	global_position = place
	clear_swing()
	_stop_dash()
	velocity = Vector3.ZERO
	_stagger = 0.0
	_coyote = 0.0
	_jump_buffer = 0.0
	_safe_now = false
	_safe_time = 0.0
	_safe_probe = 0.0
	_deferred_restore = Vector3.INF
	_footing.remember(place)
	recovery_point = place
	reset_physics_interpolation()
	if visual:
		visual.reset_movement_pose()
	recovered.emit(from, place)
	return true

func _track_ground(delta: float) -> void:
	if not is_on_floor() or is_dashing():
		_safe_time = 0.0
		_safe_now = false
		_safe_probe = 0.0
		return
	_safe_time += delta
	_safe_probe -= delta
	if _safe_probe > 0:
		return
	_safe_probe = .12
	var safe := _footing.snap(global_position, true)
	_safe_now = safe.is_finite()
	if not _safe_now:
		_safe_time = 0.0
	elif _safe_time >= .22:
		_footing.remember(safe)
		recovery_point = safe

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	if _deferred_restore.is_finite():
		_try_reposition(_deferred_restore, _deferred_restore)
	var direction := Vector3.ZERO
	_stagger = maxf(0.0, _stagger - delta)
	_dash_recovery = maxf(0.0, _dash_recovery - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_coyote = COYOTE_SECONDS if is_on_floor() else maxf(0.0, _coyote - delta)
	var can_move := move_enabled and not is_staggered()
	if can_move:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = camera.global_basis.x.slide(Vector3.UP).normalized() * input.x
		direction += camera.global_basis.z.slide(Vector3.UP).normalized() * input.y
		if Engine.get_physics_frames() > _input_after_frame and Input.is_action_just_pressed("sprint") and _dash_recovery <= 0.0:
			var heading := direction
			if heading.is_zero_approx() and visual:
				heading = -visual.global_basis.z
			if begin_swept_dash(heading, DASH_SPEED * DASH_SECONDS, DASH_SECONDS, &"dash"):
				_dash_recovery = DASH_COOLDOWN
		if Engine.get_physics_frames() > _input_after_frame and Input.is_action_just_pressed("jump") and not is_dashing() and attack_hold <= 0.0:
			_jump_buffer = BUFFER_SECONDS
	var speed := 6.1 if Input.is_action_pressed("sprint") else 3.65
	if Input.is_action_pressed("walk"):
		speed = 2.05
	if attack_hold > 0.0:
		_turn_into_swing(delta)
		attack_hold = maxf(0.0, attack_hold - delta)
		speed *= 0.28
	var was_grounded := is_on_floor()
	var dash_tick := is_dashing()
	var distance := _dash_speed * minf(delta, _dash_time)
	if dash_tick:
		if not can_move or not _dash_step_clear(_dash_dir * distance):
			_stop_dash()
			dash_tick = false
		else:
			velocity.x = _dash_dir.x * distance / delta
			velocity.z = _dash_dir.z * distance / delta
	else:
		var acceleration := 31.0 if was_grounded else 13.0
		velocity.x = move_toward(velocity.x, direction.x * speed, delta * acceleration)
		velocity.z = move_toward(velocity.z, direction.z * speed, delta * acceleration)
	velocity.y = maxf(-24.0, velocity.y - delta * GRAVITY)
	if _jump_buffer > 0.0 and _coyote > 0.0 and can_move and attack_hold <= 0.0 and (not visual or visual.can_cast_art()):
		velocity.y = JUMP_SPEED
		_jump_buffer = 0.0
		_coyote = 0.0
		movement_used.emit(&"jump")
	var start := global_position
	var fall_speed := velocity.y
	velocity += lunge
	move_and_slide()
	velocity -= lunge
	lunge = lunge.move_toward(Vector3.ZERO, delta * 22.0)
	if dash_tick:
		dash_segment.emit(_dash_kind, start, global_position)
		if is_on_wall() or _dash_time <= delta + .00001 or not is_on_floor():
			_stop_dash()
		else:
			_dash_time -= delta
	elif direction.length_squared() > 0.01 and attack_hold <= 0.0 and visual:
		var heading := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, heading, 1.0 - exp(-13.0 * delta))
	if visual:
		visual.movement_pose(delta, is_on_floor(), velocity.y, dash_tick, not was_grounded and is_on_floor(), fall_speed)
		visual.animate(delta, get_real_velocity().slide(Vector3.UP).length(), tactical)
	_track_ground(delta)
	if not is_on_floor() and velocity.y < 0.0 and _footing.lost_below_ground(global_position, recovery_point):
		_try_reposition(global_position)
