class_name CinderQuarry
extends Node3D

const DATA := preload("res://data/sites/quarry.tres")
const ARCH := preload("res://art/models/ruin_arch.glb")
const PILLAR := preload("res://art/models/ruin_pillar.glb")
const TREE := preload("res://art/models/orange_tree.glb")
const GROUND := Vector3(-53, 1.15, 0)
const TRAIL := [
	Vector3(-24.0, 0.68, 1.0), Vector3(-28.0, 0.68, 1.0),
	Vector3(-33.0, 0.82, 2.4), Vector3(-39.0, 1.02, 2.0),
	Vector3(-45.0, 1.15, 0.0), Vector3(-47.0, 1.15, 0.0),
]
const LIMESTONE := Color("#cbb28b")
const CHALK := Color("#ead4a9")
const SEDIMENT := Color("#796b60")
const SOIL := Color("#8f7962")
const TIMBER := Color("#63442d")
const BRONZE := Color("#936438")
const IRON := Color("#443e40")
const COPPER := Color("#bc652a")

var site: CinderSite
var caches := PackedVector3Array([Vector3(-36.0, 0.91, 5.76)])
var _rng := RandomNumberGenerator.new()
var _solid := StaticBody3D.new()
var _surf := SurfaceTool.new()

func _ready() -> void:
	_rng.seed = 41926
	_solid.name = "StaticQuarryCollision"
	add_child(_solid)
	_surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surf.set_smooth_group(-1)
	_build_trail()
	_build_court()
	_build_cut_faces()
	_build_crane(Vector3(-60.0, 1.15, -4.75), -0.66, 1.16)
	_build_crane(Vector3(-50.0, 2.55, -7.65), 0.48, 0.8)
	_finish_geometry()
	_configure_site()

func _configure_site() -> void:
	site = CinderSite.new()
	site.name = "BrokenQuarrySite"
	var sockets := PackedVector3Array([
		Vector3(-55.0, 1.18, -2.58), Vector3(-50.1, 1.18, -3.0),
		Vector3(-51.0, 1.18, 2.9), Vector3(-57.0, 1.18, 2.45),
	])
	var lane := PackedVector3Array([
		Vector3(-68, 1.15, -0.5), Vector3(-65, 1.15, 0.15),
		Vector3(-61.0, 1.15, 0.15), Vector3(-57.5, 1.15, -0.6), GROUND,
	])
	site.configure(DATA, GROUND, sockets, [lane],
		Vector3(-58.7, 13.4, 16.1), Vector3(-55.6, 0.93, 0.0))
	add_child(site)

func _build_trail() -> void:
	for index in range(TRAIL.size() - 1):
		var from: Vector3 = TRAIL[index]
		var to: Vector3 = TRAIL[index + 1]
		var width := 3.1 + float(index) * 0.37
		_span_floor(from, to, width)
		var direction := to - from
		direction.y = 0.0
		var side := direction.normalized().cross(Vector3.UP)
		var count := ceili(direction.length() / 0.93)
		for row in range(count):
			var start := from.lerp(to, float(row) / count)
			var end := from.lerp(to, float(row + 1) / count)
			for col in range(3):
				var begin_offset := side * width * (float(col) / 3.0 - .5)
				var end_offset := side * width * (float(col + 1) / 3.0 - .5)
				_tile(start + begin_offset, start + end_offset, end + end_offset, end + begin_offset, _stone())
		if index > 0:
			for shoulder in [-1.0, 1.0]:
				var offset: Vector3 = side * shoulder * (width * .5 + .65)
				var bank := (from + to) * .5 + offset
				_rock(bank - Vector3.UP * .50, Vector3(direction.length() * .60, .7, 1.48), SEDIMENT)
				_rocks_and_grass(from + offset, index + 2)
	# The supply ledge opens to the south without pinching the main passage.
	var turn := Vector3(-36.0, 0.92, 2.0)
	var alcove := Vector3(-36.0, 0.92, 6.5)
	_span_floor(turn, alcove, 3.0)
	_slab(Vector3(-36.0, .9, 5.25), Vector2(3.15, 3.15), .39, LIMESTONE)
	_rock(Vector3(-37.5, .2, 6.8), Vector3(1.8, 1.45, 1.5), SEDIMENT)
	_rock(Vector3(-34.3, .36, 6.2), Vector3(1.22, 1.78, .98), LIMESTONE)
	_lantern(Vector3(-34.45, .93, 5.8))
	_asset(ARCH, Vector3(-31.15, 0.72, 1.9), Vector3(1.37, 1.46, 1.22), PI * 0.5)
	for z in [0.28, 3.52]:
		_box_shape(Vector3(-31.15, 1.85, z), Vector3(0.54, 2.35, 0.46))
	_asset(TREE, Vector3(-39.0, 1.0, 5.7), Vector3.ONE * 1.36, 1.6)
	_lantern(Vector3(-40.1, 1.03, 3.62))
	_lantern(Vector3(-45.5, 1.15, -2.55))

func _build_court() -> void:
	_box_shape(Vector3(-53.75, .56, 0.03), Vector3(13.7, 1.18, 9.5))
	_box_shape(Vector3(-64.18, .56, -0.18), Vector3(8.4, 1.18, 4.0))
	_slab(Vector3(-53.75, 1.06, 0.03), Vector2(13.65, 9.45), 1.22, SOIL)
	_slab(Vector3(-64.18, 1.06, -0.18), Vector2(8.36, 3.96), 1.0, SEDIMENT)
	for row in range(17):
		var x := -68.1 + float(row) * 1.22
		var width := 2.0 if x < -60.25 else 4.65
		var sections := 4 if x < -60.25 else 8
		for col in range(sections):
			var z := -width + float(col) * width * 2.0 / sections
			var next := z + width * 2.0 / sections
			var height := _rng.randf_range(1.12, 1.149)
			var break_line := .20 * sin(z * 2.35 + row * .9)
			var end_break := .20 * sin(next * 2.35 + row * .9)
			var end_line := .20 * sin(z * 2.35 + (row + 1) * .9)
			var end_next := .20 * sin(next * 2.35 + (row + 1) * .9)
			_tile(Vector3(x + break_line, height, z), Vector3(x + end_break, height, next),
				Vector3(x + 1.20 + end_next, height, next), Vector3(x + 1.20 + end_line, height, z), _stone())
	# A weathered inlaid sundial surrounds the deployment anchor.
	var radius := 1.45
	for step in range(28):
		var a := TAU * step / 28.0
		var b := TAU * (step + 1) / 28.0
		var inset := GROUND + Vector3.UP * .017
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		_quad(inset + p * (radius - .08), inset + p * radius,
			inset + q * radius, inset + q * (radius - .08), BRONZE, Vector3.UP)
	for step in range(8):
		var a := TAU * step / 8.0
		var p := Vector3(cos(a), 0, sin(a))
		var side := p.cross(Vector3.UP) * .037
		var base := GROUND + p * 1.13 + Vector3.UP * .019
		_tri(base - side, base + side, base + p * .2, BRONZE, Vector3.UP)
	_lantern(Vector3(-59.5, 1.15, 2.6))
	_lantern(Vector3(-51.3, 1.15, -4.25))
	_lantern(Vector3(-64.0, 1.15, -1.72))

func _build_cut_faces() -> void:
	# Inner ledges enforce the western choke. Upper terraces add tall silhouettes behind it.
	_rock_wall(-68.7, -61.2, -3.05, 4.6, 1.64)
	_rock_wall(-68.5, -61.0, 2.65, 1.16, 1.1)
	_rock_wall(-61.6, -44.0, -6.25, 5.3, 1.58)
	_rock_wall(-59.7, -45.2, 5.87, 1.28, 1.30)
	_rock_wall(-67.9, -46.2, -10.25, 8.05, 2.32)
	_rock_wall(-65.0, -38.6, 11.0, 2.15, 2.7)
	_build_scree()
	_rock_wall(-44.4, -32.75, -2.68, 2.75, 1.70)
	_rock_wall(-39.5, -27.4, -2.15, 1.87, 1.52)
	for i in range(22):
		var z: float = [-1.0, 1.0][i % 2] * _rng.randf_range(5.15, 7.3)
		var p := Vector3(_rng.randf_range(-61, -44), 1.15, z)
		_rocks_and_grass(p, 3)
	_asset(PILLAR, Vector3(-58.55, 1.15, -4.42), Vector3(1.12, 1.57, 1.12), .07)
	_asset(PILLAR, Vector3(-46.76, 1.15, -3.77), Vector3(1.1, 1.36, 1.1), .17)
	_asset(TREE, Vector3(-43.1, 1.15, -5.55), Vector3.ONE * 1.32, 1.8)
	_asset(TREE, Vector3(-64.3, 1.2, 7.3), Vector3.ONE * 1.17, .4)

func _build_scree() -> void:
	# Below the carved terraces, broad sloping slabs connect the tall faces to the valley.
	for i in range(7):
		var x := -70.0 + float(i) * 5.3
		for side in [-1.0, 1.0]:
			var ledge := Vector3(x, -3.6, side * 8.1)
			_rock(ledge, Vector3(5.0, 4.0, 7.4), SEDIMENT.lerp(LIMESTONE, .23))
			var skirt := Vector3(x + 2.2, -8.4, side * 11.5)
			_rock(skirt, Vector3(6.9, 5.5, 10.0), Color("#46526a"))
	_rock(Vector3(-71.2, -3.9, -0.1), Vector3(5.2, 4.2, 5.1), SEDIMENT)

func _rock_wall(west: float, east: float, z: float, height: float, width: float) -> void:
	var step := 2.04
	var count := ceili((east - west) / step)
	for i in range(count):
		var x := lerpf(west, east, (float(i)+.48) / count)
		var varied_height := height * _rng.randf_range(.66, 1.16)
		var offset_z := _rng.randf_range(-.27, .27)
		var origin := Vector3(x, .6, z + offset_z)
		_rock(origin, Vector3(1.40, varied_height, width), _stone())
		_box_shape(origin + Vector3.UP * (varied_height * .42), Vector3(2.14, varied_height, width * 1.66))
		if height > 4.3:
			var ledge := origin + Vector3(0.16, varied_height * .53, signf(z) * .69)
			_rock(ledge, Vector3(1.39, varied_height * .60, width * .79), LIMESTONE.lightened(.06))
		if i % 2 == 0:
			var split := origin + Vector3(.52, .08, -signf(z) * width * .65)
			_rock(split, Vector3(.68, varied_height * .55, width * .57), SEDIMENT.lerp(LIMESTONE, .58))

func _build_crane(base: Vector3, rotation_y: float, scale_factor: float) -> void:
	var transform_crane := Transform3D(Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor), base)
	var front := transform_crane * Vector3(0, 4.5, 3.7)
	var rear := transform_crane * Vector3(0, 4.5, -1.52)
	_slab(base + Vector3.UP * .04, Vector2(1.6, 1.67) * scale_factor, .4, SEDIMENT)
	for side in [-1.0, 1.0]:
		var shoulder := transform_crane * Vector3(side * .31, 4.48, -.16)
		var foot := transform_crane * Vector3(side * .44, 0, -.31)
		_bar(foot, shoulder, .35 * scale_factor, TIMBER)
		_bar(transform_crane * Vector3(side * .41, .12, -1.55), shoulder, .22 * scale_factor, TIMBER)
		_bar(transform_crane * Vector3(side * .36, 2.45, -.16), transform_crane * Vector3(side * .23, 4.45, 2.79), .26 * scale_factor, TIMBER)
		for height in [1.13, 3.02, 4.27]:
			var collar := transform_crane * Vector3(side * .35, height, -.18)
			_rock(collar - Vector3.UP * .09, Vector3(.23, .18, .24) * scale_factor, BRONZE)
	_bar(rear, front, .32 * scale_factor, TIMBER.lightened(.07))
	_bar(rear + Vector3.UP * .24, front + Vector3.UP * .24, .07 * scale_factor, IRON)
	_bar(front, front - Vector3.UP * (2.15 * scale_factor), .031 * scale_factor, IRON)
	_rock(front - Vector3.UP * (2.58 * scale_factor), Vector3(.50, .45, .38) * scale_factor, LIMESTONE)
	_rock(rear - Vector3.UP * .71, Vector3(.43, .73, .48) * scale_factor, SEDIMENT)
	_bar(transform_crane * Vector3(-.62, 2.75, -.26), transform_crane * Vector3(.61, 2.75, -.26), .12, BRONZE)
	# A hanging caution pennant and brass keeper distinguish the moving end.
	var pole := transform_crane * Vector3(.46, 4.20, 2.34)
	var hem := transform_crane * Vector3(.58, 3.32, 2.23)
	_quad(pole, pole + Vector3.FORWARD * .35, hem + Vector3.FORWARD * .35, hem, COPPER, Vector3.RIGHT)
	_quad(pole, pole + Vector3.FORWARD * .35, hem + Vector3.FORWARD * .35, hem, COPPER.darkened(.13), Vector3.LEFT)
	_box_shape(base + Vector3.UP * .85, Vector3(1.15, 1.7, .83) * scale_factor)

func _lantern(base: Vector3) -> void:
	var top := base + Vector3.UP * 1.46
	_bar(base, top, .11, TIMBER)
	_bar(top, top + Vector3.RIGHT * .38, .10, BRONZE)
	var lantern_position := top + Vector3(.32, -.28, 0.0)
	_bar(top + Vector3.RIGHT * .32, lantern_position, .043, IRON)
	var glow := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = .105
	body.bottom_radius = .122
	body.height = .19
	body.radial_segments = 6
	glow.mesh = body
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#c47827")
	material.emission_enabled = true
	material.emission = Color("#ffae4e")
	material.emission_energy_multiplier = 1.45
	glow.material_override = material
	glow.position = lantern_position
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var lamp := OmniLight3D.new()
	lamp.position = lantern_position
	lamp.omni_range = 3.0
	lamp.light_energy = .66
	lamp.light_color = Color("#ffb368")
	add_child(lamp)

func _rocks_and_grass(center: Vector3, count: int) -> void:
	for i in range(count):
		var p := center + Vector3(_rng.randf_range(-.85, .85), 0, _rng.randf_range(-.48, .47))
		var scale_factor := _rng.randf_range(.09, .29)
		_rock(p - Vector3.UP * .077, Vector3(1.46, .7, 1.07) * scale_factor, _stone().darkened(.1))
		var grass := p + Vector3(.12, .017, -.07)
		for blade in range(4):
			var angle := _rng.randf() * TAU
			var forward := Vector3(cos(angle), 0, sin(angle))
			var side := forward.cross(Vector3.UP) * .025
			var point := grass + Vector3.UP * _rng.randf_range(.13, .34) + forward * .10
			var hue := Color("#806f44").lerp(Color("#b69a53"), _rng.randf())
			_tri(grass - side, grass + side, point, hue, forward)
			_tri(grass - side, grass + side, point, hue, -forward)

func _span_floor(a: Vector3, b: Vector3, width: float) -> void:
	var along := b - a
	var across := along.cross(Vector3.UP).normalized()
	var up := across.cross(along).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, .62, along.length() + .15)
	var body := CollisionShape3D.new()
	body.shape = shape
	body.transform = Transform3D(Basis(-across, up, along.normalized()), (a + b) * .5 - up * .31)
	_solid.add_child(body)
	var left := across * width * .5
	_quad(a - left - up * .037, a + left - up * .037, b + left - up * .037,
		b - left - up * .037, SEDIMENT, Vector3.UP)
	for side in [-1.0, 1.0]:
		var p: Vector3 = a + left * side
		var q: Vector3 = b + left * side
		_quad(p - up * .62, q - up * .62, q, p, SEDIMENT, across * side)

func _tile(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var center := (a + b + c + d) * .25
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	for corner in [a, b, c, d]:
		var jitter := Vector3(_rng.randf_range(-.045, .045), 0, _rng.randf_range(-.048, .048))
		top.append(corner.lerp(center, .042) + jitter)
		bottom.append(corner.lerp(center, .013) + jitter - Vector3.UP * .065)
	_quad(top[0], top[1], top[2], top[3], color, Vector3.UP)
	for i in range(4):
		var j := (i + 1) % 4
		_quad(top[i], top[j], bottom[j], bottom[i], color.darkened(.16), (top[i] + top[j]) * .5 - center)

func _slab(top_center: Vector3, size: Vector2, depth: float, color: Color) -> void:
	var x := Vector3.RIGHT * size.x * .5
	var z := Vector3.BACK * size.y * .5
	var a := top_center - x - z
	var b := top_center + x - z
	var c := top_center + x + z
	var d := top_center - x + z
	var below := Vector3.DOWN * depth
	_quad(a, b, c, d, color, Vector3.UP)
	_quad(a, a + below, b + below, b, color.darkened(.18), Vector3.FORWARD)
	_quad(b, b + below, c + below, c, color.darkened(.24), Vector3.RIGHT)
	_quad(c, c + below, d + below, d, color.darkened(.18), Vector3.BACK)
	_quad(d, d + below, a + below, a, color.darkened(.25), Vector3.LEFT)

func _rock(origin: Vector3, size: Vector3, color: Color) -> void:
	var lower := PackedVector3Array()
	var shoulder := PackedVector3Array()
	var cap := PackedVector3Array()
	var turn := _rng.randf_range(-.2, .2)
	var slope := Vector3(_rng.randf_range(-.15, .15) * size.x, 0, _rng.randf_range(-.18, .18) * size.z)
	for i in range(7):
		var angle := TAU * i / 7.0 + turn
		var shift := Vector3(cos(angle) * size.x, 0, sin(angle) * size.z)
		lower.append(origin + shift * _rng.randf_range(.79, 1.12))
		shoulder.append(origin + shift * _rng.randf_range(.86, 1.04) + Vector3.UP * size.y * _rng.randf_range(.58, .82))
		cap.append(origin + shift * _rng.randf_range(.48, .69) + slope + Vector3.UP * size.y * _rng.randf_range(.88, 1.04))
	for i in range(7):
		var j := (i + 1) % 7
		var out := (lower[i] + lower[j]) * .5 - origin
		var shade := color.lerp(SEDIMENT, _rng.randf_range(.08, .32))
		_quad(lower[i], lower[j], shoulder[j], shoulder[i], shade, out)
		_quad(shoulder[i], shoulder[j], cap[j], cap[i], shade.lightened(.065), (out + Vector3.UP).normalized())
		_tri(cap[i], cap[j], origin + slope + Vector3.UP * size.y, color.lightened(.16), Vector3.UP)

func _bar(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var forward := (b - a).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < .5:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var x := right * width * .5
	var y := up * width * .5
	var corners := [x + y, x - y, -x - y, -x + y]
	for i in range(4):
		var j := (i + 1) % 4
		_quad(a + corners[i], b + corners[i], b + corners[j], a + corners[j],
			color.lightened(.056 * i), corners[i] + corners[j])
	_quad(a + corners[0], a + corners[1], a + corners[2], a + corners[3], color, -forward)
	_quad(b + corners[0], b + corners[1], b + corners[2], b + corners[3], color, forward)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	_tri(a, b, c, color, outward)
	_tri(a, c, d, color, outward)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.00000001:
		return
	var vertices := [a, b, c] if normal.dot(outward) >= 0.0 else [a, c, b]
	for vertex in vertices:
		_surf.set_color(color)
		_surf.add_vertex(vertex)

func _box_shape(center: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = center
	_solid.add_child(collider)

func _stone() -> Color:
	return LIMESTONE.lerp(CHALK, _rng.randf_range(.02, .73)).darkened(_rng.randf_range(0, .13))

func _asset(scene: PackedScene, at: Vector3, scale_factor: Vector3, yaw: float) -> void:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.scale = scale_factor
	model.rotation.y = yaw
	add_child(model)

func _finish_geometry() -> void:
	_surf.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = _surf.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = .92
	mesh.material_override = material
	add_child(mesh)
