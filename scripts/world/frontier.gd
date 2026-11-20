class_name CinderFrontier
extends Node3D
## The expedition uses three authored routes, assembled once per journey at a shared fork and camp.

const LAYOUT_VERSION := 1
const ENTRANCE := Vector3(55, 5, 214)
const FORK := Vector3(55, 5, 280)
const CAMP := Vector3(59, 5, 468)
# Dry shelves beyond the fork, each with room for both approaches and the retreat arch.
const CLEARINGS := [Vector3(22, 5, 484), Vector3(88, 5, 492)]
const CLEARING_YAWS := [-0.21, 0.23]
const SITE_SPEC := preload("res://data/sites/frontier.tres")
const SCENERY := preload("res://scripts/world/frontier_scenery.gd")
const WEST_ROUTES := [
	[Vector2(19, 295), Vector2(-8, 324), Vector2(6, 353), Vector2(-12, 396), Vector2(14, 437)],
	[Vector2(33, 307), Vector2(-5, 337), Vector2(-16, 382), Vector2(12, 406), Vector2(10, 445)],
	[Vector2(17, 288), Vector2(12, 321), Vector2(-27, 355), Vector2(-13, 408), Vector2(25, 434)],
]
const EAST_ROUTES := [
	[Vector2(91, 305), Vector2(112, 339), Vector2(95, 366), Vector2(119, 409), Vector2(101, 441)],
	[Vector2(108, 298), Vector2(116, 340), Vector2(81, 376), Vector2(99, 407), Vector2(96, 447)],
	[Vector2(85, 310), Vector2(124, 327), Vector2(120, 363), Vector2(87, 396), Vector2(111, 441)],
]
const DISCOVERY_IDS := ["moths", "ore", "mirror"]
const DISCOVERY_PROMPTS := ["Follow the lantern moths", "Lower the abandoned ore cradle", "Align the tarnished mirror"]
const CLAIM_PROMPTS := ["Recover the hidden lamp", "Search the lowered cradle", "Open the lit recess"]
const DISCOVERY_MESSAGES := [
	"The moths settle beside a covered lantern.",
	"The cradle descends. Something is tucked beneath its load.",
	"The reflected beam picks out a recess in the wall.",
]
const DISCOVERY_REWARDS := [12, 16, 12]

var journey_seed: int
var randomized_layout := false
var clearing_variant := 0
var _clearing := Transform3D(Basis.IDENTITY, CAMP)
var site: CinderSite
var paths: Array[PackedVector3Array] = []
var layout_version: int:
	get:
		return LAYOUT_VERSION

var _scenery
var _discoveries: Array[Dictionary] = []
var _claimed := PackedStringArray()

func _ready() -> void:
	if randomized_layout:
		var index := posmod(clearing_variant, CLEARINGS.size())
		_clearing = Transform3D(Basis(Vector3.UP, CLEARING_YAWS[index]), CLEARINGS[index])
	var random := RandomNumberGenerator.new()
	random.seed = journey_seed ^ 468214
	_scenery = SCENERY.new()
	add_child(_scenery)
	_scenery.initialize(random.randi())
	var start := PackedVector3Array([ENTRANCE, Vector3(56, 5, 236), Vector3(49, 5, 257), FORK])
	paths.append(start)
	paths.append(_route(WEST_ROUTES[random.randi_range(0, WEST_ROUTES.size() - 1)], -1.0))
	paths.append(_route(EAST_ROUTES[random.randi_range(0, EAST_ROUTES.size() - 1)], 1.0))
	_scenery.surroundings()
	for i in paths.size():
		_scenery.walkway(paths[i], i)
	_scenery.island(FORK, 5.1, 10, Color("#9b885e"))
	_scenery.island(_clearing.origin, 8.2, 12, Color("#c4a780"))
	_scenery.camp(_clearing)
	_scenery.spillway(Vector3(52, 5, 237), Vector3(62, 5, 237))
	_sign(ENTRANCE, paths[0][1], "Last Lantern")
	_sign(paths[0][1], ENTRANCE, "Tanners’ Road")
	_sign(FORK, paths[1][1], "Cliff stair")
	_sign(FORK, paths[2][1], "Drowned road")
	_sign(_clearing.origin, paths[1][-2], "Tanners’ Road via cliff stair")
	_sign(_clearing.origin, paths[2][-2], "Tanners’ Road via drowned road")
	var first_kind := random.randi_range(0, 2)
	var second_kind := (first_kind + random.randi_range(1, 2)) % 3
	_add_discovery(paths[1], first_kind, -1.0)
	_add_discovery(paths[2], second_kind, 1.0)
	_scenery.finish()
	_build_site()

func _route(points: Array, side: float) -> PackedVector3Array:
	var result := PackedVector3Array([FORK])
	for point: Vector2 in points:
		result.append(Vector3(point.x, CAMP.y, point.y))
	if randomized_layout:
		# The final, twenty-seven metre approach fixes lane clearance at every socket.
		result.append(_clearing * Vector3(side * 18.0, 0, -20.0))
	result.append(_clearing.origin)
	return result

func _build_site() -> void:
	var sockets := PackedVector3Array([
		_clearing * Vector3(-3.8, .06, 1.8), _clearing * Vector3(2.5, .06, 3.2),
		_clearing * Vector3(-1.0, .06, -3.8), _clearing * Vector3(4.4, .06, .45),
	])
	var lanes: Array[PackedVector3Array] = []
	for i in range(1, 3):
		var previous := paths[i][-2]
		var camp := _clearing.origin
		var along := camp.direction_to(previous)
		lanes.append(PackedVector3Array([camp + along * 20.0, camp + along * 9.0, camp + along * 4.0, camp]))
	site = CinderSite.new()
	add_child(site)
	site.configure(SITE_SPEC, _clearing.origin + Vector3.UP * .05, sockets, lanes,
		_clearing * Vector3(0, 13, 22), _clearing * Vector3(0, .4, -3))
	site.habitat_frame.basis = _clearing.basis

func _sign(origin: Vector3, toward: Vector3, label: String) -> void:
	var along := origin.direction_to(toward)
	var side := along.cross(Vector3.UP)
	var marker := CinderWaymark.new()
	marker.position = origin + along * 1.8 + side * 2.2
	add_child(marker)
	marker.set_destination(label, along)

func _add_discovery(path: PackedVector3Array, kind: int, side: float) -> void:
	var point := path[3]
	var direction := path[2].direction_to(point)
	var outward := direction.cross(Vector3.UP) * side
	_scenery.island(point, 6.7, 10, Color("#9f8f70"))
	var clue := point + outward * 3.5 - direction * 1.9
	var reward := point + outward * 4.7 + direction * 3.25
	if kind == 1:
		reward = clue + direction * .62
	var artwork: Dictionary = _scenery.discovery(kind, clue, reward, -outward)
	_discoveries.append({
		"id": DISCOVERY_IDS[kind], "kind": kind,
		"clue": clue, "reward": reward, "revealed": false,
		"marker": artwork.marker, "guide": artwork.guide, "moving": artwork.moving, "beam": artwork.beam,
	})

func discovery_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for discovery in _discoveries:
		points.append(discovery.reward if discovery.revealed else discovery.clue)
	return points

func claimed_discoveries() -> PackedStringArray:
	return _claimed.duplicate()

func revealed_discoveries() -> PackedStringArray:
	var ids := PackedStringArray()
	for discovery in _discoveries:
		if discovery.revealed:
			ids.append(discovery.id)
	return ids

func restore_discoveries(ids: PackedStringArray, revealed := PackedStringArray()) -> void:
	_claimed = ids.duplicate()
	for discovery in _discoveries:
		if revealed.has(discovery.id) or _claimed.has(discovery.id):
			_reveal(discovery, false)
		if _claimed.has(discovery.id):
			_hide_discovery(discovery)

func _near_discovery(at: Vector3) -> Dictionary:
	for discovery in _discoveries:
		if _claimed.has(discovery.id):
			continue
		var affordance: Vector3 = discovery.reward if discovery.revealed else discovery.clue
		if at.distance_to(affordance) < 2.8:
			return discovery
	return {}

func hint_at(at: Vector3) -> String:
	var discovery := _near_discovery(at)
	if discovery.is_empty():
		return ""
	var kind: int = discovery.kind
	return "E   " + (CLAIM_PROMPTS[kind] if discovery.revealed else DISCOVERY_PROMPTS[kind])

func interact_at(at: Vector3) -> Dictionary:
	var discovery := _near_discovery(at)
	if discovery.is_empty():
		return {}
	var kind: int = discovery.kind
	if not discovery.revealed:
		_reveal(discovery, true)
		return {"scrap": 0, "message": DISCOVERY_MESSAGES[kind]}
	_claimed.append(discovery.id)
	_hide_discovery(discovery)
	return {"scrap": DISCOVERY_REWARDS[kind], "message": "Frontier discovery  •  +%d scrap" % DISCOVERY_REWARDS[kind]}

func _hide_discovery(discovery: Dictionary) -> void:
	discovery.marker.visible = false
	discovery.guide.visible = false
	if discovery.beam:
		discovery.beam.visible = false

func _reveal(discovery: Dictionary, animate: bool) -> void:
	if discovery.revealed:
		return
	discovery.revealed = true
	discovery.marker.visible = true
	if discovery.beam:
		discovery.beam.visible = true
	var signal_light: Node3D = discovery.guide
	var machinery: Node3D = discovery.moving
	var target: Vector3 = discovery.reward
	if not animate:
		signal_light.position = target
		match discovery.kind:
			1:
				machinery.position.y -= 1.5
			2:
				machinery.rotation.y += .8
		return
	var transition := create_tween().set_parallel()
	transition.tween_property(signal_light, "position", target, .9).set_trans(Tween.TRANS_SINE)
	match discovery.kind:
		1:
			transition.tween_property(machinery, "position:y", machinery.position.y - 1.5, 1.1)
		2:
			transition.tween_property(machinery, "rotation:y", machinery.rotation.y + .8, .65)
