extends Node3D
## Habitat coordinates are relative to the real campsite, including district relocation.
const Animal := preload("res://scripts/world/wildlife_animal.gd")
const S := Animal.Species
const NEAR_DISTANCE := 42.0

var animals: Array[Animal] = []
var _world: Node
var _next_check := 0.0
var _nearby: Array[Animal] = []
var _seed := 0
var _bell_fish: Array[Animal] = []
var _bell_scatter := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_world = get_parent()

func _populate() -> void:
	if not animals.is_empty():
		return
	_seed = _world.frontier.journey_seed
	for site: CinderSite in _world.sites:
		var p := site.anchor.global_position
		match site.checkpoint_id:
			&"flooded_grove":
				for i in 5:
					var offset := Vector3((i % 3) * .47, (i % 2) * .019, (i / 3) * .74)
					_place(S.FISH, p + Vector3(1.1, -.64, 10.9) + offset, p + Vector3(4.2, -.70, 9.5) + offset)
				_place(S.FROG, p + Vector3(.70, -.47, 13.6), p + Vector3(1.2, -.70, 11.4))
				_place(S.FROG, p + Vector3(-5.8, -.47, 11.3), p + Vector3(-7.3, -.66, 10.6))
			&"broken_quarry":
				_place(S.PIKA, p + Vector3(4.1, .02, 2.75), p + Vector3(6.0, .05, 3.7))
				_place(S.PIKA, p + Vector3(-3.8, .04, -3.0), p + Vector3(-5.4, .21, -4.7))
				# These raised benches are decorative rock, above the traversable floor.
				_place(S.GOAT, p + Vector3(-7.55, 2.09, -7.34), p + Vector3(-5.55, 2.23, -7.62), true)
				_place(S.GOAT, p + Vector3(-.02, 3.54, -7.56), p + Vector3(1.88, 3.35, -7.64), true)
			&"lanternwood":
				for i in 3:
					var offset := Vector3(i * 1.25, 0, i * .75)
					_place(S.DEER, p + Vector3(-6.5, .1, 5.9) + offset, p + Vector3(-12.8, 0, 8.5) + offset)
			&"sunken_aqueduct":
				_place(S.OTTER, p + Vector3(-9.7, -.51, -5.0), p + Vector3(-12, -.7, -5.2))
				_place(S.OTTER, p + Vector3(-11.3, -.49, -5.13), p + Vector3(-8.2, -.70, -5.45))
			&"sunwatch_observatory", &"fallen_relay":
				_place(S.KITE, p + Vector3(-3, 7, -3), p + Vector3(-13, 12, -8))
			&"last_lantern_frontier":
				# The two pillars beside Last Lantern have different authored heights.
				_place(S.OWL, p + Vector3(-5.5, 2.78, 3.3), p + Vector3(5.8, 3.24, 3.6))
	for road_name in ["High orchard", "Masons’ walk"]:
		var valley: CinderOuterValley = _world.outer_valley
		var road: PackedVector3Array = valley.roads[valley.road_names.find(road_name)]
		var tangent := road[2].direction_to(road[3])
		var verge := tangent.cross(Vector3.UP).normalized()
		var point := road[2].lerp(road[3], .53) + verge * 2.2
		_place(S.DEER if road_name == "High orchard" else S.PIKA, point, point + verge * 4.8 + tangent)
	_populate_bell_fish()

func _populate_bell_fish() -> void:
	var road := _world.get("bell_road") as Node3D
	if road == null:
		return
	var route: PackedVector3Array = road.route
	if route.size() < 2:
		return
	var crest: Vector3 = road.ruin_local
	var current := (crest - route[0]).slide(Vector3.UP).normalized()
	var bank := current.cross(Vector3.UP)
	# Follow the chosen crest and leave both deck approaches clear, including after the lift.
	var shoal := RandomNumberGenerator.new()
	shoal.seed = _seed ^ hash(crest)
	for i in 6:
		var along := (i % 3 - 1) * .71 + shoal.randf_range(-.12, .12)
		var across := (1.0 + float(i / 3) * .68) * (-1.0 if i % 2 == 0 else 1.0)
		var home := Vector3(crest.x, shoal.randf_range(.095, .14), crest.z)
		home += current * along + bank * across
		var refuge := home + bank * signf(across) * shoal.randf_range(2.3, 3.6) + current * .59
		refuge.y = .015
		_bell_fish.append(_place(S.FISH, road.to_global(home), road.to_global(refuge)))
	road.connect(&"toll_requested", _on_bell_toll)

func _on_bell_toll(_at: Vector3, _submerged: bool) -> void:
	# Keep danger raised through the short look-up state, then use ordinary refuge behavior.
	_bell_scatter = .85

func _place(kind: Animal.Species, home: Vector3, refuge: Vector3, ledge := false) -> Animal:
	var animal := Animal.new()
	animal.visible = false
	animal.authored_footing = ledge
	add_child(animal)
	var random := RandomNumberGenerator.new()
	random.seed = _seed ^ hash(home)
	animal.configure(kind, home, refuge, random.randf_range(0, TAU), random.randf_range(-PI, PI))
	animals.append(animal)
	return animal

func _physics_process(delta: float) -> void:
	if _world.frontier == null or _world.player == null:
		return
	if animals.is_empty():
		_populate()
	_bell_scatter = maxf(0.0, _bell_scatter - delta)
	var player: CinderPlayer = _world.player
	var observer := player.global_position
	_next_check -= delta
	if _next_check <= 0:
		_next_check = .25
		_nearby.clear()
		for animal in animals:
			var radius := 65.0 if animal.species == S.KITE else NEAR_DISTANCE
			animal.visible = observer.distance_squared_to(animal.home) < radius * radius
			if animal.visible:
				_nearby.append(animal)
	var battle: CinderBattle = _world.battle
	var busy := _world.active_site != null and (battle.active_wave or battle.engaged)
	for animal in _nearby:
		var danger := _bell_scatter > 0.0 and animal in _bell_fish
		danger = danger or (busy and animal.home.distance_squared_to(_world.active_site.anchor.global_position) < 28.0 * 28.0)
		if not danger:
			for enemy in battle.enemies:
				if animal.wake_point().distance_squared_to(enemy.global_position) < 7.5 * 7.5:
					danger = true
					break
		animal.step(delta, observer, player.velocity.slide(Vector3.UP).length(), danger)
