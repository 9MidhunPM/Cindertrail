class_name TravelerVisual
extends Node3D

signal footfall(running: bool)
## Emitted at the contact frame of a melee swing.
signal strike(index: int)

const THIGH_LENGTH := 0.395
const SHIN_LENGTH := 0.355
const GESTURE_LENGTH := {
	&"deploy": 1.05, &"pack": 1.05, &"fire": 0.30,
	&"hurt": 0.47, &"collect": 0.64, &"deliver": 1.65, &"sheathe": 0.55,
	&"flooded_grove": .48, &"broken_quarry": .55, &"fallen_relay": .32,
	&"lanternwood": .7, &"sunken_aqueduct": .38, &"sunwatch": .51,
	&"last_lantern_frontier": .47,
}
const ATTACKS := preload("res://scripts/hero/traveler_attacks.gd")
const SHEATHE_DELAY := 3.2

@onready var carry_anchor: Node3D = $CarryAnchor
@onready var _rig: Node3D = $Traveler
@onready var _pelvis := _joint("Pelvis")
@onready var _body := _joint("UpperBody")
@onready var _head := _joint("Hood")
@onready var _coat := _joint("CoatHem")

var _thighs: Array[Node3D]
var _knees: Array[Node3D]
var _feet: Array[Node3D]
var _arms: Array[Node3D]
var _elbows: Array[Node3D]
var _tails: Array[Node3D]
var _phase := 0.0
var _time := 0.0
var _speed := 0.0
var _stride := 0.0
var _guard := 0.0
var _last_heading := 0.0
var _turn := 0.0
var _rest_y := 0.84
var _action: StringName
var _age := 0.0
var _duration := 0.0
var _reach := Vector2.ZERO
var _crouch := 0.0
var _recoil := 0.0
var _flinch := 0.0
var _hands: Array[Node3D]
var _mantles: Array[Node3D]
var _skirts: Array[Node3D]
var _weapon: Node3D
var _sheath: Node3D
var _grip: Transform3D
var _ember: StandardMaterial3D
var drawn := false
var _attack := -1
var _attack_age := 0.0
var _charge := 0.0
var _struck := false
var _attack_weight := 0.0
var _guard_weight := 0.0
var _idle_armed := 0.0
var _hop := 0.0
var _grip_target: Node3D
var _carrier: CharacterBody3D
var _ground_offset := Vector2.ZERO
var _slope_tilt := Vector2.ZERO
var _brake := 0.0
var _prior_speed := 0.0
var _turn_plant: Array[Vector3] = [Vector3.INF, Vector3.INF]

func _ready() -> void:
	_carrier = get_parent() as CharacterBody3D
	for side in ["L", "R"]:
		_thighs.append(_joint("Leg" + side))
		_knees.append(_joint("Knee" + side))
		_feet.append(_joint("Foot" + side))
		_arms.append(_joint("Arm" + side))
		_elbows.append(_joint("Elbow" + side))
		_tails.append(_joint("Tail" + side))
		_hands.append(_joint("Hand" + side))
		_mantles.append(_joint("Mantle" + side))
		_skirts.append(_joint("Skirt" + side))
	_weapon = _joint("Weapon")
	_sheath = _joint("Sheath")
	_grip = _weapon.transform
	_ember = _own_ember()
	_set_drawn(false)
	_rest_y = _pelvis.position.y
	carry_anchor.reparent(_body, true)
	_last_heading = rotation.y
	animate(0.0, 0.0, false)

func _joint(joint_name: String) -> Node3D:
	return $Traveler.find_child(joint_name, true, false) as Node3D

func _own_ember() -> StandardMaterial3D:
	var blade := _weapon.find_child("*Geometry", true, false) as MeshInstance3D
	if blade == null:
		return null
	for surface in blade.mesh.get_surface_count():
		var source := blade.mesh.surface_get_material(surface) as StandardMaterial3D
		if source != null and source.emission_enabled:
			var unique := source.duplicate() as StandardMaterial3D
			blade.set_surface_override_material(surface, unique)
			return unique
	return null

func _set_drawn(value: bool) -> void:
	drawn = value
	var holder := _hands[1] if value else _sheath
	if _weapon.get_parent() != holder:
		_weapon.reparent(holder, false)
	_weapon.transform = _grip if value else Transform3D.IDENTITY

## Begin a melee swing. Returns false while another swing is still committed.
func attack(index: int) -> bool:
	if _attack >= 0 and _attack_age < ATTACKS.cancel_at(_attack):
		return false
	if not drawn:
		_set_drawn(true)
	_attack = index
	_attack_age = 0.0
	_struck = false
	_idle_armed = 0.0
	_charge = 0.0
	_interrupt_sheathe()
	return true

func _interrupt_sheathe() -> void:
	if _action == &"sheathe":
		_action = &""
		_age = _duration

func set_charge(amount: float) -> void:
	_charge = clampf(amount, 0.0, 1.0)
	if _charge > 0.0:
		_idle_armed = 0.0
		_interrupt_sheathe()
		if not drawn:
			_set_drawn(true)

func cancel_attack() -> void:
	_attack = -1
	_charge = 0.0
	_attack_age = 0.0
	_rig.rotation.y = 0.0
	_attack_weight = 0.0
	_hop = 0.0

func attack_age() -> float:
	return _attack_age

func trailing() -> bool:
	if _attack < 0:
		return false
	var window: Vector2 = ATTACKS.TRAIL_WINDOWS[_attack]
	return _attack_age >= window.x and _attack_age <= window.y

func attacking() -> bool:
	return _attack >= 0

func can_cast_art() -> bool:
	return _attack < 0 and _charge <= 0.0

## World-space base and tip of the blade, used by the swing trail.
func blade_segment() -> PackedVector3Array:
	var basis := _weapon.global_basis
	return PackedVector3Array([_weapon.global_position - basis.z * 0.09, _weapon.global_position - basis.z * 0.57])

func gesture(action: StringName, target: Node3D = null) -> void:
	if GESTURE_LENGTH.has(action):
		_grip_target = target.get_node_or_null("Visual/SunCenter") as Node3D if is_instance_valid(target) else null
		_action = action
		_idle_armed = 0.0
		_age = 0.0
		_duration = GESTURE_LENGTH[action]

func _update_gesture(delta: float) -> void:
	_age += delta
	var weight := 0.0
	if _age < _duration:
		var t := _age / _duration
		weight = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.49, 1.0, t))
	var reach := Vector2.ZERO
	var dip := 0.0
	var recoil := 0.0
	var flinch := 0.0
	match _action:
		&"deploy":
			reach = Vector2(0.84, 0.99)
			dip = 0.20
		&"pack":
			reach = Vector2(0.64, 1.10)
			dip = 0.16
		&"fire":
			reach = Vector2(0.31, 1.33)
			recoil = 0.13
		&"hurt":
			flinch = 0.24
			reach = Vector2(0.43, 0.1)
			dip = 0.07
		&"collect":
			reach = Vector2(0.12, 0.83)
			dip = 0.18
		&"deliver":
			reach = Vector2(1.22, 1.31)
			dip = 0.065
		&"flooded_grove":
			reach = Vector2(.82,.45)
			dip = .17
		&"broken_quarry":
			reach = Vector2(-.32,1.18)
			dip = .22
			recoil = .16
		&"fallen_relay":
			reach = Vector2(1.52,-.19)
			recoil = .14
		&"lanternwood":
			reach = Vector2(1.18,1.08)
			dip = .07
		&"sunken_aqueduct":
			reach = Vector2(.38,-.49)
			dip = .15
		&"sunwatch":
			reach = Vector2(1.58,.48)
		&"last_lantern_frontier":
			reach = Vector2(-.26,1.36)
			recoil = .09
		&"sheathe":
			reach = Vector2(0.0, -0.55)
			if _age >= _duration * 0.45 and drawn:
				_set_drawn(false)
	var blend := 1.0 - exp(-22.0 * delta)
	_reach = _reach.lerp(reach * weight, blend)
	_crouch = lerpf(_crouch, dip * weight, blend)
	_recoil = lerpf(_recoil, recoil * weight, blend)
	_flinch = lerpf(_flinch, flinch * weight, blend)

func animate(delta: float, speed: float, tactical: bool) -> void:
	_time += delta
	var blend := 1.0 - exp(-12.0 * delta)
	_speed = lerpf(_speed, speed, blend)
	_stride = lerpf(_stride, smoothstep(0.06, 1.25, speed), blend)
	_guard = lerpf(_guard, float(tactical), blend)
	var yaw_rate := wrapf(rotation.y - _last_heading, -PI, PI) / maxf(delta, 0.001)
	_last_heading = rotation.y
	_turn = lerpf(_turn, clampf(yaw_rate * 0.13, -1.0, 1.0), blend)
	_update_gesture(delta)
	var pose := _advance_attack(delta)

	var decel := clampf((_prior_speed - speed) / maxf(delta, 0.001) / 22.0, 0.0, 1.0)
	_brake = lerpf(_brake, decel, 1.0 - exp(-delta * (16.0 if decel > _brake else 5.2)))
	_prior_speed = speed
	var run := smoothstep(2.05, 6.1, _speed)
	var cycle_length := lerpf(1.50, 3.10, run)
	var stance := lerpf(0.795, 0.83, run) / cycle_length
	var previous_step := floori(_phase * 2.0)
	_phase += speed * delta / cycle_length
	if floori(_phase * 2.0) != previous_step and _stride > 0.38:
		footfall.emit(run > 0.50)
	_phase = fposmod(_phase, 1.0)
	var angle := _phase * TAU
	var swing := cos(angle) * _stride
	var rise := (1.0 - cos(2.0 * angle - 0.50)) * 0.5
	var breath := sin(_time * 1.85)
	var y := _rest_y - 0.053 - _guard * 0.031 - _crouch - _brake * 0.047
	y += (-0.061 + rise * lerpf(0.036, 0.084, run)) * _stride + breath * 0.004
	_pelvis.position.y = y - float(pose.get("crouch", 0.0)) * _attack_weight

	_body.rotation = Vector3(
		-0.025 - _stride * (0.075 + run * 0.13) - _crouch * 1.6 + _brake * 0.15 + _recoil + _flinch * 0.5,
		-swing * (0.070 + run * 0.060) - _turn * 0.10 + _flinch,
		sin(angle) * _stride * 0.035 + _turn * _stride * 0.14 - _flinch * 0.5)
	_head.rotation = Vector3(
		-_body.rotation.x * 0.57 + breath * 0.013 + _crouch * 0.65,
		_turn_head(swing), -_body.rotation.z * 0.62)
	for i in range(2):
		var phase := fposmod(_phase + i * 0.5, 1.0)
		_place_foot(i, phase, run, stance, cycle_length, delta)
		var side := -1.0 if i == 0 else 1.0
		var arm_swing := side * swing
		var reach := _reach[i]
		_arms[i].rotation = Vector3(
			0.05 + arm_swing * lerpf(0.43, 0.80, run) + reach,
			-side * (0.06 + reach * 0.18),
			side * (0.12 + _stride * 0.045 + reach * 0.10))
		_elbows[i].rotation = Vector3(0.24 + breath * 0.018 + _guard * 0.12, 0.0, 0.0)
		_elbows[i].rotation.x += _stride * (0.10 + run * 0.62) + arm_swing * 0.14 - reach * 0.16
		var trailing := sin(TAU * phase - 0.7)
		var tail_target := Vector3(
			-_stride * (0.17 + run * 0.34 + trailing * 0.16) - _crouch * 0.9 + _brake * 0.32,
			side * _stride * (0.09 + run * 0.06) - _turn * 0.17,
			side * (0.03 + _stride * 0.09) - _turn * 0.17 + sin(_time * 2.1 + i) * 0.027)
		_tails[i].rotation = _tails[i].rotation.lerp(tail_target, 1.0 - exp(-8.0 * delta))
	var coat_target := Vector3(-0.032 - _stride * (0.08 + run * 0.13),
		swing * 0.085 - _turn * 0.13, -sin(angle - 0.3) * _stride * 0.054 - _turn * 0.12)
	_coat.rotation = _coat.rotation.lerp(coat_target, 1.0 - exp(-9.0 * delta))
	_pelvis.position.y += _hop
	_combat(delta, run, pose)
	_grip_shrine()
	if _attack == 2:
		var support := smoothstep(0.03, 0.13, _attack_age) * (1.0 - smoothstep(0.48, 0.70, _attack_age))
		_reach_hand(0, _weapon.global_position + _weapon.global_basis.z * 0.052, support)
	_secondary(delta)
	if _attack >= 0 and not _struck and _attack_age >= ATTACKS.impact(_attack):
		_struck = true
		strike.emit(_attack)

## Follow the moving shrine with both wrists while the frame stays in reach.
## The shoulder and elbow aim solve has no authority over the shrine's motion.
func _grip_shrine() -> void:
	if not is_instance_valid(_grip_target) or _age >= _duration or _attack >= 0:
		return
	var progress := _age / _duration
	var grip := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.62, 0.94, progress))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var target := _grip_target.global_position + global_basis * Vector3(side * 0.12, 0.085, 0.0)
		_reach_hand(i, target, grip)

func _reach_hand(i: int, target: Vector3, weight: float) -> void:
	var arm := _arms[i]
	var elbow := _elbows[i]
	var hand := _hands[i]
	var offset := target - arm.global_position
	var length_a := elbow.position.length()
	var length_b := hand.position.length()
	var distance := clampf(offset.length(), 0.07, length_a + length_b - 0.001)
	var direction := offset.normalized()
	if direction.is_zero_approx():
		return
	var side := -1.0 if i == 0 else 1.0
	var pole := (global_basis * Vector3(side, -0.52, 0.12)).slide(direction).normalized()
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var elbow_target := arm.global_position + direction * along + pole * sqrt(maxf(0, length_a * length_a - along * along))
	_aim_link(arm, elbow, elbow_target, weight)
	_aim_link(elbow, hand, target, weight)

func _aim_link(joint: Node3D, end: Node3D, target: Vector3, weight: float) -> void:
	var inverse := joint.global_basis.orthonormalized().inverse()
	var current := (inverse * (end.global_position - joint.global_position)).normalized()
	var desired := (inverse * (target - joint.global_position)).normalized()
	if current.length_squared() > 0.99 and desired.length_squared() > 0.99:
		joint.quaternion = joint.quaternion * Quaternion.IDENTITY.slerp(Quaternion(current, desired), weight)

## Capelet flaps lift with the arms and the split coat panels follow the thighs.
func _secondary(delta: float) -> void:
	var follow := 1.0 - exp(-14.0 * delta)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var lift := Vector3(clampf(_arms[i].rotation.x * 0.34, -0.25, 0.95), 0.0,
			clampf(_arms[i].rotation.z * 0.45, -0.2, 0.7) if side > 0.0 else clampf(_arms[i].rotation.z * 0.45, -0.7, 0.2))
		_mantles[i].rotation = _mantles[i].rotation.lerp(lift, follow)
		var thigh := _thighs[i].rotation.x
		var panel := Vector3(clampf(thigh * 0.62 - _body.rotation.x * 0.25, -0.12, 0.95), 0.0, side * 0.02)
		_skirts[i].rotation = _skirts[i].rotation.lerp(panel, follow)

func _advance_attack(delta: float) -> Dictionary:
	var pose: Dictionary = {}
	if _attack >= 0:
		_attack_age += delta
		var length: float = ATTACKS.length(_attack)
		if _attack_age >= length:
			_attack = -1
		else:
			pose = ATTACKS.sample(_attack, _attack_age)
	var target_weight := 1.0 if _attack >= 0 else _charge
	if _attack < 0 and _charge > 0.0:
		pose = ATTACKS.WIND_UP
	_attack_weight = move_toward(_attack_weight, target_weight, delta * (14.0 if target_weight > 0.0 else 6.0))
	_rig.rotation.y = TAU * ATTACKS.SPIN_TURN_SIGN * ATTACKS.spin_progress(_attack_age) if _attack == ATTACKS.SPIN else 0.0
	_hop = float(pose.get("hop", 0.0)) * _attack_weight
	_pelvis.rotation.y = lerpf(_pelvis.rotation.y, float(pose.get("hips", 0.0)) * _attack_weight, 1.0 - exp(-24.0 * delta))
	return pose

func _combat(delta: float, run: float, pose: Dictionary) -> void:
	_guard_weight = lerpf(_guard_weight, float(drawn and _attack < 0) * (1.0 - run * 0.7), 1.0 - exp(-8.0 * delta))
	if drawn and _attack < 0 and _charge <= 0.0:
		_idle_armed += delta
		if _idle_armed > SHEATHE_DELAY and _action != &"sheathe":
			gesture(&"sheathe")
	if _ember:
		var heat := 1.4 + 5.0 * _attack_weight + (0.0 if pose.is_empty() else float(pose.get("heat", 0.0)) * 6.0)
		if _charge >= 1.0:
			heat += 2.4 + 1.6 * sin(_time * TAU * 2.0)
		_ember.emission_energy_multiplier = lerpf(_ember.emission_energy_multiplier, heat, 1.0 - exp(-20.0 * delta))
	if pose.is_empty():
		pose = ATTACKS.guard(run)
	var w := maxf(_attack_weight, _guard_weight)
	if w <= 0.001:
		_hands[1].rotation = _hands[1].rotation.lerp(Vector3.ZERO, 1.0 - exp(-10.0 * delta))
		return
	var aw := _attack_weight
	_body.rotation += (pose.get("body", Vector3.ZERO) as Vector3) * aw
	_head.rotation += (pose.get("head", Vector3.ZERO) as Vector3) * aw
	_arms[1].rotation = _arms[1].rotation.lerp(pose.get("arm_r", _arms[1].rotation), w)
	_elbows[1].rotation.x = lerpf(_elbows[1].rotation.x, float(pose.get("elbow_r", _elbows[1].rotation.x)), w)
	if pose.has("arm_l"):
		var lw := aw if _attack >= 0 else w * 0.6
		_arms[0].rotation = _arms[0].rotation.lerp(pose.arm_l, lw)
		_elbows[0].rotation.x = lerpf(_elbows[0].rotation.x, float(pose.get("elbow_l", 0.4)), lw)
	_aim_blade(pose.get("blade", Vector3.FORWARD), w)

## Rotate the sword hand so the blade points along a direction in the traveler's frame.
func _aim_blade(direction: Vector3, weight: float) -> void:
	var hand := _hands[1]
	var parent_basis := (hand.get_parent() as Node3D).global_basis.orthonormalized()
	var world_dir := (_rig.global_basis * direction).normalized()
	var flat_side := _rig.global_basis.x if absf(world_dir.dot(global_basis.y)) > 0.9 else global_basis.y
	var desired := Basis.looking_at(world_dir, flat_side)
	var local := (parent_basis.inverse() * desired).get_rotation_quaternion()
	var current := Quaternion.from_euler(hand.rotation)
	hand.quaternion = current.slerp(local, clampf(weight, 0.0, 1.0))

func _turn_head(swing: float) -> float:
	var glance := sin(_time * 0.66) * (1.0 - _stride) * 0.056
	return swing * 0.048 + _turn * 0.17 + glance - _flinch * 0.8

func _place_foot(i: int, phase: float, run: float, stance: float, cycle_length: float, delta: float) -> void:
	# During support the ankle moves backward at exactly the ground speed.
	# The swing curve matches that velocity at toe-off and at the next contact.
	var travel := cycle_length * stance
	var forward: float
	var lift := 0.0
	var roll: float
	if phase < stance:
		var t := phase / stance
		forward = travel * (0.5 - t)
		roll = 0.20 * (1.0 - smoothstep(0.0, 0.28, t)) - 0.37 * smoothstep(0.53, 1.0, t)
	else:
		var t := (phase - stance) / (1.0 - stance)
		var overshoot := cycle_length * (1.0 - stance) * t * (1.0 - t) * (1.0 - 2.0 * t)
		forward = travel * (smoothstep(0.0, 1.0, t) - 0.5) - overshoot
		lift = sin(PI * t) * sin(PI * t) * lerpf(0.18, 0.39, run) * (1.35 - 0.70 * t)
		roll = lerpf(-0.37, 0.20, smoothstep(0.12, 0.92, t)) - sin(PI * t) * run * 0.28
	forward *= _stride
	roll *= _stride
	var side := -1.0 if i == 0 else 1.0
	lift *= _stride
	# Opposite lead feet sell the crossing cuts. The free leg tucks on the pivot.
	if _attack == 0 or _attack == 1:
		var beat := sin(PI * _attack_age / ATTACKS.length(_attack))
		var lead := side if _attack == 1 else -side
		forward += lead * 0.15 * beat
		lift += maxf(lead, 0.0) * sin(PI * minf(1.0, _attack_age / ATTACKS.impact(_attack))) * 0.065
	elif _attack == ATTACKS.SPIN:
		var pivot := sin(PI * ATTACKS.spin_progress(_attack_age))
		forward -= side * 0.16 * pivot
		lift += maxf(side, 0.0) * pivot * 0.175
	elif _attack == 2:
		lift += _hop * (0.28 if i == 0 else 0.50)
	var local_step := Vector3(side * 0.124, 0.0, -forward)
	# Keep the support leg under the same patch of ground through a turn.
	var planted := _stride > 0.35 and phase < stance and absf(_turn) > 0.14
	if planted:
		if _turn_plant[i] == Vector3.INF:
			_turn_plant[i] = to_global(local_step)
		var pivot := to_local(_turn_plant[i])
		forward = lerpf(forward, clampf(-pivot.z, forward - 0.12, forward + 0.12), absf(_turn))
		local_step.z = -forward
		_thighs[i].rotation.z = clampf((pivot.x - local_step.x) * 1.35, -0.16, 0.16)
	else:
		_turn_plant[i] = Vector3.INF
		_thighs[i].rotation.z = lerpf(_thighs[i].rotation.z, 0.0, 1.0 - exp(-18.0 * delta))
	_sample_ground(i, local_step, delta)
	roll += _slope_tilt[i] * (1.0 - 0.8 * smoothstep(0.0, 0.22, lift))
	# The ankle rises as the heel rolls up, keeping the toe at floor level.
	var ankle_y := 0.090 + lift + absf(sin(roll)) * (0.14 if roll < 0.0 else 0.065)
	var drop := _pelvis.position.y - ankle_y - _ground_offset[i]
	var distance := clampf(Vector2(forward, drop).length(), 0.12, THIGH_LENGTH + SHIN_LENGTH - 0.001)
	var hip_cos := (THIGH_LENGTH ** 2 + distance ** 2 - SHIN_LENGTH ** 2) / (2.0 * THIGH_LENGTH * distance)
	var knee_cos := (THIGH_LENGTH ** 2 + SHIN_LENGTH ** 2 - distance ** 2) / (2.0 * THIGH_LENGTH * SHIN_LENGTH)
	var thigh_angle := atan2(forward, drop) + acos(clampf(hip_cos, -1.0, 1.0))
	var shin_angle := acos(clampf(knee_cos, -1.0, 1.0)) - PI
	_thighs[i].rotation.x = thigh_angle
	_knees[i].rotation.x = shin_angle
	_feet[i].rotation.x = roll - thigh_angle - shin_angle


func _sample_ground(i: int, local_step: Vector3, delta: float) -> void:
	var offset := 0.0
	var tilt := 0.0
	if is_instance_valid(_carrier) and _carrier.is_on_floor() and Engine.is_in_physics_frame():
		var at := to_global(local_step)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.29, at + Vector3.DOWN * 0.34, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			offset = clampf((hit.position as Vector3).y - global_position.y, -0.18, 0.18)
			var normal := global_basis.inverse() * (hit.normal as Vector3)
			tilt = clampf(atan2(normal.z, normal.y), -0.48, 0.48)
	var blend := 1.0 - exp(-delta * 20.0)
	_ground_offset[i] = lerpf(_ground_offset[i], offset, blend)
	_slope_tilt[i] = lerpf(_slope_tilt[i], tilt, blend)
