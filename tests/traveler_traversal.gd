extends SceneTree
## Fixed-time input and collision checks with the actual controller and traveler.
const MODEL := preload("res://scenes/player/traveler_visual.tscn")
var pawn := CinderPlayer.new()
var failures := PackedStringArray()
var moves := PackedStringArray()
var rescues := 0

func _initialize() -> void:
	_run.call_deferred()

func _box(at: Vector3, extent: Vector3) -> StaticBody3D:
	var solid := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = extent
	collider.shape = shape
	solid.add_child(collider)
	solid.position = at
	root.add_child(solid)
	return solid

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:
		failures.append(label)

func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	_box(Vector3(0,-.5,0),Vector3(10,1,10))
	_box(Vector3(1.55,1.15,0),Vector3(.035,2.3,1.25))
	var roof := _box(Vector3(-3,.67,1),Vector3(1.4,.20,1.4))
	pawn.visual = MODEL.instantiate()
	pawn.add_child(pawn.visual)
	pawn.camera = cam
	pawn.position = Vector3(0,.1,0)
	root.add_child(pawn)
	pawn.configure_recovery(Vector3.ZERO, PackedVector3Array([Vector3(0,.1,2)]))
	pawn.movement_used.connect(func(kind: StringName): moves.append(String(kind)))
	pawn.recovered.connect(func(_from: Vector3,_to: Vector3): rescues += 1)
	await _ticks(22)
	_check(pawn.is_on_floor() and pawn.has_safe_footing(), "The capsule records a supported dry footprint")
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	var peak := pawn.position.y
	var airborne := false
	for i in 43:
		await physics_frame
		airborne = airborne or not pawn.is_on_floor()
		peak = maxf(peak,pawn.position.y)
	_check(airborne and peak > .70 and peak < .95 and pawn.is_on_floor() and moves.count("jump") == 1,
		"Space takes off, reaches the expected arc and lands once (%.2f m)" % peak)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _ticks(12)
	_check(moves.count("dash") == 1 and pawn.position.x > .5 and pawn.position.x < 1.30, "Shift dashes immediately and the 3.5 cm wall blocks the swept capsule")
	await _ticks(52)
	_check(moves.count("dash") == 1, "Holding Shift never repeatedly fires a dash")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _ticks(3)
	pawn.restore_position(Vector3(-2,.10,0))
	await _ticks(4)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _ticks(12)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _ticks(8)
	_check(pawn.position.z < -2.0 and pawn.is_on_floor(), "An unobstructed dash covers its full burst")
	pawn.restore_position(Vector3(0,.06,-4.53))
	await _ticks(5)
	var accepted := pawn.begin_swept_dash(Vector3.FORWARD, 4.0,.26)
	await _ticks(25)
	_check(not accepted or (pawn.position.z > -4.79 and pawn.is_on_floor()), "Sluice Step stops before the capsule can leave a ledge")
	# Walk past the lip, then jump a few physics ticks after losing contact.
	pawn.restore_position(Vector3(.7,.06,-4.42))
	await _ticks(6)
	Input.action_press("move_forward")
	for i in 35:
		await physics_frame
		if not pawn.is_on_floor():
			break
	await _ticks(2)
	var walked_off := not pawn.is_on_floor()
	var jumps := moves.count("jump")
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	Input.action_release("move_forward")
	_check(walked_off and moves.count("jump") == jumps + 1 and pawn.velocity.y > 4.0, "A late jump is accepted inside coyote time")
	pawn.restore_position(Vector3(0,.08,1.2))
	await _ticks(7)
	Input.action_press("jump")
	await _ticks(2)
	Input.action_release("jump")
	for i in 40:
		await physics_frame
		if pawn.velocity.y < -2 and pawn.position.y < .28 and not pawn.is_on_floor():
			break
	jumps = moves.count("jump")
	Input.action_press("jump")
	await _ticks(1)
	Input.action_release("jump")
	await _ticks(7)
	_check(moves.count("jump") == jumps + 1 and pawn.velocity.y > 3, "A jump buffered just before landing begins a fresh takeoff")
	# Airborne dash input has no effect even with a recovered cooldown.
	var dash_count := moves.count("dash")
	Input.action_press("sprint")
	await _ticks(2)
	Input.action_release("sprint")
	_check(moves.count("dash") == dash_count, "Shift cannot start an airborne dash")
	pawn.restore_position(Vector3(-3,.04,1))
	await _ticks(3)
	_check(pawn.position.distance_to(roof.position) > 1.0, "A checkpoint beneath a low ceiling falls back to clear authored ground")
	pawn.restore_position(Vector3(.2,.02,1.8))
	await _ticks(26)
	var safe := pawn.position
	var count := rescues
	pawn.global_position = Vector3(12,-5.5,0)
	pawn.velocity = Vector3(8,-7,0)
	await _ticks(6)
	_check(rescues == count + 1 and pawn.position.distance_to(safe) < .22 and pawn.velocity.length() < .15, "A void fall returns to the last local footprint with momentum cleared")
	pawn.restore_position(Vector3(0,.03,2))
	await _ticks(4)
	pawn.move_enabled = false
	Input.action_press("jump")
	Input.action_release("jump")
	pawn.move_enabled = true
	jumps = moves.count("jump")
	await _ticks(3)
	_check(jumps == moves.count("jump") and pawn.is_on_floor(), "A menu Space release cannot launch the traveler when movement returns")
	var ramp := _box(Vector3(11,.4,0),Vector3(4,.5,8))
	ramp.rotation.x = deg_to_rad(18.0)
	await _ticks(4)
	pawn.restore_position(Vector3(11,.65,0))
	await _ticks(16)
	var start_y := pawn.position.y
	accepted = pawn.begin_swept_dash(Vector3.FORWARD, 2.34,.18)
	await _ticks(16)
	_check(accepted and pawn.position.y > start_y + .40 and pawn.is_on_floor(), "Swept dash climbs a supported 18-degree slope")
	for action in ["sprint","move_right","move_forward","jump"]:
		Input.action_release(action)
	if not failures.is_empty():
		push_error(str(failures))
	quit(0 if failures.is_empty() else 1)
