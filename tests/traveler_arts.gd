extends SceneTree
## Exercise all seven site rewards through the live controller, physics server and damage resolver.
const ARTS := preload("res://scripts/game/traveler_arts.gd")
const ALL := [&"flooded_grove",&"broken_quarry",&"fallen_relay",&"lanternwood",&"sunken_aqueduct",&"sunwatch",&"last_lantern_frontier"]
var failures := 0
var stage := Node3D.new()
var arts := ARTS.new()
var hero := CinderPlayer.new()
var battle := CinderBattle.new()
var core := preload("res://scenes/core/sun_core.tscn").instantiate() as SunCore

func _initialize() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _expect(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.position = at
	stage.add_child(body)
	return body

func _foe(z: float, x := 0.0) -> CinderEnemy:
	var point := Vector3(x,0,z)
	return battle.spawn_enemy(battle.CRAWLER,PackedVector3Array([point,point]))

func _setup_art(id: StringName) -> void:
	for enemy in battle.enemies.duplicate():
		battle.enemies.erase(enemy)
		enemy.free()
	hero.position = Vector3.ZERO
	hero.velocity = Vector3.ZERO
	arts.restore(ALL,id,0.0)
	battle.weapon_timer = 0.0

func _run() -> void:
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	_box(Vector3(0,-.5,0),Vector3(24,1,24))
	hero.visual = preload("res://scenes/player/traveler_visual.tscn").instantiate()
	hero.add_child(hero.visual)
	hero.camera = camera
	stage.add_child(hero)
	stage.add_child(core)
	stage.add_child(battle)
	battle.bind_carried_core(core)
	battle.set_physics_process(false)
	stage.add_child(arts)
	arts.configure(hero,battle,core)
	await _frames(5)
	_expect(not arts.cast(Vector3.FORWARD) and arts.hud_state().is_empty(), "A new traveler has no ability")
	_expect(arts.unlock(ALL[0]) and not arts.unlock(ALL[0]) and arts.ability_name(ALL[0]) == "Reed Snare", "The first reward equips once with a named HUD state")
	arts.unlock(ALL[1])
	var foe := _foe(-4.0)
	var witness := _foe(-4.0,7.0)
	_expect(arts.cast(Vector3.FORWARD,Vector3(0,0,-4)), "Reed Snare lands on traversable ground")
	var retained := arts.remaining_seconds()
	_expect(arts.cycle() and arts.selected_id() == ALL[1] and not arts.cast(Vector3.FORWARD), "Cycling cannot bypass shared recovery")
	core.position = Vector3(0,0,-10)
	foe.advance(core,1.0/60.0,1.0)
	witness.advance(core,1.0/60.0,1.0)
	_expect(foe.velocity.slide(Vector3.UP).length() < witness.velocity.slide(Vector3.UP).length()*.55, "Only the enemy inside the reeds slows")
	arts.restore(ALL,ALL[1],retained)
	_expect(is_equal_approx(arts.remaining_seconds(),retained) and arts.selected_id()==ALL[1], "Restore keeps the selected ID and remaining recovery")
	arts.set_available(false)
	_expect(not arts.cycle() and not arts.cast(Vector3.FORWARD), "Packing rejects new input")
	arts.set_available(true)
	paused = true
	var before_pause := arts.remaining_seconds()
	await process_frame
	_expect(is_equal_approx(arts.remaining_seconds(),before_pause) and not arts.cast(Vector3.FORWARD), "Pausing freezes recovery")
	paused = false
	_setup_art(ALL[1])
	foe = _foe(-3.0)
	witness = _foe(3.0)
	_expect(arts.cast(Vector3.FORWARD) and foe.health == 20.0 and witness.health == 34.0 and foe.knock.length() > 0.0, "Faultline damages and displaces foes only inside its forward cone")
	_setup_art(ALL[2])
	var a := _foe(-3)
	var b := _foe(-5,2)
	var c := _foe(-6,4)
	var d := _foe(-7,6)
	_expect(arts.cast(Vector3.FORWARD) and [a.health,b.health,c.health,d.health] == [24.0,27.0,30.0,34.0], "Chain Spark hits exactly three foes for 10, 7 and 4 damage")
	_setup_art(ALL[3])
	core.health=70.0
	core.restoration=62.0
	_expect(arts.cast(Vector3.FORWARD), "Mothward shelters the existing core")
	core.damage(4.0)
	core.damage(6.0)
	_expect(core.health == 68.0 and core.restoration == 62.0 and core.ward_strength == 0.0, "The ward absorbs eight damage and leaves restoration intact")
	_setup_art(ALL[4])
	foe = _foe(-1.2)
	var wall := _box(Vector3(0,1,-2.0),Vector3(2,2,.22))
	await _frames(2)
	_expect(arts.cast(Vector3.FORWARD), "Sluice Step starts a swept movement")
	await _frames(17)
	_expect(hero.position.z < -.6 and hero.position.z > -1.9 and foe.knock.length() > 0, "Sluice Step pushes a brushed enemy and stops before a solid wall")
	wall.free()
	_setup_art(ALL[5])
	foe = _foe(-1.6)
	_expect(arts.cast(Vector3.FORWARD) and foe.lensmarked(), "Lensmark finds the pointed creature")
	battle.ability_hit(foe,2.0)
	battle.attack(foe.body_center()+Vector3.BACK,Vector3.FORWARD)
	battle.melee(hero.position,Vector3.FORWARD,2.1,1.2,2.0,0.0)
	battle.melee(hero.position,Vector3.FORWARD,2.1,1.2,2.0,0.0)
	_expect(is_equal_approx(foe.health,12.0) and not foe.lensmarked(), "Exactly three actual spark or blade hits gain four damage each")
	_setup_art(ALL[6])
	foe = _foe(-3.2)
	_expect(arts.cast(Vector3.FORWARD), "Wick Recall leaves the traveler's hand")
	await _frames(50)
	_expect(foe.health == 22.0, "A returning crescent hits once in each direction")
	_setup_art(ALL[5])
	foe = _foe(-3.0)
	wall = _box(Vector3(0,1,-1.5),Vector3(3,2,.3))
	await _frames(2)
	_expect(not arts.cast(Vector3.FORWARD) and arts.remaining_seconds() == 0.0, "Blocked targets consume no cooldown")
	arts.restore(ALL,ALL[3],0.0)
	arts.cast(Vector3.FORWARD)
	arts.restore(ALL,ALL[3],17.5)
	_expect(core.ward_strength == 0.0 and is_equal_approx(arts.remaining_seconds(),17.5), "Retry discards active protection without refreshing its cooldown")
	stage.queue_free()
	await _frames(2)
	print("Traveler art failures ",failures)
	quit(1 if failures else 0)
