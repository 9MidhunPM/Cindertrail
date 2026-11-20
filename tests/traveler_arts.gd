extends SceneTree
## Exercise all seven site rewards through the live controller, physics server and damage resolver.
const ARTS := preload("res://scripts/game/traveler_arts.gd")
const ALL := [&"flooded_grove",&"broken_quarry",&"fallen_relay",&"lanternwood",&"sunken_aqueduct",&"sunwatch_observatory",&"last_lantern_frontier"]
var failures := 0
var awards: Array[String] = []
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
	arts.profile = ARTS.PROFILE.new("user://arts-test-%d-%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()])
	arts.achievement_unlocked.connect(func(title: String): awards.append(title))
	arts.configure(hero,battle,core)
	await _frames(5)
	_expect(not arts.cast(Vector3.FORWARD) and arts.hud_state().ability_slots.size() == 7 and not arts.hud_state().has("ability_name"), "A new traveler has no ability")
	_expect(arts.unlock(ALL[0]) and not arts.unlock(ALL[0]) and arts.ability_name(ALL[0]) == "Reed Snare", "The first reward equips once with a named HUD state")
	_expect(awards == ["Reed Snare"] and arts.achievements()[0].earned, "First mastery writes the profile and emits one achievement")
	arts.restore([], &"", {})
	_expect(arts.unlock(ALL[0]) and awards.size() == 1, "Repeating the shrine in a fresh journey equips its art without repeating the achievement")
	arts.unlock(ALL[1])
	var foe := _foe(-4.0)
	var witness := _foe(-4.0,7.0)
	_expect(arts.cast(Vector3.FORWARD,Vector3(0,0,-4)), "Reed Snare lands on traversable ground")
	var retained := arts.remaining_seconds()
	_expect(arts.cycle() and arts.selected_id() == ALL[1] and not arts.cast(Vector3.FORWARD), "Q switches during the short cast lock")
	core.position = Vector3(0,0,-10)
	foe.advance(core,1.0/60.0,1.0)
	witness.advance(core,1.0/60.0,1.0)
	_expect(foe.velocity.slide(Vector3.UP).length() < witness.velocity.slide(Vector3.UP).length()*.55, "Only the enemy inside the reeds slows")
	await _frames(19)
	_expect(arts.cast(Vector3.FORWARD) and arts.cooldowns()[ALL[0]] > 6.0, "A second art chains while the first is still cooling down")
	var saved := arts.cooldowns()
	arts.restore(ALL,ALL[0],saved,arts.cast_lock())
	_expect(is_equal_approx(arts.remaining_seconds(),saved[ALL[0]]) and is_equal_approx(arts.cast_lock(),arts.CAST_RECOVERY), "New checkpoints restore independent timers and the short lock")
	arts.restore(ALL,ALL[1],retained)
	_expect(arts.cooldowns()[ALL[4]] == 4.0 and arts.cooldowns()[ALL[3]] == retained and awards.size() == 2,
		"Legacy shared recovery migrates to each learned art and silently imports the remaining shrine achievements")
	var rows: Array = ARTS.PROFILE.new(arts.profile.path).rows()
	_expect(rows.size() == 7 and rows.all(func(row: Dictionary): return row.earned and row.icon is Texture2D), "A new profile reader sees seven persistent illustrated achievements")
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
	_expect(arts.cast(Vector3.FORWARD) and foe.health == 10.0 and witness.health == 34.0 and foe.knock.length() > 0.0, "Faultline damages and displaces foes only inside its forward cone")
	_setup_art(ALL[2])
	var a := _foe(-3)
	var b := _foe(-5,2)
	var c := _foe(-6,4)
	var d := _foe(-7,6)
	_expect(arts.cast(Vector3.FORWARD) and [a.health,b.health,c.health,d.health] == [18.0,22.0,25.0,28.0], "Chain Spark hits four distinct foes for 16, 12, 9 and 6 damage")
	_setup_art(ALL[3])
	core.health=70.0
	core.restoration=62.0
	_expect(arts.cast(Vector3.FORWARD), "Mothward shelters the existing core")
	core.damage(8.0)
	core.damage(10.0)
	_expect(core.health == 68.0 and core.restoration == 62.0 and core.ward_strength == 0.0, "The ward absorbs sixteen damage and leaves restoration intact")
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
	foe.health = 100.0
	_expect(arts.cast(Vector3.FORWARD) and foe.lensmarked(), "Lensmark finds the pointed creature")
	battle.ability_hit(foe,2.0)
	battle.attack(foe.body_center()+Vector3.BACK,Vector3.FORWARD)
	battle.melee(hero.position,Vector3.FORWARD,2.1,1.2,2.0,0.0)
	battle.melee(hero.position,Vector3.FORWARD,2.1,1.2,2.0,0.0)
	_expect(foe.lensmarked(), "An ability hit leaves all four blade and sun-spark charges available")
	battle.melee(hero.position,Vector3.FORWARD,2.1,1.2,2.0,0.0)
	_expect(is_equal_approx(foe.health,64.0) and not foe.lensmarked(), "Exactly four actual spark or blade hits gain six damage each")
	_setup_art(ALL[6])
	foe = _foe(-3.2)
	_expect(arts.cast(Vector3.FORWARD), "Wick Recall leaves the traveler's hand")
	await _frames(50)
	_expect(foe.health == 14.0, "A returning crescent hits once in each direction")
	_setup_art(ALL[5])
	foe = _foe(-3.0)
	wall = _box(Vector3(0,1,-1.5),Vector3(3,2,.3))
	await _frames(2)
	_expect(not arts.cast(Vector3.FORWARD) and arts.remaining_seconds() == 0.0, "Blocked targets consume no cooldown")
	arts.restore(ALL,ALL[3],0.0)
	arts.cast(Vector3.FORWARD)
	arts.restore(ALL,ALL[3],17.5)
	_expect(core.ward_strength == 0.0 and is_equal_approx(arts.remaining_seconds(),12.0), "Retry discards active protection without refreshing its cooldown")
	wall.free()
	_setup_art(ALL[3])
	hero.visual.attack(0)
	_expect(not arts.cast(Vector3.FORWARD), "A committed sword windup cannot be cancelled by a cast")
	await _frames(22)
	_expect(arts.cast(Vector3.FORWARD) and not arts.cast(Vector3.FORWARD) and arts.remaining_seconds() == 0.0,
		"The final sword recovery accepts just one cast into the buffer")
	await _frames(12)
	_expect(core.ward_strength == 16.0 and arts.remaining_seconds() > 0.0, "The queued ward casts when the sword has recovered")
	_setup_art(ALL[3])
	hero.visual.attack(0)
	await _frames(22)
	arts.cast(Vector3.FORWARD)
	arts.set_available(false)
	await _frames(12)
	arts.set_available(true)
	_expect(core.ward_strength == 0.0 and arts.remaining_seconds() == 0.0, "Disabling controls cancels a buffered cast without spending its cooldown")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arts.profile.path))
	stage.queue_free()
	await _frames(2)
	# Use the actual generated camps and checkpoint keys, not the tuning filenames.
	set_meta(&"direct_journey", true)
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var game = current_scene
	var learned := PackedStringArray()
	for camp: CinderSite in game.sites:
		if camp.spec.energy <= 0.0:
			continue
		var title: String = game.arts.ability_name(camp.checkpoint_id)
		_expect(not title.is_empty() and not learned.has(title) and game.arts.unlock(camp.checkpoint_id),
			"Live %s checkpoint unlocks its unique traveler art" % camp.label)
		learned.append(title)
	_expect(learned.size() == ALL.size(), "All seven extraction sites grant a portable reward")
	current_scene.queue_free()
	await _frames(2)
	print("Traveler art failures ",failures)
	quit(1 if failures else 0)
