extends Node3D
## Authored street and roof compositions share one painted masonry kit.

const MESH := preload("res://scripts/world/environment_mesh.gd")
const WATER := preload("res://art/materials/stylized/cistern_water.gdshader")
const LAMP := preload("res://art/materials/sun_amber.tres")
const STONE := Color("#d4c8ac")
const SAND := Color("#af9274")
const SHALE := Color("#50616c")
const WOOD := Color("#6b4c33")
const COPPER := Color("#c47a4c")
const BRONZE := Color("#688982")
const RUST := Color("#9c6544")
const NIGHT := Color("#202b40")

var variant := 0
var anchor := Vector3.ZERO
var discovery_points := PackedVector3Array()
var _street := PackedVector3Array()
var _roads: Array = []
var _kind: StringName
var _stone := MESH.new()
var _soft := MESH.new()
var _collision: StaticBody3D
var _lots: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()

func configure(kind: StringName, choice: int, at: Vector3, heading: Vector3, roads: Array) -> void:
	_kind = kind
	variant = clampi(choice, 0, 1)
	anchor = at
	position = at
	rotation.y = atan2(-heading.x, -heading.z)
	_roads = roads
	_rng.seed = hash(String(kind)) ^ (7919 * variant)
	_collision = StaticBody3D.new()
	_collision.name = "TownShellCollisions"
	add_child(_collision)
	match kind:
		&"western_arcade":
			name = "WesternArcade"
			_western_arcade()
		&"bellmakers_steps":
			name = "BellmakersSteps"
			_bellmakers_steps()
		_:
			name = "MineralWard"
			_mineral_ward()
	_stone.mount(self, "BuiltMasonry", MESH.pigment())
	_soft.mount(self, "FallenLeavesAndCanvas", MESH.pigment(1), false)
	_roads = []

func street_waypoints() -> PackedVector3Array:
	return _street.duplicate()

func _western_arcade() -> void:
	var old_tiles := Color("#536069") if variant == 0 else RUST.darkened(.22)
	_paved_way(-11.5, 2.0, STONE.darkened(.15))
	for row in 3:
		_road_arch(-4.5 - row * 3.15, 2.75 + .26 * (row % 2), row == (1 if variant == 0 else 2), STONE)
	var sign_side := -1.0 if variant == 0 else 1.0
	var court := _lot(-sign_side, 6.3, 4.4, Vector2(1.32, 1.27))
	if court != Vector3.INF:
		_well(court, STONE, SHALE)
		_discovery(court + Vector3(0, 0, 2.6))
		_watch_light(court + Vector3(.76, .93, .4))
	var arcade_end := _lot(sign_side, 5.5, -15.6, Vector2(1.32, 1.38))
	if arcade_end != Vector3.INF:
		_tower(arcade_end, 4.7, STONE, old_tiles, false)
		_discovery(arcade_end + Vector3(0, 0, 1.9))
	for row in 6:
		var s := sign_side * (-1.0 if row % 2 == 1 else 1.0)
		var slot := _lot(s, 5.7, -15.0 + row * 4.05, Vector2(1.73, 1.64))
		if slot != Vector3.INF:
			_house(slot, Vector2(1.72, 1.60), 2.48 + .27 * (row % 3), SAND.lightened(.11), old_tiles, row % 3, row == 1)
			if row % 2 == 0:
				_canvas(slot + Vector3(0, 2.07, 1.9), Color("#a7714f"), row % 3)

func _bellmakers_steps() -> void:
	var sign_side := 1.0 if variant == 0 else -1.0
	_paved_way(-9.0, 3.0, SHALE.lerp(STONE, .46))
	var belfry := _lot(sign_side, 6.1, -5.1, Vector2(1.86, 1.78))
	if belfry != Vector3.INF:
		_tower(belfry, 7.1 if variant == 0 else 6.15, STONE, BRONZE if variant == 0 else COPPER, true)
		_discovery(belfry + Vector3(0, .15, 2.8))
	var foundry := _lot(-sign_side, 7.2, 5.8, Vector2(1.65, 1.65))
	if foundry != Vector3.INF:
		_house(foundry, Vector2(1.62, 1.58), 2.79, SHALE.lightened(.17), BRONZE, 0, true)
		_stone.tapered(foundry + Vector3(1.03, 2.45, -.90), foundry + Vector3(1.03, 4.14, -.90), .39, .32, 8, RUST)
		_discovery(foundry + Vector3(0, .10, 2.49))
		_watch_light(foundry + Vector3(-.98, 1.35, 1.78))
	for row in 7:
		var side := sign_side * (-1.0 if row % 2 == 0 else 1.0)
		var slot := _lot(side, 6.75, -18.0 + row * 3.43, Vector2(1.60, 1.38))
		if slot != Vector3.INF:
			var plaster := STONE.lerp(SHALE, .17 * (row % 3))
			_house(slot, Vector2(1.56, 1.36), 2.5 + .40 * (row % 3), plaster, COPPER.darkened(.32), row % 3, false)
			if row % 3 == 1:
				_fallen_step(slot + Vector3(0, 0, 1.75), 1.35, SHALE.lightened(.2))

func _mineral_ward() -> void:
	var sign_side := -1.0 if variant == 0 else 1.0
	_paved_way(-12.0, 3.0, Color("#808e89"))
	var tiles := Color("#627d79") if variant == 0 else Color("#566d85")
	var cistern := _lot(sign_side, 5.85, -4.5, Vector2(2.15, 1.85))
	if cistern == Vector3.INF:
		cistern = _lot(-sign_side, 6.0, -3.1, Vector2(2.15, 1.85))
	if cistern != Vector3.INF:
		_cistern(cistern)
		_discovery(cistern + Vector3(0, 0, 2.55))
		_watch_light(cistern + Vector3(1.58, .74, 1.38))
	var overhang := _lot(-sign_side, 6.5, 6.8, Vector2(1.45, 1.2))
	if overhang != Vector3.INF:
		_tower(overhang, 4.65, STONE.lerp(BRONZE, .24), tiles, false)
		_discovery(overhang + Vector3(0, 0, 1.95))
	for row in 7:
		var side := sign_side * (1.0 if row % 2 == 1 else -1.0)
		var slot := _lot(side, 5.65 + .7 * (row % 3), -14.0 + row * 3.24, Vector2(1.52, 1.54))
		if slot != Vector3.INF:
			_house(slot, Vector2(1.48, 1.50), 2.17 + .18 * (row % 3), STONE.lerp(BRONZE, .24), tiles, row % 3, row == 0)
			_stone.block(slot + Vector3(0, -.32, 1.53), Vector3(1.59, .38, .26), BRONZE.darkened(.15))

func _paved_way(start: float, end: float, stone: Color) -> void:
	# Low pavers follow the real road bed. Its authored collision remains authoritative.
	for row in range(floori(start * 2.0), floori(end * 2.0)):
		var z := row * .50
		var center := Vector3(0, 0, z)
		var sample := _street_sample(center)
		if sample.x > 1.42:
			continue
		center.y = sample.y
		if row % 6 == 0:
			_street.append(to_global(center + Vector3.UP * .05))
		for col in range(-2, 3):
			var tile := center + Vector3(col * .62, .031, _rng.randf_range(-.023, .023))
			var tint := stone.lightened(_rng.randf_range(-.16, .15))
			_stone.block(tile, Vector3(_rng.randf_range(.26, .30), .055, _rng.randf_range(.21, .245)), tint, _rng.randf_range(-.032, .032))
			if _rng.randf() < .16:
				var spill := tile + Vector3(_rng.randf_range(-.24, .24), .067, .05)
				_leaf(spill, _rng.randf() * TAU)

func _road_arch(z: float, span: float, split: bool, tint: Color) -> void:
	var origin := Vector3(0, 0, z)
	var sample := _street_sample(origin)
	if sample.x > 1.20:
		return
	origin.y = sample.y
	var radius := span
	var spring := origin + Vector3.UP * 2.85
	for hand in [-1.0, 1.0]:
		var post := origin + Vector3.RIGHT * float(hand) * radius
		for course in 7:
			var half := Vector3(.38 + (.12 if course == 0 else .0), .239, .39)
			var p := post + Vector3(_rng.randf_range(-.022, .022), .44 * (course + .5) - .22, 0)
			_stone.block(p, half, tint.lightened(_rng.randf_range(-.13, .09)), _rng.randf_range(-.063, .063))
		if _street_sample(post).x > 2.10:
			_solid(post + Vector3.UP * 1.32, Vector3(.64, 3.0, .73))
	for stone in 13:
		if split and stone in [4, 5, 6, 7, 8]:
			continue
		var a := PI * (stone + .034) / 13.0
		var b := PI * (stone + .966) / 13.0
		_voussoir(spring, radius, radius + .47, .38, a, b, tint.lightened(_rng.randf_range(-.18, .13)))
	for i in 5:
		var rim := origin + Vector3((3.1 + _rng.randf_range(0, .4)) * (-1.0 if i % 2 == 0 else 1.0),
			.03, _rng.randf_range(-.52, .52))
		_stone.facets(rim, Vector3(.26, .15, .20), 6, SHALE.lerp(tint, .48))

func _voussoir(center: Vector3, inner: float, outer: float, depth: float, a: float, b: float, tint: Color) -> void:
	var ray_a := Vector3(cos(a), sin(a), 0)
	var ray_b := Vector3(cos(b), sin(b), 0)
	var p := center + ray_a * inner
	var q := center + ray_b * inner
	var r := center + ray_b * outer
	var s := center + ray_a * outer
	var front := Vector3.BACK * depth
	var back := Vector3.FORWARD * depth
	_stone.panel(p + front, q + front, r + front, s + front, tint, Vector3.BACK)
	_stone.panel(p + back, q + back, r + back, s + back, tint.darkened(.11), Vector3.FORWARD)
	_stone.panel(p + back, p + front, q + front, q + back, tint.darkened(.27), -ray_a - ray_b)
	_stone.panel(s + back, s + front, r + front, r + back, tint.lightened(.10), ray_a + ray_b)
	_stone.panel(p + back, p + front, s + front, s + back, tint.darkened(.13), Vector3.LEFT)
	_stone.panel(q + back, q + front, r + front, r + back, tint.darkened(.16), Vector3.RIGHT)

func _house(at: Vector3, half: Vector2, h: float, wall: Color, tiles: Color, damage: int, enterable: bool) -> void:
	var x := half.x
	var z := half.y
	_stone.block(at + Vector3.DOWN * .53, Vector3(x + .08, .58, z + .07), wall.darkened(.28))
	if enterable:
		_solid(at + Vector3.DOWN * .19, Vector3(2.0 * x, .44, 2.0 * z))
	var courses := ceili(h / .44)
	var door_half := .66
	for course in courses:
		var height := .20 + course * .41
		var tint := wall.lightened(_rng.randf_range(-.085, .095))
		_stone.block(at + Vector3(0, height, -z), Vector3(x, .202, .13), tint.darkened(.08))
		for side in [-1.0, 1.0]:
			var s := float(side)
			_stone.block(at + Vector3(s * x, height, 0), Vector3(.14, .202, z), tint.darkened(.06 + .07 * s))
			if course < 5:
				var leg := (x - door_half) * .50
				_stone.block(at + Vector3(s * (door_half + leg), height, z), Vector3(leg, .202, .16), tint)
		if course >= 5:
			_stone.block(at + Vector3(0, height, z), Vector3(x, .20, .145), tint)
	for side in [-1.0, 1.0]:
		var s := float(side)
		_stone.block(at + Vector3(s * .73, .97, z + .16), Vector3(.11, 1.08, .07), STONE.lightened(.07))
		_stone.block(at + Vector3(s * (x - .44), 1.43, z + .156), Vector3(.18, .33, .026), NIGHT)
		_stone.block(at + Vector3(s * (x - .44), 1.035, z + .22), Vector3(.26, .06, .15), tint_stone(wall))
	_stone.block(at + Vector3(0, 2.18, z + .17), Vector3(.83, .14, .12), STONE)
	if not enterable:
		_stone.block(at + Vector3(0, .94, z - .15), Vector3(.62, .99, .03), NIGHT)
		for board in 2:
			_stone.tapered(at + Vector3(-.62, .35 + board * .76, z + .085),
				at + Vector3(.62, .76 + board * .65, z + .085), .057, .053, 4, WOOD)
		_solid(at + Vector3.UP * h * .45, Vector3(2.0 * x, h, 2.0 * z))
	else:
		for side in [-1.0, 1.0]:
			_solid(at + Vector3(float(side) * x, h * .47, 0), Vector3(.23, h, 2.0 * z))
		_solid(at + Vector3(0, h * .47, -z), Vector3(2.0 * x, h, .24))
		for side in [-1.0, 1.0]:
			var width := x - door_half
			_solid(at + Vector3(float(side) * (door_half + width * .5), .98, z), Vector3(width, 2.05, .25))
		var jamb := at + Vector3(0, 2.21, z)
		_solid(jamb, Vector3(1.34, .20, .30))
	if damage == 0:
		_roof(at + Vector3.UP * (courses * .41), Vector2(x + .24, z + .23), 1.2, tiles, false)
	elif damage == 1:
		_roof(at + Vector3.UP * (courses * .41), Vector2(x + .24, z + .22), .92, tiles, true)
	else:
		for beam in 3:
			var dz := -z + .72 * beam
			_stone.tapered(at + Vector3(-x, h - .09, dz), at + Vector3(-.4, h + .63, dz + .16), .10, .069, 4, WOOD)
		_stone.block(at + Vector3(x - .22, h - .32, -z + .21), Vector3(.29, .61, .31), wall.darkened(.16))
	for i in 7:
		var p := at + Vector3(_rng.randf_range(-x - .33, x + .33), .035, z + _rng.randf_range(.19, .56))
		if enterable and absf(p.x) < .87:
			continue
		_stone.facets(p, Vector3(.17, .11, .15) * _rng.randf_range(.49, 1.34), 6, wall.darkened(.13))
	var climbing_side := -1.0 if damage == 1 else 1.0
	_ivy(at + Vector3(climbing_side * (x - .21), h - .09, z + .23), h * .71)
	_street_facade(at, half, courses, wall, damage)

func _street_facade(at: Vector3, half: Vector2, courses: int, wall: Color, damage: int) -> void:
	var x := half.x
	var z := half.y
	var hand := -1.0 if at.x > 0.0 else 1.0
	var flank := at + Vector3(hand * (x + .146), 0, 0)
	var plaster := wall.lerp(SAND, .29)
	# Varied ashlar rises above the original courses without changing the house collision.
	for course in courses:
		var y := .20 + .41 * course
		var seam := .28 if course % 2 == 0 else .57
		var beside := -z + .08
		var index := 0
		while beside < z - .04:
			var width := seam if index == 0 else .65 + .15 * sin(index * 3.3 + course)
			var next := minf(z - .025, beside + width)
			if next - beside > .06:
				var base := flank + Vector3(0, y - .182, beside)
				var upper := base + Vector3.UP * (.354 - .015 * (index % 2))
				var edge := Vector3.BACK * (next - beside - .024)
				var tint := plaster.lightened(.094 * sin(index * 2.75 + course * 1.82))
				_stone.panel(base, base + edge, upper + edge, upper, tint, Vector3.RIGHT * hand)
			index += 1
			beside = next + .017
	var ledge := flank + Vector3(hand * .012, .21, 0)
	_stone.block(ledge, Vector3(.11, .104, z + .09), SHALE.lerp(wall, .43))
	_stone.block(ledge + Vector3.BACK * (z + .22), Vector3(.27, .090, .24), SHALE.lerp(wall, .50), .055)
	for bay in 2:
		var window := flank + Vector3(hand * .016, .98 + .115 * bay, -.55 + 1.04 * bay)
		_stone.block(window, Vector3(.032, .33, .24), STONE.darkened(.16))
		_stone.block(window + Vector3.RIGHT * hand * .061, Vector3(.014, .239, .164), NIGHT)
		_stone.block(window + Vector3(hand * .07, -.32, .012), Vector3(.082, .055, .30), STONE)
		if (bay + damage) % 2 == 0:
			_stone.tapered(window + Vector3(hand * .086, -.19, .074),
				window + Vector3(hand * .086, .21, -.086), .026, .019, 4, WOOD)
	if damage != 2:
		var eave := flank + Vector3(hand * .10, courses * .41 + .017, 0)
		_stone.block(eave, Vector3(.105, .081, z + .226), WOOD)
		for brace in 3:
			var bracket := flank + Vector3(hand * .047, courses * .41 - .35, -.72 + .69 * brace)
			_stone.tapered(bracket, bracket + Vector3(hand * .26, .37, .065), .067, .044, 4, WOOD.lightened(.15))
	# The corner catches ivy and crumbling stone rather than hiding a portal.
	_ivy(flank + Vector3(hand * .059, courses * .41 - .19, z * .75), .93)
	for i in 4:
		var toe := flank + Vector3(hand * (.20 + .13 * i), .014, z * .74 + .14 * sin(i * 4.20))
		_stone.facets(toe, Vector3(.18, .10 + .024 * i, .18), 5, plaster.darkened(.15 + .03 * i))
		_leaf(toe + Vector3(hand * .14, .014, .06), i * 1.37)

func tint_stone(tint: Color) -> Color:
	return tint.lerp(STONE, .53).lightened(.063)

func _roof(at: Vector3, half: Vector2, rise: float, tiles: Color, split: bool) -> void:
	for side in [-1.0, 1.0]:
		var s := float(side)
		for course in 5:
			var begin := float(course) / 5.0
			var end := float(course + 1) / 5.0
			for row in 6:
				if split and ((row > 2 and s > 0) or (row > 3 and course < 2)):
					continue
				var z0 := lerpf(-half.y, half.y, row / 6.0) - .016
				var z1 := lerpf(-half.y, half.y, (row + 1) / 6.0) + .016
				var lip := at + Vector3(begin * half.x * s, rise * (1.0 - begin), 0)
				var edge := at + Vector3(end * half.x * s, rise * (1.0 - end), 0)
				_stone.panel(lip + Vector3.BACK * z0, edge + Vector3.BACK * z0, edge + Vector3.BACK * z1,
					lip + Vector3.BACK * z1, tiles.lightened(_rng.randf_range(-.16, .18)), Vector3.UP)
				_stone.panel(edge + Vector3.BACK * z0, edge + Vector3.BACK * z1,
					edge + Vector3(0, -.046, z1), edge + Vector3(0, -.046, z0), tiles.darkened(.22), Vector3.RIGHT * s)
	for end in [-1.0, 1.0]:
		var lip := at + Vector3.BACK * half.y * float(end)
		_stone.face(lip + Vector3.LEFT * half.x, lip + Vector3.RIGHT * half.x, lip + Vector3.UP * rise,
			tint_stone(tiles.darkened(.19)), Vector3.BACK * float(end))

func _tower(at: Vector3, h: float, tint: Color, crown: Color, bell: bool) -> void:
	_stone.block(at + Vector3.DOWN * .30, Vector3(1.45, .62, 1.38), tint.darkened(.17))
	for course in ceili(h / .58):
		var y := .28 + course * .56
		var width := lerpf(1.15, .91, clampf(y / h, 0, 1))
		_stone.block(at + Vector3.UP * y, Vector3(width, .272, width), tint.lightened(_rng.randf_range(-.14, .12)))
		if course % 3 == 1:
			var lintel := at + Vector3(0, y, width + .014)
			_stone.block(lintel, Vector3(.12, .19, .019), NIGHT)
			_stone.block(lintel + Vector3.DOWN * .22, Vector3(.25, .07, .10), STONE)
	_stone.block(at + Vector3.UP * h, Vector3(1.2, .22, 1.18), tint.lightened(.15))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var p := at + Vector3(float(x) * .84, h + .83, float(z) * .84)
			_stone.block(p, Vector3(.21, .82, .21), tint)
	if bell:
		var head := at + Vector3.UP * (h + 1.43)
		_stone.tapered(head + Vector3.DOWN * .7, head, .50, .20, 12, COPPER)
		_stone.tapered(head + Vector3.DOWN * .78, head + Vector3.DOWN * .7, .58, .50, 12, COPPER.lightened(.23))
		_stone.tapered(head + Vector3.DOWN * .87, head + Vector3.DOWN * .74, .084, .078, 6, WOOD)
	_roof(at + Vector3.UP * (h + 1.60), Vector2(1.23, 1.16), .87, crown, variant == 1 and not bell)
	_solid(at + Vector3.UP * h * .50, Vector3(2.0, h, 2.0))

func _canvas(at: Vector3, cloth: Color, tears: int) -> void:
	for side in [-1.0, 1.0]:
		var s := float(side)
		_stone.tapered(at + Vector3(s * 1.28, -.19, 1.10), at + Vector3(s * 1.28, -2.02, 1.10),
			.071, .075, 5, WOOD)
	for panel in 5:
		if panel == tears and variant == 1:
			continue
		var x := -1.27 + .51 * panel
		var p := at + Vector3(x, .11, -.24)
		var q := p + Vector3.RIGHT * .49
		var bend := Vector3(0, -.34 - .16 * sin(panel * 1.37), 1.28)
		_soft.panel(p, q, q + bend, p + bend, cloth.lightened(.052 * (panel % 2)), Vector3.UP)

func _well(at: Vector3, stone: Color, inside: Color) -> void:
	for turn in 10:
		var a := TAU * turn / 10.0
		var center := at + Vector3(cos(a) * .64, .27, sin(a) * .64)
		_stone.block(center, Vector3(.21, .29, .21), stone, -a)
	_stone.block(at + Vector3.UP * .06, Vector3(.58, .08, .56), inside)
	_solid(at + Vector3.UP * .26, Vector3(1.48, .57, 1.48))

func _cistern(at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		var s := float(side)
		_stone.block(at + Vector3(s * 1.80, .30, 0), Vector3(.20, .36, 1.56), STONE.lerp(BRONZE, .19))
		_solid(at + Vector3(s * 1.80, .23, 0), Vector3(.38, .63, 3.04))
		_stone.block(at + Vector3(0, .30, s * 1.52), Vector3(1.63, .36, .20), STONE.lerp(BRONZE, .31))
		_solid(at + Vector3(0, .23, s * 1.52), Vector3(3.21, .63, .35))
	var surface := at + Vector3.UP * .30
	var water := MeshInstance3D.new()
	water.name = "CisternWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.28, 2.69)
	water.mesh = plane
	var current := ShaderMaterial.new()
	current.shader = WATER
	water.material_override = current
	water.position = surface
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	for limb in 11:
		var p := surface + Vector3(1.37 - (limb % 4) * .16, 0, -1.10 + .22 * (limb % 5))
		var bend := p + Vector3(.12, _rng.randf_range(.30, .52), -.12)
		_soft.face(p - Vector3.RIGHT * .058, p + Vector3.RIGHT * .05, bend, BRONZE.lightened(.15), Vector3.BACK)

func _ivy(top: Vector3, height: float) -> void:
	var stem := top
	var teal := Color("#527052")
	for step in 8:
		var wind := sin(step * 1.84) * .075
		var tip := top + Vector3(wind, -height * (step + 1) / 8.0, .012 * step)
		_soft.tapered(stem, tip, .019, .017, 4, teal.darkened(.13))
		var along := Vector3(-.14 if step % 2 == 0 else .16, -.05, .055)
		var rim := stem.lerp(tip, .59)
		var width := along.cross(Vector3.BACK) * .38
		_soft.face(rim, rim + along, rim + along * .42 + width, teal.lightened(.12), Vector3.BACK)
		_soft.face(rim, rim + along * .42 - width, rim + along, teal, Vector3.BACK)
		stem = tip

func _watch_light(at: Vector3) -> void:
	var lamp := MeshInstance3D.new()
	lamp.name = "WatchLight"
	var glass := CylinderMesh.new()
	glass.height = .16
	glass.top_radius = .095
	glass.bottom_radius = .123
	glass.radial_segments = 6
	lamp.mesh = glass
	lamp.material_override = LAMP
	lamp.position = at
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	_stone.block(at + Vector3.UP * .084, Vector3(.13, .05, .13), WOOD)
	_stone.block(at + Vector3.DOWN * .094, Vector3(.13, .045, .13), BRONZE)
	var glow := OmniLight3D.new()
	glow.position = at
	glow.light_color = Color("#ffc48e")
	glow.light_energy = 2.15
	glow.omni_range = 4.2
	glow.distance_fade_enabled = true
	glow.distance_fade_begin = 36.0
	glow.distance_fade_length = 8.0
	add_child(glow)

func _fallen_step(at: Vector3, wide: float, tint: Color) -> void:
	for step in 3:
		var p := at + Vector3(.11 * step, -.036 - .13 * step, step * .29)
		_stone.block(p, Vector3(wide * .50, .13, .15), tint.lightened(.10 * step), .09 * step)

func _leaf(at: Vector3, angle: float) -> void:
	var along := Vector3(cos(angle), .14, sin(angle)) * .15
	var edge := along.cross(Vector3.UP) * .37
	var tint := COPPER.lerp(RUST, _rng.randf())
	_soft.face(at - along, at + edge, at + along, tint, Vector3.UP)
	_soft.face(at + along, at - edge, at - along, tint.darkened(.18), Vector3.UP)

func _solid(at: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	collider.shape = bounds
	collider.position = at
	_collision.add_child(collider)

func _discovery(local: Vector3) -> void:
	# Keep the opening end of the recess inside the accessible part of the street.
	discovery_points.append(to_global(local))

func _lot(side: float, x: float, z: float, half: Vector2) -> Vector3:
	var radius := half.length()
	for offset: Vector2 in [Vector2.ZERO, Vector2(1.5, 0), Vector2(2.8, 1.6),
			Vector2(3.5, -1.7), Vector2(5.3, 2.4), Vector2(5.8, -2.8)]:
		var candidate := Vector3(side * (x + offset.x), 0, z + offset.y)
		var street := _street_sample(candidate)
		if street.x < radius + 2.3:
			continue
		var overlaps := false
		for existing in _lots:
			if Vector2(existing.x - candidate.x, existing.z - candidate.z).length() < existing.y + radius + .65:
				overlaps = true
				break
		if overlaps:
			continue
		_lots.append(Vector3(candidate.x, radius, candidate.z))
		candidate.y = street.y
		return candidate
	return Vector3.INF

func _street_sample(point: Vector3) -> Vector2:
	var world := to_global(point)
	var target := Vector2(world.x, world.z)
	var closest := INF
	var y := anchor.y
	for road: PackedVector3Array in _roads:
		for i in range(1, road.size()):
			var from := road[i - 1]
			var to := road[i]
			var left := Vector2(from.x, from.z)
			var step := Vector2(to.x, to.z) - left
			var length_sq := step.length_squared()
			if length_sq < .00001:
				continue
			var t := clampf((target - left).dot(step) / length_sq, 0.0, 1.0)
			var distance := target.distance_squared_to(left + step * t)
			if distance < closest:
				closest = distance
				y = lerpf(from.y, to.y, t)
	return Vector2(sqrt(closest), y - anchor.y)
