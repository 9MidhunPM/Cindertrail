class_name TravelerVisual
extends Node3D

@onready var carry_anchor: Node3D = $CarryAnchor
@onready var _body: Node3D = $Traveler.find_child("UpperBody", true, false)
@onready var _coat: Node3D = $Traveler.find_child("CoatHem", true, false)
@onready var _left_leg: Node3D = $Traveler.find_child("LegL", true, false)
@onready var _right_leg: Node3D = $Traveler.find_child("LegR", true, false)
@onready var _left_arm: Node3D = $Traveler.find_child("ArmL", true, false)
@onready var _right_arm: Node3D = $Traveler.find_child("ArmR", true, false)
var _phase := 0.0
var _time := 0.0
var _stride := 0.0
var _body_height: float

func _ready() -> void:
	_body_height = _body.position.y

func animate(delta: float, speed: float, tactical: bool) -> void:
	_time += delta
	_stride = move_toward(_stride, 0.0 if tactical else clampf(speed / 4.6, 0.0, 1.25), delta * 5.0)
	_phase += delta * (4.0 + _stride * 6.5)
	var step := sin(_phase) * _stride
	var lift := absf(cos(_phase)) * .043 * _stride + sin(_time * 1.8) * .006
	_left_leg.rotation.x = step * .6
	_right_leg.rotation.x = -step * .6
	_left_arm.rotation.x = -.11 - step * .36
	_right_arm.rotation.x = -.08 + step * .36
	_body.position.y = _body_height + lift
	_body.rotation.z = sin(_phase) * .035 * _stride
	_coat.rotation.x = -.035 - _stride * .09 + sin(_phase + .5) * .025 * _stride
	_coat.rotation.z = cos(_phase) * .05 * _stride
	carry_anchor.position.y = .84 + lift
	carry_anchor.rotation.z = _body.rotation.z
