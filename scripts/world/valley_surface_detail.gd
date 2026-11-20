extends RefCounted
## Small non-colliding details baked into the hand-built districts.

const CHALK := Color("#dac9ad")
const STONE_EDGE := Color("#b09d89")
const QUARRY_SEAM := Color("#735b58")
const GROVE_LICHEN := Color("#526c50")
const GROVE_STONE := Color("#9bafa0")
const LEAF_COPPER := Color("#cf7537")

static func split_slab(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	# The narrow diagonal reveals the dark supporting course between the two faces.
	var first := polygon[0]
	var far := polygon[4]
	var bend := first.lerp(far, .53) + (far - first).orthogonal() * .074
	var broad := PackedVector2Array([first, polygon[1], polygon[2], polygon[3], far, bend])
	var broken := PackedVector2Array([first, bend, far, polygon[5], polygon[6], polygon[7]])
	return [_open_joint(broad, .017), _open_joint(broken, .034)]

static func _open_joint(polygon: PackedVector2Array, gap: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= polygon.size()
	for i in polygon.size():
		polygon[i] = polygon[i].move_toward(center, gap)
	return polygon

static func grove_arch_chips(origin: Vector3, yaw: float, scale_factor: float, face: Callable) -> void:
	var placement := Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3.ONE * scale_factor), origin)
	var front := placement.basis.z.normalized()
	for index in [1, 3, 6, 8, 10]:
		var angle := PI * (float(index) + .43) / 11.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var tangent := Vector3(-radial.y, radial.x, 0)
		# A spall starts at the chamfer and steps inward off the grain of each block.
		var lip := Vector3(0, 1.30, .254 + .009 * (index % 3)) + radial * (1.31 + .024 * sin(index))
		var tongue := lip - radial * .17 + tangent * .021
		var fleck := tongue - radial * .057 - tangent * .064
		var left := lip - tangent * .081
		var right := lip + tangent * .046 - radial * .04
		face.call(placement * left, placement * right, placement * tongue, STONE_EDGE.darkened(.10), front)
		face.call(placement * left, placement * tongue, placement * fleck, CHALK, front)
		if index % 2 != 0:
			var stain := tongue + Vector3.BACK * .012 - tangent * .055
			face.call(placement * stain, placement * (stain - radial * .051),
				placement * (stain - radial * .073 + tangent * .067), GROVE_LICHEN, front)

static func grove_waterline(face: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 312804
	var shelves := [Vector3(-1.2, .26, 16.7), Vector3(-.80, .26, 12.0),
		Vector3(-1.25, .26, 9.4), Vector3(1.98, .26, 3.82),
		Vector3(-4.91, .26, 16.6), Vector3(-4.46, .26, 11.2), Vector3(-7.69, .26, 7.64)]
	for stone in shelves:
		for index in 3:
			var center: Vector3 = stone + Vector3((index - 1) * .31, -.06, rng.randf_range(-.29, .29))
			var rim := PackedVector3Array()
			var top := center + Vector3.UP * rng.randf_range(.11, .22)
			for corner in 6:
				var angle := TAU * (corner + .32) / 6.0
				rim.append(center + Vector3(cos(angle) * .33, rng.randf_range(-.04, .04),
					sin(angle) * .47) * rng.randf_range(.8, 1.25))
			for corner in rim.size():
				var next := (corner + 1) % rim.size()
				var tone := GROVE_STONE if corner % 3 == 0 else GROVE_LICHEN
				face.call(top, rim[corner], rim[next], tone.lightened(rng.randf_range(.04, .16)), Vector3.UP)
		for leaf in 12:
			var center: Vector3 = stone + Vector3(rng.randf_range(-.48, .42), .02, rng.randf_range(-.68, .69))
			var heading := rng.randf() * TAU
			var blade := Vector3(cos(heading), 0, sin(heading)) * rng.randf_range(.066, .137)
			var fold := blade.cross(Vector3.UP) * .34
			var tint := LEAF_COPPER.lerp(Color("#b79146"), rng.randf_range(-.12, .47))
			var ridge := center + Vector3.UP * .018
			face.call(center - blade, center + fold, ridge, tint.darkened(.19), Vector3.UP)
			face.call(center + fold, center + blade, ridge, tint, Vector3.UP)
			face.call(center + blade, center - fold, ridge, tint.lightened(.09), Vector3.UP)
			face.call(center - fold, center - blade, ridge, tint, Vector3.UP)

static func quarry_cut_face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
		tint: Color, face: Callable) -> void:
	var first := a.lerp(d, _strata_level(a))
	var second := b.lerp(c, _strata_level(b))
	var cliff_height := (d.y - a.y + c.y - b.y) * .5
	var width := clampf(.09 / maxf(cliff_height, .18), .035, .19)
	var upper_first := a.lerp(d, _strata_level(a) + width)
	var upper_second := b.lerp(c, _strata_level(b) + width)
	var notch := first.lerp(second, .61)
	var middle := upper_first.lerp(upper_second, .61) + outward.normalized() * minf(.17, cliff_height * .10)
	var crown := d.lerp(c, .61)
	face.call(a, b, second, first, tint.lerp(QUARRY_SEAM, .12), outward)
	face.call(first, notch, middle, upper_first, tint.lerp(QUARRY_SEAM, .41), outward)
	face.call(notch, second, upper_second, middle, tint.lerp(QUARRY_SEAM, .55), outward)
	face.call(upper_first, middle, crown, d, tint.lerp(CHALK, .24), outward)
	face.call(middle, upper_second, c, crown, tint.lerp(CHALK, .10), outward)

static func _strata_level(point: Vector3) -> float:
	return .36 + sin(point.x * .93 + point.z * 1.22) * .11

static func attach_relay(parent: Node3D) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[PackedVector3Array] = []
	var columns := 54
	# Three stepped walls and their bench tops break up the sky below the horizon.
	for row in 9:
		var points := PackedVector3Array()
		for column in columns:
			var x := -156.0 + column * 6.4
			var phase := floorf(row * .5) * .67
			var z := -101.0 - row * 13.2 + sin(x * .058 + phase) * 7.2
			z -= cos(x * .109 - phase) * 2.75
			var valley := exp(-pow((x + 20.0 - row * 5.4) / (19.0 + row * 2.2), 2.0))
			var terrace := floorf((row + 1) * .5) * 5.1 if row % 2 == 1 else floorf(row * .5) * 5.1 + 1.7
			var flank := absf(sin(x * .046 + phase) * cos(x * .128 + phase * 1.83))
			var y := -8.0 + terrace * (1.0 - valley * .97) + pow(flank, 1.5) * (2.1 + terrace * .33)
			if row == 0:
				z = minf(z, -96.5)
			points.append(Vector3(x, y, z))
		grid.append(points)

	var ledges := [Color("#253f5b"), Color("#22456a"), Color("#315c7b"), Color("#426f97")]
	for row in range(grid.size() - 1):
		for column in range(columns - 1):
			var a := grid[row][column]
			var b := grid[row][column + 1]
			var c := grid[row + 1][column + 1]
			var d := grid[row + 1][column]
			var palette: Color = ledges[mini(floori(row * .5), ledges.size() - 1)]
			var tint := palette.lightened(.030 + .052 * sin(column * 2.2 + row))
			if row % 2 == 0:
				tint = tint.darkened(.34)
			_land_face(tool, a, b, c, tint)
			_land_face(tool, a, c, d, tint.lightened(.075))
			if row % 2 == 0 and column % 3 != 1 and a.distance_to(d) > 7.0:
				var stand := a.lerp(c, .39) - Vector3.UP * .24
				var spread := 1.25 + .33 * absf(sin(column * 2.4))
				_distant_fir(tool, stand, spread, palette.darkened(.56))
				_distant_fir(tool, stand + Vector3(1.93, 0, .51), spread * .64, palette.darkened(.48))
				if row < 4:
					_distant_fir(tool, stand + Vector3(-1.48, -.09, 1.14), spread * .83, palette.darkened(.63))
	var shelf := MeshInstance3D.new()
	shelf.name = "RelayDistantValleyTerraces"
	shelf.mesh = tool.commit()
	shelf.visibility_range_end = 220.0
	shelf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pigment := StandardMaterial3D.new()
	pigment.vertex_color_use_as_albedo = true
	pigment.vertex_color_is_srgb = true
	pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pigment.cull_mode = BaseMaterial3D.CULL_DISABLED
	shelf.material_override = pigment
	parent.add_child(shelf)

static func _land_face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

static func _distant_fir(tool: SurfaceTool, root: Vector3, size: float, tint: Color) -> void:
	for spine in [Vector3.RIGHT, Vector3.FORWARD]:
		for tier in 3:
			var mid := root + Vector3.UP * (.36 + .61 * tier) * size
			var tip := mid + Vector3.UP * 1.16 * size
			var width: Vector3 = spine * (.68 - tier * .14) * size
			_land_face(tool, mid - width, tip, mid + width, tint.lightened(.047 * tier))
