extends CinderEnemy
## The guardian holds the crown. Its marked charge ends short of the cradle;
## only an uninterrupted ground pulse can wound the sun.
enum Phase { MARK, CHARGE, BRACE, PULSE, OPEN, RETURN }
const LENGTHS := [1.65, 1.25, 1.65, 0.85, 3.2, 2.3]
const PLATE := Color("#d492ef")
const EXPOSED := Color("#ffe3a0")
const INTERRUPT_POWER := 4.0

signal cue_requested(cue: String)
signal fell
var phase := Phase.MARK
var _east_lane := false
var elapsed := 0.0
var _brace_hits := 0.0
var _start: Vector3
var _end: Vector3
var _return_goal: Vector3
var _rail: MeshInstance3D
var _pulse: MeshInstance3D
var _shutters: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _heads: Array[Node3D] = []
var _chant: Label3D
var _weak := 0.0
var _delivered_blow := false

func configure(spec: CinderEnemyStats, path: PackedVector3Array, camp: CinderSite) -> void:
	super.configure(spec, path, camp)
	_start = path[0] + Vector3.UP * .07
	_end = path[-1] + Vector3.UP * .07
	rotation.y = atan2(_end.x - _start.x, _end.z - _start.z)
	_rail = _mark_mesh()
	_pulse = MeshInstance3D.new()
	var circle := TorusMesh.new()
	circle.inner_radius = .91
	circle.outer_radius = 1.0
	circle.rings = 48
	circle.ring_segments = 5
	_pulse.mesh = circle
	_pulse.material_override = _emission(PLATE)
	add_child(_pulse)
	_pulse.top_level = true
	_pulse.hide()
	_shutters = _parts(["ChestL", "ChestR"])
	_arms = _parts(["ArmL","ArmR"])
	_legs = _parts(["LegL","LegR"])
	_heads = _parts(["HeadPivot"])
	_chant = Label3D.new()
	_chant.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_chant.font_size = 32
	_chant.pixel_size = .006
	_chant.outline_size = 7
	_chant.position = Vector3.UP * (spec.height + .66)
	add_child(_chant)
	_enter(Phase.MARK)

func _parts(names: Array) -> Array[Node3D]:
	var output: Array[Node3D] = []
	for part_name: String in names:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			output.append(part)
	return output

func _emission(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _mark_mesh() -> MeshInstance3D:
	var path_mesh := ImmediateMesh.new()
	path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var forward := (_end - _start).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	# World-space chevrons point toward the precise end of this charge.
	for i in 6:
		var center := _start.lerp(_end, (i+.65)/6.6) + Vector3.UP * .10
		for hand: float in [-1.0, 1.0]:
			var outer := center + side * hand * .58
			var inner := center + forward * .27
			for vertex: Vector3 in [outer, inner, inner - forward * .13, outer,
					inner - forward * .13, outer - forward * .13]:
				path_mesh.surface_add_vertex(vertex)
	path_mesh.surface_end()
	var trace := MeshInstance3D.new()
	trace.mesh = path_mesh
	trace.material_override = _emission(PLATE)
	add_child(trace)
	trace.top_level = true
	trace.global_transform = Transform3D.IDENTITY
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return trace

func phase_name() -> String:
	return ["Marked charge", "Charging", "Break the pulse", "Ground pulse", "Chest exposed", "Repositioning"][phase]

func _enter(next: Phase) -> void:
	phase = next
	elapsed = 0.0
	_delivered_blow = false
	_rail.visible = phase == Phase.MARK or phase == Phase.CHARGE
	_pulse.visible = phase == Phase.BRACE or phase == Phase.PULSE
	if phase == Phase.MARK:
		cue_requested.emit("vesper_charge")
	if phase == Phase.BRACE:
		_brace_hits = 0.0
		cue_requested.emit("vesper_pulse")
	if phase == Phase.OPEN:
		cue_requested.emit("vesper_exposed")
	if phase == Phase.RETURN:
		_return_goal = _start
		if health <= stats.health * .55:
			_east_lane = not _east_lane
			var next_lane := 2 if _east_lane else 0
			_return_goal = site_of_origin.lanes[next_lane][0] + Vector3.UP * .07
	_chant.text = phase_name().to_upper()
	_chant.modulate = EXPOSED if phase == Phase.OPEN or phase == Phase.BRACE else PLATE

func advance(core: SunCore, delta: float, field_factor: float) -> bool:
	_fade_flash(delta)
	elapsed += delta * (maxf(field_factor, .7) if phase == Phase.CHARGE else 1.0)
	var duration: float = LENGTHS[phase]
	if health <= stats.health * .55 and phase in [Phase.MARK, Phase.RETURN]:
		duration *= .72
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var previous := global_position
	var desired := global_position
	if phase == Phase.CHARGE:
		desired = _start.lerp(_end, smoothstep(0.0, 1.0, progress))
	elif phase == Phase.RETURN:
		desired = _end.lerp(_return_goal, smoothstep(0.0, 1.0, progress))
		desired.z -= sin(progress * PI) * .8
	if phase == Phase.MARK or phase == Phase.RETURN:
		var look := (_end - _start) if phase == Phase.MARK else (_return_goal - previous)
		if look.length_squared() > .02:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), 1.0 - exp(-6.5 * delta))
	velocity = (desired - global_position) / maxf(delta, .001)
	velocity.y = -1.2
	move_and_slide()
	var distance := flat_distance(previous, global_position)
	stride += distance * 3.7
	breath += delta
	_weak = move_toward(_weak, 1.0 if phase == Phase.OPEN else 0.0, delta * 4.0)
	var brace := sin(progress * PI * .5) if phase == Phase.BRACE else 0.0
	var charging := sin(PI * progress) if phase == Phase.CHARGE else 0.0
	model.rotation.x = .14 * charging + .19 * brace - .16 * _weak
	model.position.y = .02 + .016 * sin(breath * 2.2) - .18 * brace + minf(distance * 3.0, .09) * absf(sin(stride))
	for i in _shutters.size():
		_shutters[i].rotation.y = (-1 if i == 0 else 1) * (_weak * 1.0 + brace * .16)
	for i in _arms.size():
		_arms[i].rotation.x = -.28 * brace - .25 * charging + sin(stride + i * PI) * minf(.5, distance * 6.0)
	for i in _legs.size():
		_legs[i].rotation.x = sin(stride + (1-i)*PI) * minf(.52, distance * 6.0) + .09 * brace
	for head in _heads:
		head.rotation.x = .13 * brace - .20 * _weak
	if _pulse.visible:
		var radius := .7 + brace * .85
		if phase == Phase.PULSE:
			radius = lerpf(1.45, 6.0, progress)
		_pulse.scale = Vector3(radius, .16, radius)
		_pulse.global_position = global_position + Vector3.UP * .12
	var connected := false
	if phase == Phase.PULSE and not _delivered_blow and 1.45 + progress * 4.55 >= flat_distance(global_position, core.global_position):
		_delivered_blow = true
		connected = true
	if progress >= 1.0:
		var next := (phase + 1) % Phase.size()
		if next == Phase.MARK and _start.distance_squared_to(_return_goal) > .1:
			_start = _return_goal
			_end = core.global_position + Vector3(1.55 if _east_lane else -1.55,.07,-.35)
			_rail.queue_free()
			_rail = _mark_mesh()
		_enter(next as Phase)
	return connected

func wound(amount: float) -> void:
	if phase == Phase.BRACE:
		_brace_hits += amount
		if _brace_hits >= INTERRUPT_POWER:
			_enter(Phase.OPEN)
	var factor := 1.0 if phase == Phase.OPEN else .35
	super.wound(amount * factor)

func shove(_push: Vector3, _stun: float) -> void:
	pass

func withdraw(defeated := false) -> void:
	if fading:
		return
	_rail.hide()
	_pulse.hide()
	_chant.hide()
	super.withdraw(defeated)
	if defeated:
		fell.emit()
