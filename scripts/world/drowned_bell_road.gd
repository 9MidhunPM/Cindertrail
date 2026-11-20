extends Node3D
## The old roof joins two existing causeways. The Grove reserve is its only saved state.

signal raised
signal opened
signal toll_requested(world_position: Vector3, submerged: bool)

const BELFRY := preload("res://scripts/world/drowned_belfry_mesh.gd")
const WATER_MARK := preload("res://scripts/fx/bell_road_water.gdshader")
const WATER_Y := .285
const DECK_HALF_WIDTH := 1.11
const SUNKEN_Y := -2.82
const RISE_SECONDS := 3.6

var route := PackedVector3Array()
var ruin_local: Vector3:
	get:
		return route[1] if route.size() > 1 else Vector3.ZERO
var awakened := false
var walkable := false
var _deck_profile := PackedVector3Array()
var _shrine_local := Vector3.ZERO
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
	# The western landing passes a surviving pillar at (-8.4, 4.7).
	# Both of its spans swing toward the inner pool to clear the stone plinth.
	var offsets := Vector2(.98, 1.86) if crest.z > 0.0 else Vector2(-.48, .52)
	crest += side * offsets[variant]
	crest.y = [1.56, 1.74][variant]
	route = PackedVector3Array([start, crest, finish])
	# The toes overlap the old paving flush so a traveler approaching from the side
	# can join either road without catching against the edge of the raised slope.
	var entry_toe := start.move_toward(crest, 1.85)
	entry_toe.y = start.y + .018
	var exit_toe := finish.move_toward(crest, 2.45)
	exit_toe.y = finish.y + .018
	_deck_profile = PackedVector3Array([start, entry_toe, crest, exit_toe, finish])
	_model = BELFRY.new()
	_model.name = "DrownedBelfry"
	_model.position.y = SUNKEN_Y
	add_child(_model)
	_model.build(_deck_profile)
	_build_deck()
	_shrine_local = shrine_local
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
	var listener := to_local(world_position)
	var distance := listener.distance_to(ruin_local)
	if distance > 9.5 and (listener.distance_to(_shrine_local) > 7.0 or distance > 17.0):
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
	(_pulse.material_override as ShaderMaterial).set_shader_parameter("progress", clampf(t / .42, 0., 1.))
	var ripple_mat := _ripples.material_override as ShaderMaterial
	ripple_mat.set_shader_parameter("strength", .84)
	ripple_mat.set_shader_parameter("progress", clampf((t - .31) / .69, 0., 1.))
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
	for i in _deck_profile.size():
		var incoming := _deck_profile[i] - _deck_profile[maxi(i - 1, 0)]
		var outgoing := _deck_profile[mini(i + 1, _deck_profile.size() - 1)] - _deck_profile[i]
		var a := Vector3(-incoming.z, 0, incoming.x).normalized()
		var b := Vector3(-outgoing.z, 0, outgoing.x).normalized()
		var across := (a + b).normalized()
		var offset := across * DECK_HALF_WIDTH / across.dot(b if b != Vector3.ZERO else a)
		left.append(_deck_profile[i] + offset)
		right.append(_deck_profile[i] - offset)
	var faces := PackedVector3Array()
	var rows := [left, _deck_profile, right]
	for lane in 2:
		var a: PackedVector3Array = rows[lane]
		var b: PackedVector3Array = rows[lane + 1]
		for i in range(_deck_profile.size() - 1):
			faces.append_array(PackedVector3Array([a[i], b[i], b[i + 1], a[i], b[i + 1], a[i + 1]]))
	# The old tolling terrace has a paved shoulder on each side of the main roof.
	# Only its upward-facing surfaces are solid, so travelers can still wade underneath.
	var across_terrace := (right[2] - left[2]).normalized()
	var along_terrace := across_terrace.cross(Vector3.UP)
	for shoulder: Vector2 in [Vector2(-1.73, -1.02), Vector2(1.02, 2.22)]:
		var inner := ruin_local + across_terrace * shoulder.x - Vector3.UP * .055
		var outer := ruin_local + across_terrace * shoulder.y - Vector3.UP * .055
		var depth := along_terrace * 1.52
		faces.append_array(PackedVector3Array([inner - depth, outer - depth, outer + depth,
			inner - depth, outer + depth, inner + depth]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_deck.add_child(collision)

func _build_water_marks(shrine: Vector3) -> void:
	var target := route[1]
	target.y = WATER_Y + .018
	var origin := shrine + Vector3.UP * .36
	var shore_fraction := clampf(5.5 / Vector2(target.x - origin.x, target.z - origin.z).length(), .2, .86)
	var side := Vector3(-(target.z - origin.z), 0, target.x - origin.x).normalized()
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 33:
		var t := i / 32.0
		var point := origin.lerp(target, t) + side * sin(t * PI) * .63
		# Stay above the shrine island until the light reaches the shallows.
		point.y = lerpf(origin.y, target.y, smoothstep(shore_fraction, minf(.98, shore_fraction + .16), t))
		for j in 2:
			ribbon.set_uv(Vector2(t, j))
			ribbon.add_vertex(point + side * (j - .5) * .83)
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
