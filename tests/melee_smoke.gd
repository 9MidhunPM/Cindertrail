extends SceneTree
## godot --headless --fixed-fps 60 --script tests/melee_smoke.gd

var failures := 0
var game
var battle: CinderBattle
var traveler: CinderPlayer
var swings: Array[int] = []
var hit_counts: Array[int] = []
var contacts: Array[Vector3] = []
var contact_frames: Array[int] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(passed: bool, detail: String) -> void:
	print("PASS " if passed else "FAIL ", detail)
	if not passed:
		failures += 1

func _frames(count: int) -> void:
	for _frame in count:
		await physics_frame

func _run() -> void:
	set_meta(&"direct_journey", true)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	game = current_scene
	if game.get("battle") == null or game.get("player") == null:
		push_error("The journey failed to start")
		quit(1)
		return
	battle = game.battle
	traveler = game.player
	game.melee.swung.connect(func(index: int, count: int) -> void:
		swings.append(index)
		hit_counts.append(count))
	battle.damaged.connect(func(point: Vector3, _amount: float, source: StringName, _fatal: bool) -> void:
		if source == &"melee":
			contacts.append(point)
			contact_frames.append(Engine.get_physics_frames()))
	# A flat isolated deck keeps world generation and walking enemies out of the
	# measurement. Player, camera, input routing, combat and physics are live.
	var deck_center := Vector3(2500, 0, 2500)
	_box(deck_center - Vector3.UP * 0.5, Vector3(35, 1, 35))
	traveler.global_position = deck_center + Vector3.UP * 0.1
	battle.set_physics_process(false)
	await _frames(6)
	_check(not traveler.visual.drawn, "The blade starts sheathed")
	await _nearest_and_buffer()
	await _combo_defeat()
	await _obstructions()
	await _contextual_cuts()
	await _charge()
	await _tactical_inputs()
	await _frames(260)
	_check(not traveler.visual.drawn, "The blade returns to its sheath after a quiet moment")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hit-stop leaves time scale restored")
	print("Melee failures: ", failures)
	quit(1 if failures > 0 else 0)

func _box(center: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	game.add_child(body)
	body.global_position = center
	return body

func _enemy(offset: Vector3) -> CinderEnemy:
	var at := traveler.global_position + offset
	return battle.spawn_enemy(battle.CRAWLER, PackedVector3Array([at, at]))

func _reset_encounter() -> void:
	for target in battle.enemies:
		target.queue_free()
	battle.enemies.clear()
	await _frames(95)
	swings.clear()
	hit_counts.clear()
	contacts.clear()
	contact_frames.clear()

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	root.push_input(event, true)

func _nearest_and_buffer() -> void:
	traveler.visual.rotation.y = 0.0
	var camera_yaw: float = game.director.yaw
	var behind := _enemy(Vector3.BACK * 1.3)
	var front := _enemy(Vector3.FORWARD * 2.1)
	var health := behind.health
	_key(KEY_F, true)
	_key(KEY_F, false)
	_check(traveler.visual.drawn, "F starts the sword stroke on press")
	_check((-traveler.visual.global_basis.z).dot(Vector3.BACK) < 0.99, "A rear target does not snap the traveler around on press")
	await _frames(12)
	_check(behind.health < health and is_equal_approx(front.health, health), "The nearest rear enemy wins over a farther enemy in front")
	_check((-traveler.visual.global_basis.z).dot(Vector3.BACK) > 0.94 and is_equal_approx(game.director.yaw, camera_yaw),
		"The body completes its pivot by impact and the exploration camera retains its heading")
	# Buffer during recovery, then switch the closest enemy before the cancel window.
	game.melee.request(Vector3.BACK)
	front.global_position = traveler.global_position + Vector3.FORWARD * 1.1
	behind.global_position = traveler.global_position + Vector3.BACK * 2.0
	await _frames(25)
	_check(swings == [0, 1] and front.health < health, "The buffered rising cut reacquires the closest enemy on acceptance")
	game.melee.request(Vector3.FORWARD)
	await _frames(56)
	_check(swings == [0, 1, 2], "Three combo attacks each reach contact exactly once")
	await _reset_encounter()

func _combo_defeat() -> void:
	var crawler := _enemy(Vector3.FORWARD * 1.2)
	for tap in 3:
		game.melee.request(Vector3.FORWARD)
		await _frames(40)
	_check(swings == [0, 1, 2] and hit_counts == [1, 1, 1]
			and (not is_instance_valid(crawler) or crawler.fading),
		"A complete combo still defeats a healthy crawler")
	await _reset_encounter()

func _obstructions() -> void:
	var high := _enemy(Vector3(0.45, 2.2, 0))
	var covered := _enemy(Vector3.BACK * 1.4)
	var outside := _enemy(Vector3.FORWARD * 5.5)
	var wall := _box(traveler.global_position + Vector3(0, 1.1, 0.68), Vector3(1.3, 2.2, 0.16))
	var health := covered.health
	await _frames(3)
	game.melee.request(Vector3.RIGHT)
	await _frames(30)
	_check((-traveler.visual.global_basis.z).dot(Vector3.RIGHT) > 0.95,
		"Solid cover, another elevation and distant targets leave the supplied aim intact")
	var struck := battle.melee(traveler.global_position, Vector3.BACK, 2.35, PI, 11.0, 4.0)
	_check(struck == 0 and high.health == health and covered.health == health and outside.health == health,
		"Even a radial strike respects range, height and solid cover")
	wall.queue_free()
	await _reset_encounter()

func _contextual_cuts() -> void:
	var start := traveler.global_position
	var foe := _enemy(Vector3.FORWARD * 3.35)
	var before := foe.health
	_check(traveler.begin_swept_dash(Vector3.FORWARD, 2.34, .18, &"dash"), "A grounded dash starts before the follow-up")
	await _frames(2)
	_key(KEY_F, true)
	_key(KEY_F, false)
	await _frames(4)
	_check(swings.is_empty() and foe.health == before, "A buffered dash cut preserves the sweep until its exit")
	await _frames(41)
	_check(swings == [CinderMelee.ATTACKS.DASH_CUT] and foe.health == before - 15.0 and hit_counts == [1],
		"F during Shift produces one Sunwake Cut at the real blade contact")
	await _reset_encounter()
	traveler.global_position = start
	traveler.velocity = Vector3.ZERO
	await _frames(5)
	foe = _enemy(Vector3.FORWARD * 1.35)
	before = foe.health
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for frame in 44:
		await physics_frame
		if not traveler.is_on_floor() and traveler.velocity.y < -.22:
			break
	_click(MOUSE_BUTTON_LEFT, true, Vector2(360,240))
	_click(MOUSE_BUTTON_LEFT, false, Vector2(360,240))
	var airborne_damage := false
	for frame in 45:
		await physics_frame
		if not traveler.is_on_floor() and foe.health < before:
			airborne_damage = true
	_check(not airborne_damage and swings == [CinderMelee.ATTACKS.DESCENT] and foe.health == before - 21.0,
		"Left-click while descending holds Falling Star in the air and damages once on landing")
	await _reset_encounter()
	game.melee.request(Vector3.FORWARD)
	await _frames(40)
	_check(swings == [0], "A grounded cut after either variation restarts the normal combo")
	await _reset_encounter()

func _charge() -> void:
	_key(KEY_F, true)
	await _frames(32)
	_key(KEY_F, false)
	await _frames(90)
	_check(swings == [0], "An early release keeps the opening cut without a spin")
	swings.clear()
	_key(KEY_F, true)
	game.director.yaw += PI * 0.75
	await _frames(46)
	var release_heading: Vector3 = (-game.camera.global_basis.z).slide(Vector3.UP).normalized()
	_key(KEY_F, false)
	await _frames(50)
	_check((-traveler.visual.global_basis.z).dot(release_heading) > 0.99,
		"An empty spin follows the camera at release after turning during charge")
	swings.clear()
	_key(KEY_F, true)
	await _frames(46)
	_check(swings == [0], "Holding a ready charge waits for release")
	var targets: Array[CinderEnemy] = []
	for offset: Vector3 in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		targets.append(_enemy(offset * 1.35))
	contacts.clear()
	contact_frames.clear()
	_key(KEY_F, false)
	await _frames(86)
	var once_each := contacts.size() == targets.size()
	for target in targets:
		var count := 0
		for point in contacts:
			if point.distance_to(target.body_center()) < 0.05:
				count += 1
		once_each = once_each and count == 1
	_check(swings.size() == 2 and hit_counts.back() == 4 and once_each,
		"Releasing a ready charge sweeps through four bearings and damages each creature once")
	_check(contact_frames.size() == 4 and contact_frames.back() - contact_frames.front() > 3,
		"Spin contact travels around the traveler over several physics ticks")
	await _reset_encounter()
	_key(KEY_F, true)
	await _frames(46)
	_key(KEY_M, true)
	_key(KEY_M, false)
	_check(paused, "The map opens during charge")
	_key(KEY_F, false)
	_key(KEY_M, true)
	_key(KEY_M, false)
	await _frames(60)
	_check(not paused and swings == [0], "Releasing while the map is open cannot fire a spin on resume")
	swings.clear()
	_key(KEY_F, true)
	await _frames(46)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(paused, "Pause opens with a ready charge")
	_key(KEY_F, false)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(60)
	_check(not paused and swings == [0], "Pause clears the pending spin")

func _click(button: MouseButton, down: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = point
	root.push_input(event, true)

func _tactical_inputs() -> void:
	await _reset_encounter()
	traveler.global_position = game.grove.anchor.global_position + Vector3.UP * 0.12
	_key(KEY_F, true)
	await _frames(46)
	game.interact()
	_key(KEY_F, false)
	await _frames(90)
	_check(game.active_site == game.grove and game.mode == game.Mode.PREPARE and swings == [0],
		"Deploying the core cancels a ready charge")
	swings.clear()
	_click(MOUSE_BUTTON_LEFT, true, Vector2(500, 300))
	await _frames(46)
	_key(KEY_1, true)
	_key(KEY_1, false)
	_click(MOUSE_BUTTON_LEFT, false, Vector2(500, 300))
	await _frames(60)
	var socket: Node3D = game.grove.sockets[0]
	var pointer: Vector2 = game.camera.unproject_position(socket.global_position)
	_click(MOUSE_BUTTON_LEFT, true, pointer)
	_click(MOUSE_BUTTON_LEFT, false, pointer)
	await _frames(36)
	_check(battle.towers.has(0) and swings == [0],
		"Selecting a module cancels mouse charge and clicking the socket places only the tower")
	_click(MOUSE_BUTTON_RIGHT, true, pointer)
	_click(MOUSE_BUTTON_RIGHT, false, pointer)
	_check(battle.weapon_timer > 0 and swings == [0], "Right click still launches a spark")
	await _frames(85)
	swings.clear()
	_key(KEY_F, true)
	await _frames(46)
	game.pack_step(0.01)
	_check(game.mode == game.Mode.PACK, "The traveler can begin packing with the blade ready")
	_key(KEY_F, false)
	await _frames(60)
	_check(swings == [0], "Entering the pack channel cancels the ready charge")
