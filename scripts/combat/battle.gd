class_name CinderBattle
extends Node3D

signal message(text: String)
signal sound(cue: String)
signal enemy_defeated(enemy: CinderEnemy)
signal roamer_removed(enemy: CinderEnemy, defeated: bool)
## Damage dealt to a creature. source is "melee", "spark", "ability" or "tower".
signal damaged(point: Vector3, amount: float, source: StringName, fatal: bool)

const MODULES: Array[CinderModuleStats] = [
	preload("res://data/defenses/bolt.tres"), preload("res://data/defenses/field.tres"),
	preload("res://data/defenses/mortar.tres")
]
const CRAWLER: CinderEnemyStats = preload("res://data/enemies/crawler.tres")
const BRUTE: CinderEnemyStats = preload("res://data/enemies/brute.tres")
const WAVES: CinderWaveStats = preload("res://data/waves/valley.tres")
const WAVE_ENTRY := preload("res://scripts/combat/wave_entry.gd")
const REPAIR_COST := 8
const REPAIR_AMOUNT := 20.0
const SPARK_DAMAGE := 4.0
const SPARK_COOLDOWN := 0.55
const BASE_UPGRADE_CAP := 3
const MAX_UPGRADE_CAP := 10

var scrap := 16
var upgrade_cap := BASE_UPGRADE_CAP:
	set(value):
		upgrade_cap = clampi(value, BASE_UPGRADE_CAP, MAX_UPGRADE_CAP)
var active_wave := false
var enemies: Array[CinderEnemy] = []
# Each entry is an owned module. Its installed socket is temporary.
var inventory: Array[Dictionary] = []
var towers: Dictionary[int, CinderInstalledModule] = {}
var site: CinderSite
var core: SunCore
var engaged := false
var held := false
var halted := false
## Enabled for the current camp after the player deliberately resumes extraction at full restoration.
var post_restoration := false
var remaining_spawns := 0
var total_in_wave := 0
var spawn_timer := 0.0
var intermission := 0.0
var weapon_timer := 0.0
var last_breadcrumb := Vector3.INF
var _landmark_lane := -1
var _landmark_seconds := 0.0

func bind_carried_core(carried: SunCore) -> void:
	core = carried

## The same budget covers wave enemies, trail encounters and the summit guardian.
func register_enemy(enemy: CinderEnemy) -> bool:
	if halted or not enemy or enemies.has(enemy) or enemies.size() >= WAVES.active_limit:
		return false
	enemies.append(enemy)
	enemy.cue.connect(sound.emit)
	enemy.volley.connect(_enemy_volley)
	return true

func spawn_enemy(spec: CinderEnemyStats, path: PackedVector3Array, camp: CinderSite = null, lane := -1) -> CinderEnemy:
	if halted or spec == null or path.is_empty() or enemies.size() >= WAVES.active_limit:
		return null
	var enemy := CinderEnemy.new()
	add_child(enemy)
	enemy.configure(spec, path, camp)
	enemy.origin_lane = lane
	if not register_enemy(enemy):
		enemy.queue_free()
		return null
	return enemy

func spawn_roamer(spec: CinderEnemyStats, start: Vector3, approach: Vector3) -> CinderEnemy:
	var enemy := spawn_enemy(spec, PackedVector3Array([start, approach]))
	if enemy:
		enemy.pursuing = true
		enemy.award_bounty = false
		enemy.is_roamer = true
	return enemy

func prepare(camp: CinderSite, sun: SunCore) -> void:
	if halted or is_instance_valid(site):
		return
	site = camp
	core = sun
	held = false
	engaged = false
	active_wave = false
	post_restoration = false

func begin(after_full_restoration := false) -> bool:
	if halted or not is_instance_valid(site) or site.remaining_energy <= 0.0 or not is_instance_valid(core):
		return false
	var fully_restored := core.restoration >= 100.0
	if fully_restored != after_full_restoration:
		return false
	if engaged:
		if not held or not after_full_restoration:
			return false
		post_restoration = true
		resume()
		return true
	if held:
		return false
	post_restoration = after_full_restoration
	engaged = true
	_start_wave()
	return true

func hold() -> void:
	held = true

func resume() -> void:
	held = false

func recall() -> void:
	if site:
		for enemy in enemies:
			if not enemy.pursuing:
				enemy.pursuing = true
				enemy.counts_for_wave = false
				enemy.follow_trail(site.anchor.global_position)
	for tower in towers.values():
		tower.queue_free()
	towers.clear()
	for module in inventory:
		module.socket = -1
	for child in get_children():
		if child is CinderShotEffect and (halted or not child.is_in_group(&"hostile_volleys")):
			child.queue_free()
	site = null
	held = false
	engaged = false
	active_wave = false
	post_restoration = false
	remaining_spawns = 0
	last_breadcrumb = Vector3.INF
	_landmark_lane = -1
	_landmark_seconds = 0.0

func stop() -> void:
	halted = true
	recall()
	for enemy in enemies.duplicate():
		if enemy.is_roamer:
			roamer_removed.emit(enemy, false)
		enemy.queue_free()
	enemies.clear()
	set_physics_process(false)

func _packed(kind: int) -> int:
	var best := -1
	for i in inventory.size():
		var module := inventory[i]
		if module.kind == kind and module.socket == -1 and (best < 0 or module.level > inventory[best].level):
			best = i
	return best

func module_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for i in MODULES.size():
		var packed := _packed(i)
		var detail := "%d scrap" % MODULES[i].price if packed < 0 else "packed · Lv %d" % inventory[packed].level
		labels.append(detail)
	return labels

func socket_at(point: Vector3) -> int:
	if not site:
		return -1
	var best := -1
	var closest := 1.75
	for i in site.sockets.size():
		var dist := CinderEnemy.flat_distance(point, site.sockets[i].global_position)
		if dist < closest:
			closest = dist
			best = i
	return best

func place(index: int, kind: int) -> bool:
	if halted or held or not site or index < 0 or index >= site.sockets.size() or kind < 0 or kind >= MODULES.size() or towers.has(index):
		return false
	var stats := MODULES[kind]
	var id := _packed(kind)
	if id < 0:
		if scrap < stats.price:
			message.emit("Need %d scrap for %s." % [stats.price, stats.label])
			return false
		scrap -= stats.price
		inventory.append({"kind": kind, "level": 1, "socket": -1})
		id = inventory.size() - 1
	inventory[id].socket = index
	var tower := CinderInstalledModule.new()
	add_child(tower)
	tower.global_position = site.sockets[index].global_position
	tower.configure(kind, inventory[id].level, stats)
	towers[index] = tower
	sound.emit("build")
	return true

func upgrade(index: int) -> bool:
	if held or halted or not towers.has(index):
		return false
	var tower := towers[index]
	var cost := upgrade_cost(index)
	if cost < 0:
		message.emit("Defense level cap reached (%d)." % upgrade_cap)
		return false
	if scrap < cost:
		message.emit("Upgrade costs %d scrap." % cost)
		return false
	for module in inventory:
		if module.socket == index:
			scrap -= cost
			module.level += 1
			tower.set_level(module.level)
			message.emit("%s upgraded to level %d." % [tower.stats.label, tower.level])
			sound.emit("build")
			return true
	return false

func repair() -> bool:
	if held or halted or not site or not core or core.health >= 100.0 or core.health <= 0.0:
		return false
	if scrap < REPAIR_COST:
		message.emit("Repairs cost %d scrap." % REPAIR_COST)
		return false
	scrap -= REPAIR_COST
	core.repair(REPAIR_AMOUNT)
	sound.emit("collect")
	return true

func attack(origin: Vector3, dir: Vector3) -> bool:
	if halted or weapon_timer > 0.0 or dir.length_squared() < 0.0001:
		return false
	var aim := dir.normalized()
	var reach := 22.0
	var obstruction := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + aim * reach, 1))
	if not obstruction.is_empty():
		reach = origin.distance_to(obstruction.position) + 0.1
	var target: CinderEnemy
	var end := origin + aim * reach
	for enemy in enemies:
		var offset := enemy.body_center() - origin
		var distance := offset.dot(aim)
		if distance < 0.0 or distance >= reach:
			continue
		if (offset - aim * distance).length() <= enemy.spark_radius():
			target = enemy
			reach = distance
			end = enemy.body_center()
	_visual_shot(origin, end, false, Color(0.70, 0.95, 1.0))
	if target:
		_hit(target, SPARK_DAMAGE, &"spark")
	weapon_timer = SPARK_COOLDOWN
	sound.emit("attack")
	return true

func forecast() -> String:
	if not site or site.lane_names.is_empty():
		return ""
	var upcoming := site.threat if active_wave else site.threat + 1
	var count := total_in_wave if active_wave else _count_for(upcoming)
	var contacts := PackedStringArray()
	for sequence in count:
		var spec := _wave_member(upcoming, sequence, count)
		if spec != CRAWLER and not contacts.has(spec.label):
			contacts.append(spec.label)
	return "%s  ·  %d hostiles  ·  %s" % ["/".join(site.lane_names), count, "crawlers" if contacts.is_empty() else ", ".join(contacts)]

func _wave_member(wave: int, slot: int, count: int) -> CinderEnemyStats:
	var escort := wave > WAVES.brute_from and slot % WAVES.brute_every == WAVES.brute_every - 2
	if _has_brute(wave) and (slot == count - 1 or escort):
		return BRUTE
	if wave < WAVES.specialist_from or WAVES.specialists.is_empty():
		return CRAWLER
	for i in WAVES.specialists.size():
		var native := WAVES.specialists[i]
		if native.home_sites.has(String(site.checkpoint_id)):
			if slot == 1:
				return native
			if wave >= WAVES.mixed_from and slot == 4:
				var offset := 1 + (wave - WAVES.mixed_from) % maxi(1, WAVES.specialists.size() - 1)
				return WAVES.specialists[(i + offset) % WAVES.specialists.size()]
			break
	return CRAWLER

func _wave_alive() -> bool:
	for enemy in enemies:
		if enemy.counts_for_wave:
			return true
	return false

func _has_brute(wave: int) -> bool:
	return wave >= WAVES.brute_from or (site.intensity > 1.1 and wave >= WAVES.brute_from - 1)

func _count_for(wave: int) -> int:
	var growth := roundi((wave - 1) * WAVES.count_growth * site.intensity)
	return clampi(WAVES.base_count + growth + floori(core.restoration / WAVES.restoration_step), WAVES.base_count, WAVES.max_count)

## Scrap needed to raise the tower in this socket by one level; -1 when it cannot be upgraded.
func upgrade_cost(index: int) -> int:
	if not towers.has(index) or towers[index].level >= upgrade_cap:
		return -1
	return towers[index].stats.upgrade_cost * towers[index].level

func _start_wave() -> void:
	site.threat += 1
	active_wave = true
	total_in_wave = _count_for(site.threat)
	remaining_spawns = total_in_wave
	spawn_timer = 0.0
	sound.emit("wave")
	message.emit("Wave %d  ·  %s" % [site.threat, forecast()])

## Bias only nearby crawler reinforcements. Brutes keep their original route.
func bias_next_spawns(lane_index: int, seconds := 3.0) -> bool:
	if halted or held or not site or lane_index < 0 or lane_index >= site.lanes.size() or seconds <= 0.0:
		return false
	_landmark_lane = lane_index
	_landmark_seconds = seconds
	return true

func landmark_hit(enemy: CinderEnemy, damage: float) -> void:
	if halted or not site or not is_instance_valid(enemy) or damage <= 0.0:
		return
	if enemy.site_of_origin == site and not enemy.pursuing and enemies.has(enemy):
		_hit(enemy, damage)

func ability_hit(enemy: CinderEnemy, amount: float) -> void:
	if halted or amount <= 0.0 or not is_instance_valid(enemy) or not enemies.has(enemy):
		return
	_hit(enemy, amount, &"ability")

func _advance_waves(delta: float) -> void:
	if not engaged or held or site.remaining_energy <= 0.0 or (core.restoration >= 100.0 and not post_restoration):
		return
	if not active_wave:
		intermission -= delta
		if intermission <= 0.0:
			_start_wave()
		return
	if remaining_spawns > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and enemies.size() < WAVES.active_limit and not site.lanes.is_empty():
			var sequence := total_in_wave - remaining_spawns
			var spec := _wave_member(site.threat, sequence, total_in_wave)
			var lane_index := (sequence + site.threat - 1) % site.lanes.size()
			if spec == CRAWLER and _landmark_seconds > 0.0:
				lane_index = _landmark_lane
			var lane := site.lanes[lane_index]
			if lane.size() >= 2:
				var route := WAVE_ENTRY.extend(get_world_3d().direct_space_state, lane, spec)
				var enemy := spawn_enemy(spec, route, site, lane_index)
				if not enemy:
					return
				enemy.counts_for_wave = true
				remaining_spawns -= 1
				spawn_timer = WAVES.interval / clampf(site.intensity, 0.85, 1.45)
	elif not _wave_alive():
		active_wave = false
		intermission = WAVES.breather
		_landmark_seconds = 0.0
		scrap += WAVES.clear_bonus
		message.emit("Wave held  ·  +%d scrap  ·  next in %.1fs" % [WAVES.clear_bonus, WAVES.breather])

func _physics_process(delta: float) -> void:
	if halted or not is_instance_valid(core):
		return
	weapon_timer = maxf(0.0, weapon_timer - delta)
	if active_wave and not held:
		_landmark_seconds = maxf(0.0, _landmark_seconds - delta)
	_advance_waves(delta)
	if enemies.is_empty():
		return
	if last_breadcrumb == Vector3.INF or last_breadcrumb.distance_to(core.global_position) > 0.85:
		last_breadcrumb = core.global_position
		for enemy in enemies:
			if enemy.pursuing:
				enemy.follow_trail(last_breadcrumb)
	for tower in towers.values():
		_update_tower(tower, delta)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if (enemy.pursuing and enemy.global_position.distance_to(core.global_position) > WAVES.leash) or enemy.global_position.y < -30.0:
			enemies.remove_at(i)
			if enemy.is_roamer:
				roamer_removed.emit(enemy, false)
			enemy.withdraw()
			continue
		var slow := 1.0
		for tower in towers.values():
			if tower.kind == 1 and enemy.global_position.distance_to(tower.global_position) <= tower.stats.reach:
				slow = minf(slow, tower.stats.power / (1.0 + tower.stats.upgrade_gain * (tower.level - 1)))
		enemy.separation = Vector3.ZERO
		for other in enemies:
			var offset := enemy.global_position - other.global_position
			offset.y = 0.0
			if offset.length_squared() < 1.0 and offset.length_squared() > 0.0001:
				enemy.separation += offset.normalized() * (1.0 - offset.length())
		if enemy.advance(core, delta, slow):
			core.damage(enemy.stats.damage)
			sound.emit("hit")
			if halted or core.health <= 0.0:
				return

func _update_tower(tower: CinderInstalledModule, delta: float) -> void:
	if tower.kind == 1:
		return
	tower.cooldown -= delta
	var target: CinderEnemy
	var closest := INF
	for enemy in enemies:
		var range_to := tower.global_position.distance_to(enemy.global_position)
		if range_to <= tower.stats.reach and range_to >= tower.stats.min_reach:
			var urgency := core.global_position.distance_squared_to(enemy.global_position)
			if urgency < closest:
				closest = urgency
				target = enemy
	if not target:
		return
	var end := target.body_center()
	tower.track(end, delta)
	if tower.cooldown > 0.0:
		return
	var muzzle := tower.fire()
	var power := tower.stats.power * (1.0 + tower.stats.upgrade_gain * (tower.level - 1))
	var lob := tower.kind == 2
	if lob:
		end += Vector3(target.velocity.x, 0.0, target.velocity.z) * 0.5
	var shot := _visual_shot(muzzle, end, lob, Color(1.0, 0.67, 0.22))
	if lob:
		shot.set_blast_radius(tower.stats.splash)
		shot.landed.connect(_splash.bind(end, tower.stats.splash, power), CONNECT_ONE_SHOT)
	else:
		_hit(target, power)
	tower.cooldown = tower.stats.interval
	sound.emit("mortar" if lob else "attack")

func _visual_shot(origin: Vector3, end: Vector3, arc: bool, tint: Color) -> CinderShotEffect:
	var shot := CinderShotEffect.new()
	add_child(shot)
	shot.launch(origin, end, arc, tint)
	return shot

func _splash(point: Vector3, radius: float, power: float) -> void:
	if halted or not site:
		return
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if CinderEnemy.flat_distance(enemy.global_position, point) <= radius:
			_hit(enemy, power)

## Use the same reachability rules for selecting a foe and landing a blow.
func blade_path_clear(origin: Vector3, enemy: CinderEnemy) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.fading or enemy.health <= 0.0:
		return false
	if absf(enemy.global_position.y - origin.y) > 1.8:
		return false
	var hand := origin + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(hand, enemy.body_center(), 1)
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func closest_melee_target(origin: Vector3, radius: float) -> CinderEnemy:
	var closest: CinderEnemy
	var best_distance := radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := (enemy.global_position - origin).slide(Vector3.UP).length_squared()
		if distance > best_distance or (closest and distance == best_distance):
			continue
		if blade_path_clear(origin, enemy):
			best_distance = distance
			closest = enemy
	return closest

## A shared hit set lets the charged blade visit consecutive sectors of its arc.
func melee(origin: Vector3, forward: Vector3, reach: float, half_arc: float, damage: float, knockback: float,
		already_hit: Dictionary = {}) -> int:
	if halted:
		return 0
	var aim := forward.slide(Vector3.UP).normalized()
	var struck := 0
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if not is_instance_valid(enemy) or already_hit.has(enemy.get_instance_id()):
			continue
		var offset := (enemy.global_position - origin).slide(Vector3.UP)
		if offset.length_squared() > pow(reach + enemy.stats.radius, 2):
			continue
		if half_arc < PI and offset.length_squared() > 0.0001 and aim.angle_to(offset.normalized()) > half_arc:
			continue
		if not blade_path_clear(origin, enemy):
			continue
		already_hit[enemy.get_instance_id()] = true
		var away := offset.normalized() if offset.length_squared() > 0.0025 else aim
		enemy.shove(away * knockback, 0.32)
		enemy.flash()
		_hit(enemy, damage, &"melee")
		struck += 1
	return struck

func _hit(enemy: CinderEnemy, amount: float, source := &"tower") -> void:
	if source == &"spark" or source == &"melee":
		enemy.direct_hit()
		amount += enemy.consume_mark_bonus(source)
	var applied := amount * (0.42 if enemy.is_warded() else 1.0)
	var before := enemy.health
	enemy.combat_hit(applied, source)
	damaged.emit(enemy.body_center(), minf(before, maxf(0.0, before - enemy.health)), source, enemy.health <= 0)
	if enemy.health <= 0:
		enemies.erase(enemy)
		if enemy.award_bounty:
			scrap += enemy.stats.bounty
		enemy_defeated.emit(enemy)
		if enemy.is_roamer:
			roamer_removed.emit(enemy, true)
		enemy.withdraw(true)

func _enemy_volley(origin: Vector3, target: Vector3, radius: float, damage: float) -> void:
	var tint := Color("#d17fba")
	var shot := _visual_shot(origin, target + Vector3.UP * 0.15, true, tint)
	shot.add_to_group(&"hostile_volleys")
	shot.set_blast_radius(radius)
	shot.ring_ink.set_shader_parameter("amber", tint)
	shot.ring_ink.set_shader_parameter("hot", Color("#ffe1e8"))
	shot.landed.connect(_volley_hit.bind(target, radius, damage), CONNECT_ONE_SHOT)

func _volley_hit(point: Vector3, radius: float, damage: float) -> void:
	if halted or not is_instance_valid(core):
		return
	if CinderEnemy.flat_distance(point, core.global_position) <= radius and absf(core.global_position.y - point.y) < 2.2:
		core.damage(damage)
		sound.emit("hit")
