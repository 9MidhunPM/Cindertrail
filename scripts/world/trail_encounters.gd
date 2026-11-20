extends Node3D
## A journey chooses a familiar local species and a small pack at each turnoff.
## Dormant models are scenery. Only a deliberately approached or shot pack joins combat.
const DEN := preload("res://scripts/world/trail_den.gd")
const SPECIES := {
	"crawler": preload("res://data/enemies/crawler.tres"),
	"ford_skimmer": preload("res://data/enemies/ford_skimmer.tres"),
	"quarry_ram": preload("res://data/enemies/quarry_ram.tres"),
	"splinterback": preload("res://data/enemies/splinterback.tres"),
	"bell_warden": preload("res://data/enemies/bell_warden.tres"),
}
# Stable keys preserve clears as other roads and frontier configurations are added.
const HABITATS := [
	["shale_hollow", "Quarry switchback", 3, "quarry_ram", "Quarry ram", "#b49b76", "#997f9c"],
	["glass_roost", "High orchard", 3, "splinterback", "Splinterback", "#998d6b", "#9d83b5"],
	["reed_nest", "South wash", 1, "ford_skimmer", "Ford skimmer", "#819883", "#5ab9ba"],
	["bell_cleft", "Relay ascent", 4, "bell_warden", "Bell warden", "#a49785", "#ac8667"],
	["frontier_escarpment", "", 1, "splinterback", "Splinterback", "#a18972", "#9689bf"],
	["frontier_mire", "", 1, "ford_skimmer", "Ford skimmer", "#75968a", "#6bb3a2"],
]
const ENGAGE_RADIUS := 3.65
const SCOUT_RADIUS := 15.5
const VISIBLE_RADIUS := 48.0
var _dens: Array[DEN] = []
var _members := {}
var _battle: CinderBattle
var _clock := 0.0
var _next_observe := 0.0

func configure(journey_seed: int, valley: CinderOuterValley, frontier: CinderFrontier, battle: CinderBattle) -> void:
	_battle = battle
	_battle.roamer_removed.connect(_on_removed)
	for i in HABITATS.size():
		var data: Array = HABITATS[i]
		var random := RandomNumberGenerator.new()
		random.seed = journey_seed ^ hash(data[0])
		var index := valley.road_names.find(data[1])
		var path: PackedVector3Array
		if index >= 0:
			path = valley.roads[index]
		elif data[1] == "":
			path = frontier.paths[1 if data[0] == "frontier_escarpment" else 2]
		else:
			continue
		if path.size() < 2:
			continue
		var section := mini(int(data[2]), path.size() - 2)
		var a := path[section]
		var b := path[section + 1]
		var delta := b - a
		var direction := delta.slide(Vector3.UP).normalized()
		var outward := direction.cross(Vector3.UP) * (-1.0 if random.randi_range(0,1) else 1.0)
		var grade := outward.cross(Vector3.UP).dot(direction) * delta.y / delta.slide(Vector3.UP).length()
		var pack: Array[CinderEnemyStats] = [SPECIES[data[3]]]
		for member in random.randi_range(0, 2):
			pack.append(SPECIES["crawler"])
		var den := DEN.new()
		add_child(den)
		den.build(data[0], a.lerp(b, random.randf_range(.40, .63)), outward, grade,
			pack, data[4], Color(data[5]), Color(data[6]))
		_dens.append(den)

func observe(delta: float, at: Vector3, traveling: bool) -> void:
	_clock += delta
	_next_observe -= delta
	if _next_observe > 0.0:
		return
	_next_observe = .10
	for den in _dens:
		var distance := at.distance_to(den.center())
		if distance > SCOUT_RADIUS + 6.0:
			den.scouting = false
			den.must_leave = false
		den.idle(distance < VISIBLE_RADIUS, _clock)
		if not traveling or den.claimed or den.alerted or den.must_leave or not _can_engage():
			continue
		if distance <= ENGAGE_RADIUS:
			_engage(den, at)
		elif distance < SCOUT_RADIUS and not den.scouting:
			den.scouting = true
			_battle.message.emit("%s tracks at the turnoff. The road passes safely." % den.label)

func _can_engage() -> bool:
	return _members.is_empty() and _battle.enemies.is_empty() and not _battle.halted and _battle.site == null

func provoke_by_aim(origin: Vector3, direction: Vector3) -> void:
	if not _can_engage() or direction.length_squared() < .001:
		return
	var aim := direction.normalized()
	var reach := 22.0
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + aim * reach, 1)
	var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty():
		reach = origin.distance_to(obstruction.position)
	var target: DEN
	for den in _dens:
		var distance := den.aimed_distance(origin, aim, reach)
		if distance < reach:
			target = den
			reach = distance
	if target:
		_engage(target, origin - Vector3.UP)

func _engage(den: DEN, traveler: Vector3) -> void:
	den.alerted = true
	den.clear_resting()
	for i in den.pack.size():
		if den.defeated & (1 << i):
			continue
		var enemy := _battle.spawn_roamer(den.pack[i], den.bed(i), traveler)
		if enemy != null:
			_members[enemy] = [den, i]
	if _members.is_empty():
		den.alerted = false
	else:
		_battle.message.emit("%s pack stirred" % den.label)

func _on_removed(enemy: CinderEnemy, defeated: bool) -> void:
	if not _members.has(enemy):
		return
	var entry: Array = _members[enemy]
	_members.erase(enemy)
	var den: DEN = entry[0]
	if defeated:
		den.defeated |= 1 << int(entry[1])
	if not _members.is_empty():
		return
	den.alerted = false
	den.must_leave = true
	if den.all_defeated() and not den.claimed:
		den.claimed = true
		var scrap := 4 + den.pack.size() * 2
		_battle.scrap += scrap
		_battle.message.emit("Turnoff cleared  ·  +%d scrap" % scrap)
		_battle.sound.emit("collect")

func progress() -> Dictionary:
	var result := {}
	for den in _dens:
		if den.defeated != 0:
			result[den.key] = den.defeated
	return result

func restore_progress(records: Dictionary) -> void:
	for den in _dens:
		var saved := int(records.get(den.key, 0))
		den.defeated = maxi(0, saved) & ((1 << den.pack.size()) - 1)
		den.claimed = den.all_defeated()
		den.clear_resting()
