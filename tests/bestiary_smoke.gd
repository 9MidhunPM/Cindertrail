extends SceneTree
## Short physical encounters exercising the species counters through actual player and tower attacks.
const SKIMMER := preload("res://data/enemies/ford_skimmer.tres")
const RAM := preload("res://data/enemies/quarry_ram.tres")
const SPLINTER := preload("res://data/enemies/splinterback.tres")
const WARDEN := preload("res://data/enemies/bell_warden.tres")
const TECH := preload("res://scripts/combat/enemy_technique.gd")
var fails := 0
var fight: CinderBattle
var core: SunCore
var grove: CinderSite

func _initialize() -> void:
	call_deferred("_run")

func _check(result: bool, message: String) -> void:
	print("PASS " if result else "FAIL ", message)
	if not result:
		fails += 1

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _member(stats: CinderEnemyStats, z: float, x := 0.0) -> CinderEnemy:
	var path := PackedVector3Array([Vector3(x, 0, z), Vector3(x, 0, 0)])
	return fight.spawn_enemy(stats, path, grove)

func _clear() -> void:
	for enemy in fight.enemies.duplicate():
		fight.enemies.erase(enemy)
		enemy.free()
	core.position = Vector3.ZERO
	core.health = 100.0

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80,1,80)
	collision.shape = floor_shape
	ground.add_child(collision)
	ground.position.y = -0.5
	stage.add_child(ground)
	core = preload("res://scenes/core/sun_core.tscn").instantiate()
	stage.add_child(core)
	fight = CinderBattle.new()
	stage.add_child(fight)
	fight.bind_carried_core(core)
	grove = CinderSite.new()
	stage.add_child(grove)
	var lanes: Array[PackedVector3Array] = [PackedVector3Array([Vector3(0,0,10), Vector3.ZERO])]
	grove.configure(preload("res://data/sites/grove.tres"), Vector3.ZERO, PackedVector3Array([Vector3(0,0,6)]), lanes, Vector3.ZERO, Vector3.ZERO)
	# The skimmer runs below the raised island, at the Grove's shallow-water level.
	grove.habitat_frame.origin.y = .73
	grove.wet = true
	var skimmer := _member(SKIMMER, 13.0)
	await _frames(25)
	var wet := skimmer.velocity.slide(Vector3.UP).length()
	grove.wet = false
	await _frames(20)
	var dry := skimmer.velocity.slide(Vector3.UP).length()
	_check(wet > dry * 1.35 and dry > 1.0, "Ford skimmer accelerates through shallows and loses speed on dry stone")
	_clear()
	fight.prepare(grove, core)
	var ram := _member(RAM, 9.0)
	await _frames(55)
	_check(ram.technique.phase == TECH.Phase.WINDUP and ram.velocity.slide(Vector3.UP).length() < 0.1, "Ram braces in place before its charge")
	_check(fight.place(0, 1), "Field installed on the approaching ram's lane")
	await _frames(4)
	_check(ram.technique.phase == TECH.Phase.RECOVER and ram.is_disrupted(), "A slowing field breaks a ram charge")
	fight.recall()
	_clear()
	var volley := _member(SPLINTER, 9.0)
	await _frames(54)
	_check(volley.technique.phase == TECH.Phase.WINDUP, "Splinterback fans its mantle over a marked volley")
	core.position.x = 4.5
	await _frames(110)
	_check(is_equal_approx(core.health, 100.0), "Moving the carried sun out of the locked landing circle evades the volley")
	_clear()
	volley = _member(SPLINTER, 9.0)
	await _frames(123)
	fight.recall()
	await _frames(43)
	_check(core.health < 100.0 and CinderEnemy.flat_distance(volley.global_position, core.position) > 2.0, "A launched volley stays dangerous at range when modules are recalled")
	_clear()
	var ally := _member(fight.BRUTE, 11.0, 0.0)
	var warden := _member(WARDEN, 12.0, 1.0)
	await _frames(112)
	_check(ally.is_warded(), "A bell warden opens its ribs to shield one ally")
	var before := ally.health
	var origin := ally.body_center() + Vector3(2.0,0,0)
	fight.attack(origin, Vector3.LEFT)
	_check(is_equal_approx(before - ally.health, fight.SPARK_DAMAGE * 0.42), "Shielded plates attenuate an incoming spark")
	await _frames(36)
	origin = warden.body_center() + Vector3.RIGHT
	fight.attack(origin, Vector3.LEFT)
	_check(not ally.is_warded(), "A spark interrupts the exposed chime and removes its ally's ward")
	_clear()
	fight.prepare(grove, core)
	grove.threat = 1
	_check("Ford Skimmer" in fight.forecast(), "Wave two forecasts its local specialist")
	_check(fight.begin(), "A mixed wave starts at normal pacing")
	var den := fight.spawn_roamer(SKIMMER, Vector3(6,0,8), Vector3(6,0,4))
	while fight.remaining_spawns > 0:
		await physics_frame
	var total := fight.enemies.size()
	for enemy in fight.enemies.duplicate():
		if enemy.counts_for_wave:
			fight.landmark_hit(enemy, 500.0)
	await _frames(2)
	_check(not fight.active_wave and is_instance_valid(den) and total == fight.total_in_wave + 1, "A roaming skirmish uses the shared budget and cannot hold a cleared camp wave open")
	_clear()
	stage.queue_free()
	await _frames(2)
	quit(1 if fails else 0)
