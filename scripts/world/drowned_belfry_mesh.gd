extends Node3D
## Masonry, metalwork and bell. The road controller supplies the walk surface in local coordinates.

const CHALK := preload("res://art/materials/stylized/painted_stone_light.tres")
const STONE := preload("res://art/materials/stylized/painted_stone_cream.tres")
const JOINT := preload("res://art/materials/stylized/painted_stone_shadow.tres")
const COPPER := preload("res://art/materials/stylized/painted_bronze.tres")
const GOLD := preload("res://art/materials/stylized/painted_brass.tres")
const DARK := preload("res://art/materials/stylized/painted_bronze_dark.tres")
const MOSS := preload("res://art/materials/stylized/route_moss.tres")
const MATS := [CHALK, STONE, JOINT, COPPER, GOLD, DARK, MOSS]
const HALF_WIDTH := 1.12

var _surfaces: Dictionary = {}
var _bell: MeshInstance3D
var _swing: Tween

func build(route: PackedVector3Array) -> void:
	if route.size() < 3:
		return
	if _swing:
		_swing.kill()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var sides := PackedVector3Array()
	for i in route.size():
		var before := _side(route[maxi(i - 1, 0)], route[i])
		var after := _side(route[i], route[mini(i + 1, route.size() - 1)])
		var side := (before + after).normalized()
		# Equal width through each bend; cap the miter on very acute corners.
		side /= maxf(.72, side.dot(after if i < route.size() - 1 else before))
		sides.append(side)
	for i in route.size() - 1:
		_walk_span(route[i], route[i + 1], sides[i], sides[i + 1], i)
	var middle := floori(route.size() / 2.0)
	var side := sides[middle].normalized()
	var frame := Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), route[middle])
	_tower(frame)
	_finish_mesh(self, "LimestoneAndCopper")
	var pivot := _arcade_frame(frame).translated_local(Vector3(0, 2.05, 0))
	_bell_metal()
	_bell = _finish_mesh(self, "TollingBell")
	_bell.transform = pivot

func toll(strength: float = 1.0) -> void:
	if not is_instance_valid(_bell):
		return
	if _swing:
		_swing.kill()
	_swing = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var peak := clampf(strength, 0, 1.5) * .42
	for factor in [1.0, -.71, .45, -.25, .11, 0.0]:
		_swing.tween_property(_bell, "rotation:z", peak * factor, .35)

func _side(a: Vector3, b: Vector3) -> Vector3:
	var delta := b - a
	return Vector3(delta.z, 0, -delta.x).normalized()

func _walk_span(a: Vector3, b: Vector3, sa: Vector3, sb: Vector3, index: int) -> void:
	var length := a.distance_to(b)
	if length < .02:
		return
	_deck_course(2, a, b, sa, sb, -HALF_WIDTH, HALF_WIDTH, -.13, -.40)
	for lane in 2:
		var x0 := -HALF_WIDTH + HALF_WIDTH * lane + .014
		var start := 0.0
		var block := index * 3 + lane
		while start < length - .002:
			var end := minf(length, start + (1.15 + .21 * sin(block * 3.7)) * (.55 if lane == 1 and start == 0 else 1.0))
			var gap := minf(.012, (end - start) * .1)
			var f0 := (start + gap) / length
			var f1 := (end - gap) / length
			_deck_course(0 if block % 5 == 1 else 1, a.lerp(b, f0), a.lerp(b, f1),
				sa.lerp(sb, f0), sa.lerp(sb, f1), x0, x0 + HALF_WIDTH - .028, 0, -.15)
			start = end
			block += 1
	for sign_x in [-1.0, 1.0]:
		var edge: float = HALF_WIDTH * sign_x
		_deck_course(3, a, b, sa, sb, edge - .064, edge + .064, -.18, -.26)
	var supports := floori(length / 3.8)
	for k in supports:
		var t := (k + .5) / supports
		var center := a.lerp(b, t)
		var side := sa.lerp(sb, t).normalized()
		var frame := Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), center)
		_block(2, frame, Vector3(0, -1.62, 0), Vector3(1.67, 2.55, .64), .12)
		_block(1, frame, Vector3(0, -.53, 0), Vector3(2.04, .27, .94), .1)

func _deck_course(mat: int, a: Vector3, b: Vector3, sa: Vector3, sb: Vector3,
		left: float, right: float, top: float, bottom: float) -> void:
	_extrude(mat, PackedVector3Array([a + left * sa, a + right * sa,
		b + right * sb, b + left * sb]), Vector3.UP * bottom, Vector3.UP * top)

func _tower(f: Transform3D) -> void:
	# The roof widens to an old bell terrace. The bell arcade stands alongside the through path.
	_block(2, f, Vector3(.35, -1.27, 0), Vector3(3.64, 2.1, 3.12), .34)
	_block(1, f, Vector3(.35, -.59, 0), Vector3(3.90, .23, 3.36), .35)
	_block(3, f, Vector3(.35, -.42, 0), Vector3(4.03, .12, 3.49), .38)
	_block(1, f, Vector3(.35, -.29, 0), Vector3(4.18, .20, 3.66), .39)
	for flank in [-1.0, 1.0]:
		for corner in [-1.0, 1.0]:
			var x: float = .35 + flank * 1.61
			var z: float = corner * 1.35
			_block(1, f, Vector3(x, -1.44, z), Vector3(.54, 2.0, .53), .10)
			_block(3, f, Vector3(x, -.88, z), Vector3(.58, .085, .57), .11)
	for i in 7:
		var z := (i - 3) * .44
		_block(3 if i % 3 else 5, f, Vector3(-1.42, -.15, z), Vector3(.66, .20, .427), .05)
		_block(3 if i % 4 else 5, f, Vector3(1.68, -.15, z), Vector3(1.08, .20, .427), .05)
	# One arcade survives. On the opposite eave only a wet, broken pier foot remains.
	_block(6, f, Vector3(-1.41, .065, -.91), Vector3(.44, .24, .48), .095)
	_block(1, f, Vector3(-1.42, .24, -.93), Vector3(.32, .15, .35), .07)
	var arcade := _arcade_frame(f)
	for sign_z in [-1.0, 1.0]:
		var z: float = sign_z * .73
		_block(0, arcade, Vector3(0, .115, z), Vector3(.68, .31, .69), .095)
		for j in 4:
			_block(0 if j == 1 else 1, arcade, Vector3(0, .435 + j * .324, z),
				Vector3(.40 + .04 * (j % 2), .314, .43), .045)
		_block(3, arcade, Vector3(0, 1.51, z), Vector3(.57, .095, .54), .065)
		_block(0, arcade, Vector3(0, 1.64, z), Vector3(.61, .18, .56), .073)
	for wedge in 9:
		var a := PI * wedge / 9 + .008
		var b := PI * (wedge + 1) / 9 - .008
		var r := 1.06 if wedge == 4 else .986
		var points := PackedVector3Array()
		for p in [Vector2(.55, a), Vector2(r, a), Vector2(r, b), Vector2(.55, b)]:
			points.append(arcade * Vector3(0, 1.73 + sin(p.y) * p.x, cos(p.y) * p.x))
		_extrude(0 if wedge == 4 or wedge == 1 else 1, points,
			arcade.basis.x * -.255, arcade.basis.x * .255)
	# A split verdigris crown and a gilded ridge tip break the surface first.
	_block(3, arcade, Vector3(0, 2.78, 0), Vector3(.63, .12, .52), .08)
	_block(4, arcade, Vector3(0, 2.90, -.04), Vector3(.20, .15, .19), .05)
	_block(5, arcade, Vector3(0, 2.10, 0), Vector3(.22, .15, 1.31), .035)
	_block(4, arcade, Vector3(0, 2.08, .47), Vector3(.24, .18, .08), .02)
	_block(4, arcade, Vector3(0, 2.08, -.47), Vector3(.24, .18, .08), .02)

func _arcade_frame(f: Transform3D) -> Transform3D:
	# The arcade faces diagonally so its opening reads from the incoming path and tactical view.
	return f.translated_local(Vector3(1.92, 0, 0)).rotated_local(Vector3.UP, deg_to_rad(-32))

func _bell_metal() -> void:
	# Radius and drop below axle. The return profile models a hollow mouth.
	var profile := [Vector2(.12, .03), Vector2(.13, -.16), Vector2(.21, -.22),
		Vector2(.29, -.28), Vector2(.32, -.40), Vector2(.36, -.66),
		Vector2(.45, -.82), Vector2(.52, -.87), Vector2(.525, -.93),
		Vector2(.437, -.94), Vector2(.40, -.82), Vector2(.24, -.45), Vector2(.04, -.31)]
	_lathe(profile, [5, 4, 5, 3, 3, 3, 4, 3, 4, 5, 5, 5], 20)
	_lathe([Vector2(.03, -.29), Vector2(.037, -.86), Vector2(.10, -.94),
		Vector2(.083, -1.04), Vector2(.02, -1.08)], [5, 4, 4, 5], 10)

func _lathe(profile: Array, materials: Array, steps: int) -> void:
	for j in profile.size() - 1:
		var p: Vector2 = profile[j]
		var q: Vector2 = profile[j + 1]
		for i in steps:
			var a := TAU * i / steps
			var b := TAU * (i + 1) / steps
			var da := Vector3(cos(a), 0, sin(a))
			var db := Vector3(cos(b), 0, sin(b))
			var normal := (da + db).normalized() * (p.y - q.y) + Vector3.UP * (q.x - p.x)
			_quad(materials[j], da * p.x + Vector3.UP * p.y, db * p.x + Vector3.UP * p.y,
				db * q.x + Vector3.UP * q.y, da * q.x + Vector3.UP * q.y, normal)

func _block(mat: int, f: Transform3D, center: Vector3, size: Vector3, bevel: float) -> void:
	var x := size.x * .5
	var z := size.z * .5
	var rim := PackedVector3Array()
	for p in [Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),Vector2(x,z-bevel),
			Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)]:
		rim.append(f * (center + Vector3(p.x, 0, p.y)))
	_extrude(mat, rim, Vector3.DOWN * size.y * .5, Vector3.UP * size.y * .5)

func _extrude(mat: int, rim: PackedVector3Array, low: Vector3, high: Vector3) -> void:
	var center := Vector3.ZERO
	for p in rim:
		center += p
	center /= rim.size()
	for i in rim.size():
		var p := rim[i]
		var q := rim[(i + 1) % rim.size()]
		_tri(mat, center + high, p + high, q + high, high - low)
		_tri(mat, center + low, p + low, q + low, low - high)
		_quad(mat, p + high, p + low, q + low, q + high, (p + q) * .5 - center)

func _quad(mat: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(mat, a, b, c, outward)
	_tri(mat, a, c, d, outward)

func _tri(mat: int, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.is_zero_approx():
		return
	var surface: SurfaceTool = _surfaces.get(mat)
	if not surface:
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(MATS[mat])
		_surfaces[mat] = surface
	var reverse := normal.dot(outward) > 0
	surface.set_normal(normal if reverse else -normal)
	surface.add_vertex(a)
	surface.add_vertex(c if reverse else b)
	surface.add_vertex(b if reverse else c)

func _finish_mesh(parent: Node3D, label: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for surface: SurfaceTool in _surfaces.values():
		surface.index()
		surface.commit(mesh)
	_surfaces.clear()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	parent.add_child(part)
	return part
