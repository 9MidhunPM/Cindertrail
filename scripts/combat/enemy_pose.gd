extends RefCounted
## The authored rigid pivots carry their own armor, claws and light seams.
## Stance travels backwards by the distance the actor has moved; swing is quicker and lifts the foot.
var _hips: Array[Node3D] = []
var _hips_rest: Array[Transform3D] = []
var _sides := PackedFloat32Array()
var _offsets := PackedFloat32Array()
var _arms: Array[Node3D] = []
var _fan: Array[Node3D] = []
var _bell: Array[Node3D] = []
var _head: Node3D
var _joint_rest: Dictionary[Node3D, Vector3] = {}
var _action := 0.0
var _wet := 0.0

func bind(model: Node3D) -> void:
	for row in 4:
		for side in ["L", "R"]:
			var leg := model.find_child("Hip_%s%d" % [side, row], true, false) as Node3D
			if leg:
				_hips.append(leg)
				_hips_rest.append(leg.transform)
				_sides.append(-1.0 if side == "L" else 1.0)
				_offsets.append(fmod(row * 0.49 + (0.5 if side == "L" else 0.0), 1.0))
	for side in ["L", "R"]:
		_collect(model, "Shoulder_" + side, _arms)
		_collect(model, "Fan_" + side, _fan)
		_collect(model, "Bell_" + side, _bell)
	_head = model.find_child("HeadPivot", true, false) as Node3D
	if _head:
		_joint_rest[_head] = _head.rotation

func _collect(model: Node3D, label: String, into: Array[Node3D]) -> void:
	var joint := model.find_child(label, true, false) as Node3D
	if joint:
		into.append(joint)
		_joint_rest[joint] = joint.rotation

func advance(body: CinderEnemy, delta: float, thrust: float, hit: float) -> void:
	var species := body.stats.species
	var opening := body.technique.opening() if body.technique else 0.0
	_action = lerpf(_action, opening, 1.0 - exp(-12.0 * delta))
	var water := 1.0 if body.technique and body.technique.in_water else 0.0
	_wet = lerpf(_wet, water, 1.0 - exp(-5.0 * delta))
	var clock := body.stride / TAU
	var cycle_length := TAU / body.stats.stride_frequency
	for i in _hips.size():
		var offset := _offsets[i]
		if species == &"quarry_ram":
			# Front hooves and hind hooves pair up during the gallop.
			offset = lerpf(offset, (0.12 if _sides[i] < 0.0 else 0.0) + floorf(i / 2.0) * 0.5, _action)
		var phase := fposmod(clock + offset, 1.0)
		var stance := phase < 0.60
		var pass_time := clampf((phase - 0.60) / 0.40, 0.0, 1.0)
		var sweep := 0.30 - phase if stance else lerpf(-0.30, 0.30, smoothstep(0.0, 1.0, pass_time))
		var lift := sin(PI * pass_time) if not stance else 0.0
		var walk := body.gait_weight
		var hinge := _hips[i]
		var rest := _hips_rest[i]
		var travel := sweep * cycle_length * walk / body.stats.model_scale
		var step_height := 0.09 if species == &"crawler" else 0.14
		hinge.position = rest.origin + Vector3(_wet * _sides[i] * lift * 0.1, lift * walk * step_height, travel * 0.48)
		var rot := rest.basis.get_euler()
		if species in [&"crawler", &"ford_skimmer", &"splinterback"]:
			rot.y += _sides[i] * sweep * walk * (1.18 + _wet * 0.6)
			rot.z += _sides[i] * (lift * 0.24 * walk + body.windup * 0.15 - thrust * 0.23)
		else:
			rot.x += travel * (1.0 if species == &"brute" else 1.45)
			rot.z += _sides[i] * (_action * 0.08 + lift * 0.07 * walk)
		hinge.rotation = rot
	for i in _arms.size():
		var shoulder := _arms[i]
		var side := -1.0 if i == 0 else 1.0
		var swing := sin(body.stride) * side * body.gait_weight
		shoulder.rotation = _joint_rest[shoulder] + Vector3(swing * .27 + body.windup * (0.42 if i == 0 else .9) - thrust * (0.77 if i == 0 else 1.26),0.0, side * absf(swing) * 0.1)
	var lowered := -_action * 0.42 if species == &"quarry_ram" else _action * 0.12
	if _head:
		_head.rotation = _joint_rest[_head] + Vector3(lowered + sin(body.breath) * .027 - thrust * .16 + hit * .14, sin(body.stride) * .043 * body.gait_weight, hit * .08)
	for i in _fan.size():
		var side := -1.0 if i == 0 else 1.0
		var panel := _fan[i]
		panel.rotation = _joint_rest[panel] + Vector3(-_action * .23, side * _action * .20, side * (_action * .83 + _wet * (.17 + .11 * sin(body.stride)) + .045 * sin(body.breath)))
	for i in _bell.size():
		var side := -1.0 if i == 0 else 1.0
		var rib := _bell[i]
		rib.rotation = _joint_rest[rib] + Vector3(.04 * sin(body.breath), side * _action * .28, side * _action * .78)

func collapse(tween: Tween, species: StringName) -> void:
	var insect := species in [&"crawler", &"ford_skimmer", &"splinterback"]
	for i in _hips.size():
		var hinge := _hips[i]
		var target := hinge.rotation + Vector3(-0.28 if insect else 0.64, _sides[i] * 0.16, _sides[i] * (-0.74 if insect else 0.26))
		tween.tween_property(hinge, "rotation", target, 0.22)
	for shoulder in _arms:
		tween.tween_property(shoulder, "rotation:x", shoulder.rotation.x - 0.70, 0.24)
	for panel in _fan:
		tween.tween_property(panel, "rotation:x", panel.rotation.x + 0.68, 0.24)
