extends Node3D
## The old roof joins two existing causeways. The Grove reserve is its only saved state.

signal raised
signal opened
signal toll_requested(world_position: Vector3, submerged: bool)

const BELFRY := preload("res://scripts/world/drowned_belfry_mesh.gd")
const WATER_MARK := preload("res://scripts/fx/bell_road_water.gdshader")
const WATER_Y := .285
const DECK_HALF_WIDTH := 1.03
const SUNKEN_Y := -3.9
const RISE_SECONDS := 3.6

var route := PackedVector3Array()
var ruin_local: Vector3:
	get:
		return route[1] if route.size() > 1 else Vector3.ZERO
var awakened := false
var walkable := false
var _heard := false
var _model: Node3D
var _deck: StaticBody3D
var _pulse: MeshInstance3D
var _ripples: MeshInstance3D
var _rise: Tween
var _echo: Tween
var _tolled := false

func configure(journey_seed: int, shrine_local := Vector3(0, .73, 0)) -> void:
	if not route.is_empty():
		return
	var sockets: Dictionary = get_parent().bell_road_sockets()
	var start := to_local(sockets.start)
	var crest := to_local(sockets.ruin)
	var finish := to_local(sockets.end)
	# Two placements within each ruin footprint, using the very same permanent landings.
	var span := finish - start
	var side := Vector3(-span.z, 0, span.x).normalized()
	var variant := posmod(journey_seed, 2)
	crest += side * [-.48, .52][variant]
	crest.y = [1.56, 1.74][variant]
	route = PackedVector3Array([start, crest, finish])
	_model = BELFRY.new()
	_model.name = "DrownedBelfry"
	_model.position.y = SUNKEN_Y
	add_child(_model)
	_model.build(route)
	_build_deck()
	_build_water_marks(shrine_local)

func apply_reserve(remaining: float, capacity: float, animate: bool, reduced_motion := false) -> void:
	if route.is_empty() or capacity <= 0.0:
		return
	var unlocked := remaining <= capacity * .5 + .00001
	if not animate:
		# A restore can interrupt a reveal or load a checkpoint from before the draw.
		if _rise:
			_rise.kill()
		if _echo:
			_echo.kill()
		awakened = unlocked
		_heard = unlocked
		_tolled = unlocked
		_model.position.y = 0.0 if unlocked else SUNKEN_Y
		_set_walkable(unlocked)
		_pulse.hide()
		_ripples.hide()
		return
	if awakened or not unlocked:
		return
	awakened = true
	if _echo:
		_echo.kill()
	_pulse.visible = not reduced_motion
	_ripples.visible = not reduced_motion
	_set_fraction(0.0)
	raised.emit()
	_rise = create_tween()
	if reduced_motion:
		_rise.tween_interval(.20)
	else:
		_rise.tween_method(_set_fraction, 0.0, 1.0, RISE_SECONDS)
	_rise.tween_callback(_finish_lift)

func listen(world_position: Vector3) -> void:
	if _heard or awakened or route.is_empty():
		return
	if to_local(world_position).distance_to(route[1]) > 9.5:
		return
	_heard = true
	toll_requested.emit(to_global(route[1]), true)
	_ripples.show()
	var material := _ripples.material_override as ShaderMaterial
	material.set_shader_parameter("strength", .37)
	_echo = create_tween()
	_echo.tween_method(func(t: float) -> void: material.set_shader_parameter("progress", t), 0.0, 1.0, 1.9)
	_echo.tween_callback(_ripples.hide)

func _set_fraction(t: float) -> void:
	# The first beat travels out from the shrine. The masonry follows its arrival.
	_model.position.y = lerpf(SUNKEN_Y, 0.0, smoothstep(.23, .94, t))
	(_pulse.material_override as ShaderMaterial).set_shader_parameter("progress", clampf(t / .36, 0., 1.))
	var ripple_mat := _ripples.material_override as ShaderMaterial
	ripple_mat.set_shader_parameter("strength", .84)
	ripple_mat.set_shader_parameter("progress", clampf((t - .2) / .8, 0., 1.))
	if t >= .54 and not _tolled:
		_ring_belfry()

func _ring_belfry() -> void:
	_tolled = true
	_model.toll()
	toll_requested.emit(to_global(route[1]), false)

func _finish_lift() -> void:
	_model.position.y = 0.0
	if not _tolled:
		# Reduced motion keeps the sound cue but skips the visible bell swing.
		_tolled = true
		toll_requested.emit(to_global(route[1]), false)
	_pulse.hide()
	_ripples.hide()
	_set_walkable(true)
	opened.emit()

func _set_walkable(value: bool) -> void:
	walkable = value
	_deck.collision_layer = 1 if value else 0

func _build_deck() -> void:
	_deck = StaticBody3D.new()
	_deck.name = "RoadDeck"
	_deck.collision_layer = 0
	_deck.collision_mask = 0
	add_child(_deck)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in route.size():
		var incoming := route[i] - route[maxi(i - 1, 0)]
		var outgoing := route[mini(i + 1, route.size() - 1)] - route[i]
		var a := Vector3(-incoming.z, 0, incoming.x).normalized()
		var b := Vector3(-outgoing.z, 0, outgoing.x).normalized()
		var across := (a + b).normalized()
		var offset := across * DECK_HALF_WIDTH / across.dot(b if b != Vector3.ZERO else a)
		left.append(route[i] + offset)
		right.append(route[i] - offset)
	var faces := PackedVector3Array()
	for i in range(route.size() - 1):
		faces.append_array(PackedVector3Array([left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_deck.add_child(collision)

func _build_water_marks(shrine: Vector3) -> void:
	var target := route[1]
	target.y = WATER_Y + .018
	var origin := shrine + Vector3.UP * .36
	var side := Vector3(-(target.z - origin.z), 0, target.x - origin.x).normalized()
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 33:
		var t := i / 32.0
		var point := origin.lerp(target, t) + side * sin(t * PI) * .63
		# Stay above the shrine island until the light reaches the shallows.
		point.y = lerpf(origin.y, target.y, smoothstep(.35, .80, t))
		for j in 2:
			ribbon.set_uv(Vector2(t, j))
			ribbon.add_vertex(point + side * (j - .5) * .42)
	_pulse = _water_mark(ribbon.commit(), false)
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	_ripples = _water_mark(plane, true)
	_ripples.position = Vector3(target.x, WATER_Y, target.z)

func _water_mark(mesh: Mesh, radial: bool) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	mark.name = "BellRipples" if radial else "LightFromShrine"
	var material := ShaderMaterial.new()
	material.shader = WATER_MARK
	material.render_priority = 4
	material.set_shader_parameter("radial", radial)
	mark.material_override = material
	mark.mesh = mesh
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.hide()
	add_child(mark)
	return mark
