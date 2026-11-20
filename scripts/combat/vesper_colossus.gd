extends CinderEnemy
## The guardian holds the crown. Its marked charge ends short of the cradle;
## only an uninterrupted ground pulse can wound the sun.
enum Phase { MARK, CHARGE, STAMP, RING, OFFSET_MARK, OFFSET_CHARGE, BRACE, PULSE, OPEN, RECOVER, RETURN }
const LENGTHS := [1.3, .65, 1.0, 1.15, 1.0, .65, 2.3, .75, 4.0, 1.0, 1.8]
const GUIDE_PHASES: Array[StringName] = [&"mark", &"charge", &"stamp", &"ring", &"offset_mark",
	&"offset_charge", &"brace", &"pulse", &"open", &"recover", &"return"]
const STAGE_FLOORS := [.70, .35, 0.0]
const PULSE_DAMAGE := [9.0, 12.0, 15.0]
const SHOULDER_REACH := 3.65
const SHOULDER_COS := .342 # Within 70 degrees of the lit side.
const RING_GAP_COS := .79
const PLATE := Color("#d492ef")
const EXPOSED := Color("#ffe3a0")

signal cue_requested(cue: String)
signal fell
var phase := Phase.MARK
var _east_lane := false
var elapsed := 0.0
var traveler: CinderPlayer
var stage := 1
var _break_points := 0
var _stage_unsealed := false
var _shoulder_side := 1.0
var _contact_cooldown := 0.0
var _charge_start: Vector3
var _charge_end: Vector3
var _ring: MeshInstance3D
var _shoulder: MeshInstance3D
var _pauldron: MeshInstance3D
var _foot_rune: Label3D
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
var _last_pulse_loss := -1.0
var _last_pulse_absorbed := 0.0

func configure(spec: CinderEnemyStats, path: PackedVector3Array, camp: CinderSite) -> void:
	super.configure(spec.duplicate(), path, camp)
	_start = path[0] + Vector3.UP * .07
	_end = path[-1] + Vector3.UP * .07
	rotation.y = atan2(_end.x - _start.x, _end.z - _start.z)
	_ring = _arc(acos(RING_GAP_COS), TAU - acos(RING_GAP_COS), .90, 1.0, PLATE)
	_shoulder = _arc(-deg_to_rad(64), deg_to_rad(64), 1.50, 1.86, EXPOSED)
	_pauldron = MeshInstance3D.new()
	var point := PrismMesh.new()
	point.size = Vector3(.26, .42, .26)
	_pauldron.mesh = point
	_pauldron.material_override = _emission(EXPOSED)
	add_child(_pauldron)
	# The far-side foothold can fall behind the Colossus in the fixed camera.
	_foot_rune = Label3D.new()
	_foot_rune.text = "◆"
	_foot_rune.font_size = 32
	_foot_rune.pixel_size = .013
	_foot_rune.render_priority = 5
	_foot_rune.outline_size = 10
	_foot_rune.outline_modulate = Color("#513641")
	_foot_rune.modulate = EXPOSED
	_foot_rune.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_foot_rune.no_depth_test = true
	add_child(_foot_rune)
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
	_chant.pixel_size = .009
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
	var forward := (_charge_end - _charge_start).normalized()
	var side := forward.cross(Vector3.UP).normalized()
	# The twin rails match the traveler's contact threshold on either side.
	for hand: float in [-1.0, 1.0]:
		var edge := side * 1.05 * hand + Vector3.UP * .095
		var a := _charge_start + edge
		var b := _charge_end + edge
		for vertex: Vector3 in [a, b, b - side * .045 * hand, a, b - side * .045 * hand, a - side * .045 * hand]:
			path_mesh.surface_add_vertex(vertex)
	# World-space chevrons point toward the precise end of this charge.
	for i in 6:
		var center := _charge_start.lerp(_charge_end, (i+.65)/6.6) + Vector3.UP * .10
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

func _arc(start_angle: float, end_angle: float, inside: float, outside: float, color: Color) -> MeshInstance3D:
	var strip := ImmediateMesh.new()
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 49:
		var theta := lerpf(start_angle, end_angle, i / 48.0)
		var radial := Vector3(sin(theta), 0, cos(theta))
		strip.surface_add_vertex(radial * inside)
		strip.surface_add_vertex(radial * outside)
	strip.surface_end()
	var marker := MeshInstance3D.new()
	marker.mesh = strip
	marker.material_override = _emission(color)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.top_level = true
	return marker

func phase_name() -> String:
	return ["Marked charge", "Charging", "Jump the ring or find the gap", "Rising ring",
		"Sidestep the second charge", "Crossing charge", "Break the pulse", "Ground pulse",
		"Chest exposed", "Armor resealing", "Repositioning"][phase]

func on_lit_shoulder() -> bool:
	if not is_instance_valid(traveler):
		return false
	var offset := (traveler.global_position - global_position).slide(Vector3.UP)
	return offset.length() <= SHOULDER_REACH and offset.normalized().dot(shoulder_direction()) >= SHOULDER_COS

func seconds_left() -> float:
	return maxf(0.0, LENGTHS[phase] - elapsed)

func guide_state() -> Dictionary:
	return {"phase": GUIDE_PHASES[phase], "stage": stage, "seconds": seconds_left(),
		"sparks": mini(_break_points, 2) if phase in [Phase.BRACE, Phase.OPEN] else 0,
		"on_shoulder": on_lit_shoulder(), "target": counter_position(), "pulse_damage": int(stats.damage)}

func guide_heading() -> String:
	var timer := "%.1fs" % seconds_left()
	var prefix := "%s   ·   " % ["I", "II", "III"][stage - 1]
	match phase:
		Phase.BRACE:
			return prefix + "Counter   %s   ·   %d/2 sparks" % [timer, _break_points]
		Phase.OPEN:
			return prefix + "Chest open   %s" % timer
		Phase.PULSE, Phase.RECOVER, Phase.RETURN:
			if _last_pulse_loss >= 0.0:
				if _last_pulse_loss < .01:
					return prefix + "Ward absorbed the pulse"
				if _last_pulse_absorbed > 0.0:
					return prefix + "Core −%d   ·   Ward absorbed %d" % [roundi(_last_pulse_loss),roundi(_last_pulse_absorbed)]
				return prefix + "Missed pulse   ·   Core −%d" % roundi(_last_pulse_loss)
	return prefix + phase_name()

func guide_action() -> String:
	match phase:
		Phase.MARK, Phase.CHARGE, Phase.OFFSET_MARK, Phase.OFFSET_CHARGE:
			return "Shift   Dash sideways out of the violet lane"
		Phase.STAMP, Phase.RING:
			return "Space   Jump the ring or run through the gold gap"
		Phase.BRACE:
			if not on_lit_shoulder():
				return "Move to the gold shoulder to interrupt the pulse"
			if _break_points == 1:
				return "RMB   Land one more spark from the gold shoulder"
			return "LMB   Blade once     G   Damaging art     RMB   Two sparks"
		Phase.OPEN:
			return "Strike the open chest before the plates close"
		Phase.PULSE, Phase.RECOVER:
			return "An unbroken pulse strikes the shrine"
	return "Next gold shoulder   ·   One blade, a damaging art or two sparks"

func shoulder_direction() -> Vector3:
	return Vector3(0, 0, _shoulder_side)

func counter_position() -> Vector3:
	var landing := global_position
	if phase in [Phase.MARK, Phase.CHARGE, Phase.OFFSET_MARK, Phase.OFFSET_CHARGE]:
		landing = _charge_end
	elif phase == Phase.RETURN:
		landing = site_of_origin.anchor.global_position + Vector3(1.55 if _east_lane else -1.55, .07, -.35)
	return landing + shoulder_direction() * 1.73

func _set_charge(from: Vector3, to: Vector3) -> void:
	_charge_start = from
	_charge_end = to
	if _rail:
		_rail.hide()
		_rail.queue_free()
	_rail = _mark_mesh()

func _enter(next: Phase) -> void:
	phase = next
	elapsed = 0.0
	_delivered_blow = false
	match phase:
		Phase.MARK:
			_last_pulse_loss = -1.0
			_set_charge(_start, _end)
			cue_requested.emit("vesper_charge")
		Phase.STAMP:
			cue_requested.emit("vesper_pulse")
		Phase.OFFSET_MARK:
			# The second lane is fixed at the tell so its exit stays readable.
			var offset := 1.6 * _shoulder_side
			_set_charge(global_position, _end + Vector3(2.5 if _east_lane else -2.5, 0, offset))
			cue_requested.emit("vesper_charge")
		Phase.BRACE:
			_break_points = 0
			cue_requested.emit("vesper_pulse")
		Phase.OPEN:
			_stage_unsealed = true
			cue_requested.emit("vesper_exposed")
		Phase.RETURN:
			if stage < 3 and _stage_unsealed and health <= stats.health * STAGE_FLOORS[stage-1] + .001:
				stage += 1
				_stage_unsealed = false
			stats.damage = PULSE_DAMAGE[stage-1]
			_shoulder_side *= -1.0
			_east_lane = not _east_lane
			_end = global_position
			_return_goal = site_of_origin.lanes[2 if _east_lane else 0][0] + Vector3.UP * .07
	_rail.visible = phase in [Phase.MARK, Phase.CHARGE, Phase.OFFSET_MARK, Phase.OFFSET_CHARGE]
	_pulse.visible = phase in [Phase.BRACE, Phase.PULSE, Phase.STAMP]
	_ring.visible = phase in [Phase.STAMP, Phase.RING]
	_shoulder.visible = phase in [Phase.MARK, Phase.CHARGE, Phase.BRACE, Phase.STAMP, Phase.RING, Phase.OFFSET_MARK, Phase.OFFSET_CHARGE]
	_pauldron.visible = _shoulder.visible
	_foot_rune.visible = _shoulder.visible
	_chant.visible = phase == Phase.OPEN
	_chant.text = "CHEST OPEN"
	_chant.modulate = EXPOSED

func _next_phase() -> Phase:
	match phase:
		Phase.CHARGE:
			return Phase.BRACE if stage == 1 else Phase.STAMP
		Phase.RING:
			return Phase.OFFSET_MARK if stage == 3 else Phase.BRACE
		Phase.PULSE:
			return Phase.RECOVER
		Phase.OPEN, Phase.RECOVER:
			return Phase.RETURN
		Phase.RETURN:
			_start = _return_goal
			_end = site_of_origin.anchor.global_position + Vector3(1.55 if _east_lane else -1.55, .07, -.35)
			return Phase.MARK
	return (phase + 1) as Phase

func advance(core: SunCore, delta: float, field_factor: float) -> bool:
	_fade_flash(delta)
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	var rushing := phase in [Phase.CHARGE, Phase.OFFSET_CHARGE]
	elapsed += delta * (maxf(field_factor, .7) if rushing else 1.0)
	var progress := clampf(elapsed / float(LENGTHS[phase]), 0.0, 1.0)
	var previous := global_position
	var desired := global_position
	if rushing:
		desired = _charge_start.lerp(_charge_end, smoothstep(0.0, 1.0, progress))
	elif phase == Phase.RETURN:
		desired = _end.lerp(_return_goal, smoothstep(0.0, 1.0, progress))
		desired.z -= sin(progress * PI) * .8
	if phase in [Phase.MARK, Phase.OFFSET_MARK, Phase.RETURN]:
		var look := (_return_goal - previous) if phase == Phase.RETURN else (_charge_end - _charge_start)
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
	var charging := sin(PI * progress) if rushing else 0.0
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
	if _shoulder.visible:
		var rune := "◇  SHOULDER"
		if phase in [Phase.STAMP, Phase.RING]:
			rune = "◇  GAP"
		elif phase == Phase.BRACE:
			rune = "◆  ON MARK" if on_lit_shoulder() else "◇  MOVE HERE"
		if _foot_rune.text != rune:
			_foot_rune.text = rune
		_shoulder.global_position = counter_position() - shoulder_direction() * 1.73 + Vector3.UP * .10
		_shoulder.rotation.y = 0.0 if _shoulder_side > 0.0 else PI
		_foot_rune.global_position = counter_position() + shoulder_direction() * .42 + Vector3.UP * (.75 + .07 * sin(breath * 5.0))
		_pauldron.global_position = global_position + shoulder_direction() * .65 + Vector3.UP * (2.07 + sin(breath * 5.0) * .06)
	var ring_radius := .62 + progress * 6.0 if phase == Phase.RING else .62
	if _ring.visible:
		_ring.global_position = global_position + Vector3.UP * .12
		_ring.rotation.y = 0.0 if _shoulder_side > 0.0 else PI
		_ring.scale = Vector3.ONE * ring_radius
	if is_instance_valid(traveler) and _contact_cooldown <= 0.0:
		var offset := (traveler.global_position - global_position).slide(Vector3.UP)
		var closest := global_position
		if rushing and previous.distance_squared_to(global_position) > .00001:
			closest = Geometry3D.get_closest_point_to_segment(traveler.global_position, previous, global_position)
		var struck := rushing and flat_distance(traveler.global_position, closest) < 1.05
		if phase == Phase.RING and absf(offset.length() - ring_radius) < .38 and traveler.global_position.y < global_position.y + .52:
			struck = offset.normalized().dot(shoulder_direction()) < RING_GAP_COS
		if struck:
			traveler.guardian_stagger(.4)
			_contact_cooldown = 1.0
	var connected := false
	if phase == Phase.PULSE and not _delivered_blow and 1.45 + progress * 4.55 >= flat_distance(global_position, core.global_position):
		_delivered_blow = true
		connected = true
		_last_pulse_absorbed = minf(core.ward_strength, stats.damage)
		_last_pulse_loss = minf(core.health, stats.damage - _last_pulse_absorbed)
	if progress >= 1.0:
		_enter(_next_phase())
	return connected

## Keep sparks aimed past the tall boss able to hit the smaller escorts.
func spark_radius() -> float:
	return stats.radius + .20

func combat_hit(amount: float, source: StringName) -> void:
	if phase == Phase.BRACE and source in [&"spark", &"melee", &"ability"]:
		if on_lit_shoulder():
			_break_points += 1 if source == &"spark" else 2
			if _break_points >= 2:
				_enter(Phase.OPEN)
	wound(amount)

func wound(amount: float) -> void:
	var floor_hp: float = stats.health * STAGE_FLOORS[stage-1]
	if not _stage_unsealed:
		floor_hp += 1.0
	var effective := amount * (1.0 if phase == Phase.OPEN else .25)
	super.wound(minf(effective, maxf(0.0, health - floor_hp)))

func shove(_push: Vector3, _stun: float) -> void:
	pass

func withdraw(defeated := false) -> void:
	if fading:
		return
	_rail.hide()
	_pulse.hide()
	_ring.hide()
	_shoulder.hide()
	_pauldron.hide()
	_foot_rune.hide()
	_chant.hide()
	super.withdraw(defeated)
	if defeated:
		fell.emit()
