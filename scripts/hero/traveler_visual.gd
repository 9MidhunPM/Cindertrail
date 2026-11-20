class_name TravelerVisual
extends Node3D

signal footfall(running: bool)

const THIGH_LENGTH := 0.395
const SHIN_LENGTH := 0.355
const GESTURE_LENGTH := {
	&"deploy": 1.05, &"pack": 1.05, &"fire": 0.30,
	&"hurt": 0.47, &"collect": 0.64, &"deliver": 1.65,
}

@onready var carry_anchor: Node3D = $CarryAnchor
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

func _ready() -> void:
	for side in ["L", "R"]:
		_thighs.append(_joint("Leg" + side))
		_knees.append(_joint("Knee" + side))
		_feet.append(_joint("Foot" + side))
		_arms.append(_joint("Arm" + side))
		_elbows.append(_joint("Elbow" + side))
		_tails.append(_joint("Tail" + side))
	_rest_y = _pelvis.position.y
	carry_anchor.reparent(_body, true)
	_last_heading = rotation.y
	animate(0.0, 0.0, false)

func _joint(joint_name: String) -> Node3D:
	return $Traveler.find_child(joint_name, true, false) as Node3D

func gesture(action: StringName) -> void:
	if GESTURE_LENGTH.has(action):
		_action = action
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
	var y := _rest_y - 0.053 - _guard * 0.031 - _crouch
	y += (-0.061 + rise * lerpf(0.036, 0.084, run)) * _stride + breath * 0.004
	_pelvis.position.y = y

	_body.rotation = Vector3(
		-0.025 - _stride * (0.075 + run * 0.13) - _crouch * 1.6 + _recoil + _flinch * 0.5,
		-swing * (0.070 + run * 0.060) - _turn * 0.10 + _flinch,
		sin(angle) * _stride * 0.035 + _turn * _stride * 0.14 - _flinch * 0.5)
	_head.rotation = Vector3(
		-_body.rotation.x * 0.57 + breath * 0.013 + _crouch * 0.65,
		_turn_head(swing), -_body.rotation.z * 0.62)
	for i in range(2):
		var phase := fposmod(_phase + i * 0.5, 1.0)
		_place_foot(i, phase, run, stance, cycle_length)
		var side := -1.0 if i == 0 else 1.0
		var arm_swing := side * swing
		var reach := _reach[i]
		_arms[i].rotation = Vector3(
			0.05 + arm_swing * lerpf(0.43, 0.80, run) + reach,
			-side * (0.06 + reach * 0.18),
			side * (0.12 + _stride * 0.045 + reach * 0.10))
		_elbows[i].rotation.x = 0.24 + breath * 0.018 + _guard * 0.12
		_elbows[i].rotation.x += _stride * (0.10 + run * 0.62) + arm_swing * 0.14 - reach * 0.16
		var trailing := sin(TAU * phase - 0.7)
		var tail_target := Vector3(
			-_stride * (0.17 + run * 0.34 + trailing * 0.16) - _crouch * 0.9,
			side * _stride * (0.09 + run * 0.06) - _turn * 0.17,
			side * (0.03 + _stride * 0.09) - _turn * 0.17 + sin(_time * 2.1 + i) * 0.027)
		_tails[i].rotation = _tails[i].rotation.lerp(tail_target, 1.0 - exp(-8.0 * delta))
	var coat_target := Vector3(-0.032 - _stride * (0.08 + run * 0.13),
		swing * 0.085 - _turn * 0.13, -sin(angle - 0.3) * _stride * 0.054 - _turn * 0.12)
	_coat.rotation = _coat.rotation.lerp(coat_target, 1.0 - exp(-9.0 * delta))

func _turn_head(swing: float) -> float:
	var glance := sin(_time * 0.66) * (1.0 - _stride) * 0.056
	return swing * 0.048 + _turn * 0.17 + glance - _flinch * 0.8

func _place_foot(i: int, phase: float, run: float, stance: float, cycle_length: float) -> void:
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
	# The ankle rises as the heel rolls up, keeping the toe at floor level.
	var ankle_y := 0.090 + lift * _stride + absf(sin(roll)) * (0.14 if roll < 0.0 else 0.065)
	var drop := _pelvis.position.y - ankle_y
	var distance := clampf(Vector2(forward, drop).length(), 0.12, THIGH_LENGTH + SHIN_LENGTH - 0.001)
	var hip_cos := (THIGH_LENGTH ** 2 + distance ** 2 - SHIN_LENGTH ** 2) / (2.0 * THIGH_LENGTH * distance)
	var knee_cos := (THIGH_LENGTH ** 2 + SHIN_LENGTH ** 2 - distance ** 2) / (2.0 * THIGH_LENGTH * SHIN_LENGTH)
	var thigh_angle := atan2(forward, drop) + acos(clampf(hip_cos, -1.0, 1.0))
	var shin_angle := acos(clampf(knee_cos, -1.0, 1.0)) - PI
	_thighs[i].rotation.x = thigh_angle
	_knees[i].rotation.x = shin_angle
	_feet[i].rotation.x = roll - thigh_angle - shin_angle
