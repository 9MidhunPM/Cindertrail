extends SceneTree
## godot --headless --fixed-fps 60 --script tests/traveler_motion.gd

const TRAVELER := preload("res://scenes/player/traveler_visual.tscn")
const SHRINE := preload("res://scenes/core/sun_core.tscn")
const DT := 1.0 / 120.0

var failures := 0
var steps := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)

func _run() -> void:
	var traveler := TRAVELER.instantiate() as TravelerVisual
	root.add_child(traveler)
	traveler.footfall.connect(func(_running: bool): steps += 1)
	var foot := traveler.find_child("FootL", true, false) as Node3D
	var shoulder := traveler.find_child("ArmR", true, false) as Node3D
	if foot == null or shoulder == null:
		push_error("Traveler import is missing its articulated joints")
		quit(1)
		return
	var last_lift := 0.0
	for speed: float in [2.05, 3.65, 6.1]:
		for frame in 360:
			traveler.animate(DT, speed, true)
		var low := INF
		var high := -INF
		var planted := 0
		var longest_plant := 0
		var last_position := foot.global_position
		var initial_steps := steps
		for frame in 240:
			traveler.position.z -= speed * DT
			traveler.animate(DT, speed, true)
			var ankle := foot.global_position
			if ankle.y < 0.15 and absf(ankle.z - last_position.z) < 0.002:
				planted += 1
			else:
				planted = 0
			longest_plant = maxi(longest_plant, planted)
			low = minf(low, ankle.y)
			high = maxf(high, ankle.y)
			last_position = ankle
		var lift := high - low
		_check(longest_plant * DT >= 0.07 and steps - initial_steps >= 5 and lift > last_lift + 0.05,
			"%.2f m/s, tactical locomotion: %.3fs of continuous ground contact, %.3fm ankle lift, %d footfalls in two seconds" %
			[speed, longest_plant * DT, lift, steps - initial_steps])
		last_lift = lift
	for frame in 240:
		traveler.animate(DT, 0, false)
	for action: StringName in [&"deploy", &"pack", &"fire", &"hurt", &"collect", &"deliver"]:
		var rest_angle := shoulder.rotation.x
		var maximum := 0.0
		traveler.gesture(action)
		for frame in 300:
			traveler.animate(DT, 0.0, false)
			maximum = maxf(maximum, absf(shoulder.rotation.x - rest_angle))
		_check(maximum > 0.065 and absf(shoulder.rotation.x - rest_angle) < 0.015,
			"%s moves the shoulder and settles into idle" % action)
	var anchor := Node3D.new()
	var core := SHRINE.instantiate() as SunCore
	root.add_child(anchor)
	root.add_child(core)
	core.transfer(traveler.carry_anchor, SunCore.Form.CARRIED)
	var sun := core.get_node("Visual/SunCenter").find_children("Sun*", "MeshInstance3D", false, false)[0]
	var sun_id := sun.get_instance_id()
	for form in [SunCore.Form.DEPLOYED, SunCore.Form.CARRIED, SunCore.Form.DEPLOYED, SunCore.Form.DELIVERED]:
		var owner_anchor := traveler.carry_anchor if form == SunCore.Form.CARRIED else anchor
		core.transfer(owner_anchor, form, 0.3)
		var intact := true
		for frame in 32:
			await physics_frame
			var suns := core.get_node("Visual/SunCenter").find_children("Sun*", "MeshInstance3D", false, false)
			intact = intact and suns.size() == 1 and suns[0].get_instance_id() == sun_id
		_check(intact and core.form == form and core.get_parent() == owner_anchor,
			"Form %d retains the original sun throughout animated transfer" % form)
	print("Traveler motion failures: ", failures)
	quit(1 if failures else 0)
