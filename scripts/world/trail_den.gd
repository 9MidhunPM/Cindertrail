extends Node3D
## A walkable shelf beside a through-road. Local +X points away from the safe road.
## Dormant silhouettes live here until the traveling core draws the pack out.

const ROCK_SHADER := preload("res://art/outer_valley/valley_pigment.gdshader")
const LIMESTONE := preload("res://art/textures/stylized/route_paint.png")
const BRUSH := preload("res://art/textures/stylized/valley_brush.png")
static var _stone: ShaderMaterial
const BEDS := [Vector2(7.0, 0.15), Vector2(6.0, -1.65), Vector2(7.8, 1.8)]
const RIM := [Vector2(.65, -1.22), Vector2(3.05, -1.78), Vector2(5.1, -3.3),
	Vector2(8.2, -3.4), Vector2(9.35, -2.1), Vector2(9.55, 1.2), Vector2(8.53, 3.3),
	Vector2(6.1, 3.05), Vector2(4.0, 2.05), Vector2(.65, 1.25)]
var key: String
var pack: Array[CinderEnemyStats] = []
var label: String
var defeated := 0
var claimed := false
var alerted := false
var must_leave := false
var scouting := false
var _grade := 0.0
var _resting: Dictionary[int, Node3D] = {}

func build(id: String, origin: Vector3, outward: Vector3, grade: float,
		members: Array[CinderEnemyStats], title: String, stone: Color, tint: Color) -> void:
	key = id
	label = title
	pack = members
	_grade = grade
	name = id
	transform = Transform3D(Basis(outward, Vector3.UP, outward.cross(Vector3.UP)), origin)
	var stonework := SurfaceTool.new()
	stonework.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper := PackedVector3Array()
	var lower := PackedVector3Array()
	var center := _top(Vector2(5.5, 0))
	for i in RIM.size():
		var point := _top(RIM[i])
		upper.append(point)
		lower.append(point.lerp(center, .14) - Vector3.UP * (1.2 + .22 * (i % 3)))
	for i in RIM.size():
		var next := (i + 1) % RIM.size()
		var a := upper[i]
		var b := upper[next]
		_triangle(stonework, center, a, b, stone.lightened(.02 * float(i % 3)), Vector3.UP)
		var outward_normal := ((a + b) * .5 - center).slide(Vector3.UP)
		_triangle(stonework, a, lower[i], lower[next], stone.darkened(.30), outward_normal)
		_triangle(stonework, a, lower[next], b, stone.darkened(.23 + .035 * float(i % 2)), outward_normal)
	# Three-toed tracks point from the road shoulder into the lair. A chipped outer
	# edge catches moonlight so the tracks remain legible without floating markers.
	for i in 7:
		var base := Vector2(1.6 + i * .68, (-.25 if i % 2 == 0 else .25) + sin(i * .8) * .23)
		for toe in [-1, 0, 1]:
			var foot := base + Vector2(0, toe * .115)
			var tip := foot + Vector2(.35 - abs(toe) * .06, toe * .078)
			_triangle(stonework, _top(foot - Vector2(0,.052)) + Vector3.UP * .018,
				_top(foot + Vector2(0,.052)) + Vector3.UP * .018,
				_top(tip) + Vector3.UP * .023, stone.darkened(.57), Vector3.UP)
	# Shed mineral scales in the creatures' joint color identify an occupied turnoff.
	for i in 7:
		var at := Vector2(3.0 + i * .71, (1.24 if i % 2 == 0 else -1.42) + cos(i) * .12)
		var p := _top(at)
		var peak := p + Vector3(.09, .23 + .12 * (i % 3), -.06)
		var base := [p + Vector3(-.15,0,-.10), p + Vector3(.16,0,-.04), p + Vector3(-.04,0,.13)]
		for face in 3:
			_triangle(stonework, base[face], base[(face+1)%3], peak, tint.darkened(.17 * face),
				((base[face] + base[(face+1)%3]) * .5 - p).slide(Vector3.UP))
	if _stone == null:
		_stone = ShaderMaterial.new()
		_stone.shader = ROCK_SHADER
		_stone.set_shader_parameter("route_paint", LIMESTONE)
		_stone.set_shader_parameter("brush_detail", BRUSH)
	stonework.set_material(_stone)
	var artwork := MeshInstance3D.new()
	artwork.mesh = stonework.commit()
	add_child(artwork)
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	# Match the rendered fan, including its shallow slope where it meets the road.
	var faces := PackedVector3Array()
	for i in upper.size():
		faces.append(center)
		faces.append(upper[i])
		faces.append(upper[(i + 1) % upper.size()])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)

func _top(at: Vector2) -> Vector3:
	return Vector3(at.x, .07 + at.y * _grade + .105 * at.x, at.y)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, towards: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.dot(towards) < 0.0:
		var swap := c
		c = b
		b = swap
		normal = -normal
	for point: Vector3 in [a, b, c]:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal(normal)
		surface.add_vertex(point)

func bed(index: int) -> Vector3:
	return to_global(_top(BEDS[index]))

func center() -> Vector3:
	return bed(0)

func all_defeated() -> bool:
	return defeated == (1 << pack.size()) - 1

func clear_resting() -> void:
	for actor: Node3D in _resting.values():
		actor.hide()
		actor.queue_free()
	_resting.clear()

func idle(visible_here: bool, clock: float) -> void:
	if not visible_here or alerted or claimed or must_leave:
		if not _resting.is_empty():
			clear_resting()
		return
	for i in pack.size():
		if defeated & (1 << i):
			continue
		if not _resting.has(i):
			var actor := pack[i].model.instantiate() as Node3D
			add_child(actor)
			actor.scale = Vector3.ONE * pack[i].model_scale
			actor.rotation.y = -1.1 + i * .44
			_resting[i] = actor
		var mesh: Node3D = _resting[i]
		var breath := clock * 1.5 + i * 2.2
		mesh.position = _top(BEDS[i]) + Vector3.UP * (.025 + sin(breath) * .022)
		mesh.rotation.x = cos(breath) * .018
		mesh.rotation.y = -1.1 + i * .44 + sin(breath * .43) * .11

func aimed_distance(origin: Vector3, aim: Vector3, reach: float) -> float:
	var nearest := INF
	for i: int in _resting:
		var middle := bed(i) + Vector3.UP * pack[i].height * .53
		var offset := middle - origin
		var distance := offset.dot(aim)
		if distance > 0.0 and distance <= reach and (offset - aim * distance).length() <= maxf(.85, pack[i].height):
			nearest = minf(nearest, distance)
	return nearest
