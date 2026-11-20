extends SceneTree
## godot --headless --fixed-fps 60 --script tests/melee_smoke.gd

var failures := 0

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
	var game = current_scene
	var battle: CinderBattle = game.battle
	var traveler: CinderPlayer = game.player
	await _frames(4)
	_check(not traveler.visual.drawn, "The blade starts sheathed")
	var crawler := CinderEnemy.new()
	battle.add_child(crawler)
	var front: Vector3 = traveler.global_position - traveler.visual.global_basis.z * 1.3
	crawler.configure(battle.CRAWLER, PackedVector3Array([front, front]), game.grove)
	battle.enemies.append(crawler)
	var health := crawler.health
	var swings := 0
	var hits: Array[int] = []
	game.melee.swung.connect(func(index: int, count: int) -> void: hits.append(count))
	for attempt in 3:
		if game.melee.request(front - traveler.global_position):
			swings += 1
		await _frames(40)
	_check(traveler.visual.drawn, "Swinging draws the blade")
	_check(swings == 3 and hits.size() == 3, "Three buffered swings each reach their contact frame")
	_check(not is_instance_valid(crawler) or crawler.health < health, "The combo wounds a crawler in front")
	var fallen := not is_instance_valid(crawler) or crawler.fading
	_check(fallen, "The full combo defeats a crawler")
	var behind := CinderEnemy.new()
	battle.add_child(behind)
	var back: Vector3 = traveler.global_position + traveler.visual.global_basis.z * 6.0
	behind.configure(battle.CRAWLER, PackedVector3Array([back, back]), game.grove)
	battle.enemies.append(behind)
	var spared := behind.health
	await _frames(60)
	var struck := battle.melee(traveler.global_position, -traveler.visual.global_basis.z, 2.35, 1.25, 11.0, 4.0)
	_check(struck == 0 and is_equal_approx(behind.health, spared), "Out-of-reach creatures are not struck")
	await _frames(260)
	_check(not traveler.visual.drawn, "The blade returns to its sheath after a quiet moment")
	_check(is_equal_approx(Engine.time_scale, 1.0), "Hit-stop leaves time scale restored")
	print("Melee failures: ", failures)
	quit(1 if failures > 0 else 0)
