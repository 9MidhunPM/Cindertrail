extends MeshInstance3D

## Offsets from the deployment anchor. Each pair traces a feature to the place
## where its current breaks free of the ground, cable, branch or glass.
const STREAMS := {
	&"flooded_grove": [Color("#5de6d1"),
		Vector3(-6.9,-.39,3.1), Vector3(-4.9,.21,2.15),
		Vector3(6.6,-.39,3.75), Vector3(4.55,.33,2.52),
		Vector3(2.9,-.40,-7.25), Vector3(2.35,.22,-4.52)],
	&"broken_quarry": [Color("#eab370"),
		Vector3(-6.15,.2,-4.9), Vector3(-3.7,.16,-3.2),
		Vector3(3.7,.32,-5.18), Vector3(3.2,.15,-2.3),
		Vector3(1.8,.24,4.75), Vector3(.92,.2,3.3)],
	&"fallen_relay": [Color("#66d9ce"),
		Vector3(-4.5,5.69,-7.8), Vector3(-3.5,2.65,-5.3),
		Vector3(7.7,6.32,-5.65), Vector3(5.45,2.25,-3.56),
		Vector3(2.7,1.26,-4.94), Vector3(2.3,.34,-3.55)],
	&"lanternwood": [Color("#c5dd8c"),
		Vector3(-6.6,.08,1.9), Vector3(-4.2,.21,1.4),
		Vector3(5.0,.09,-3.98), Vector3(3.09,.28,-2.1),
		Vector3(-2.8,.08,-6.6), Vector3(-1.27,.25,-4.3)],
	&"sunken_aqueduct": [Color("#80dfed"),
		Vector3(-9.06,-.07,-5.1), Vector3(-4.8,.19,-2.9),
		Vector3(6.58,-.04,-9.3), Vector3(4.15,.21,-5.55),
		Vector3(5.95,.71,-5.45), Vector3(3.7,.32,-2.7)],
	&"sunwatch_observatory": [Color("#c2e4fc"),
		Vector3(-5.5,1.23,5.0), Vector3(-3.18,1.57,3.2),
		Vector3(5.5,1.23,5.0), Vector3(3.49,1.62,2.9),
		Vector3(0,.13,6.77), Vector3(.45,.27,3.78)],
	&"last_lantern_frontier": [Color("#ffbf79"),
		Vector3(-4.6,1.08,4.8), Vector3(-3.75,1.74,2.65),
		Vector3(4.6,1.08,4.8), Vector3(3.8,1.63,3.02),
		Vector3(0,.05,-6.18), Vector3(.73,.75,-3.98)]
}

var _surface := ShaderMaterial.new()
var _site_id: StringName
var _clock := 0.0
var _last_draw_frame := -1
var _vertices := PackedVector3Array()
var _tangents := PackedVector3Array()
var _uvs := PackedVector2Array()
var _width_phase := PackedVector2Array()
var _indices := PackedInt32Array()
var quiet := false

func _ready() -> void:
	name = "SiteEnergyStreams"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = .5
	_surface.shader = preload("res://scripts/fx/site_draw.gdshader")
	_surface.render_priority = 3
	material_override = _surface
	process_physics_priority = 100
	clear()

func receive(site: CinderSite, focus: Vector3, amount: float, reduced_motion: bool) -> void:
	if amount <= 0.0 or not STREAMS.has(site.checkpoint_id):
		clear()
		return
	if _site_id != site.checkpoint_id:
		_site_id = site.checkpoint_id
		global_position = site.anchor.global_position
		_build(to_local(focus))
	if not visible:
		_clock = 0.0
		set_physics_process(true)
		show()
	_last_draw_frame = Engine.get_physics_frames()
	_clock += amount / maxf(site.spec.rate, .001)
	quiet = reduced_motion
	_surface.set_shader_parameter("quiet", quiet)
	_surface.set_shader_parameter("draw_clock", _clock)
	_surface.set_shader_parameter("abundance", clampf(site.remaining_energy / site.spec.energy, 0.0, 1.0))

func clear() -> void:
	hide()
	set_physics_process(false)
	_last_draw_frame = -1

func arrival_glow() -> float:
	if not visible or quiet:
		return 0.0
	# Same packet phase as the fragment shader at x = 1.
	var pulse := 0.0
	for i in 3:
		var distance_to_head := absf(fposmod(1.22 - _clock * .73 + i * .28 + .5, 1.0) - .5)
		pulse = maxf(pulse, exp(-distance_to_head * 14.0))
	return pulse

func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() != _last_draw_frame:
		clear()

func _build(focus: Vector3) -> void:
	var theme: Array = STREAMS[_site_id]
	_surface.set_shader_parameter("source_tint", theme[0])
	for i in 3:
		var source: Vector3 = theme[1+i*2]
		var bend: Vector3 = theme[2+i*2]
		var toward := Vector3(-source.x, 0, -source.z).normalized()
		var across := toward.cross(Vector3.UP)
		var is_mirror := _site_id == &"sunwatch_observatory"
		# Follow the feature first, then spiral around the brass ring which
		# receives the strand. All three curves end at the same miniature sun.
		var route := PackedVector3Array([source, bend, bend.lerp(focus,.58) + across * .55 + Vector3.UP * .09,
			focus - toward * .68 + across * .33 + Vector3.UP * .24,
			focus + across * .22 + Vector3.UP * .29, focus])
		var current := _curve(route)
		_strip(current, .17 if is_mirror else .225, .19, 1.0, i * .28)
		# Two streams of dust curl around the trunk as each parcel is drawn in.
		for flank: float in [-1.0, 1.0]:
			var eddy := PackedVector3Array()
			for step in current.size():
				var t := float(step) / (current.size() - 1)
				var radius := .25 * sin(t * PI)
				var turn := t * TAU * 1.6 + i * .81
				var offset := across * sin(turn) + Vector3.UP * cos(turn)
				eddy.append(current[step] + offset * radius * flank)
			_strip(eddy, .083, .19, 1.0, 1.0 + i * .28 + flank * .035 + .05)
		# Feeder threads trace water seams, ore cracks, roots, or the flare where
		# light leaves the glass. Only one material/surface for the entire site.
		var raised_source := source.y > .65
		for side: float in [-1.0, 1.0]:
			var reach := .48 if raised_source else 1.39
			var outer := source + across * side * reach - toward * reach * .54
			if raised_source:
				outer.y += .18 * side
			var elbow := source + across * side * reach * .52 - toward * reach * .28
			if not is_mirror:
				elbow += toward * .18 * side
			_strip(_curve(PackedVector3Array([outer, elbow, source])), .087, .0, .19, i * .28)
		# In water a pair of luminous, broken ripples marks the spring even
		# against the much brighter limestone circle.
		if _site_id == &"flooded_grove" or (_site_id == &"sunken_aqueduct" and i < 2):
			for arc in 2:
				var ripple := PackedVector3Array()
				for step in 31:
					var a := step / 30.0 * PI * 1.62 + i + arc * 2.12
					var radius := .39 + .32 * arc
					ripple.append(source + (across * cos(a) + toward * sin(a) * .79) * radius)
				_strip(ripple, .069, .0, .19, i * .28)
	_build_surface()

func _curve(keys: PackedVector3Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	for segment in keys.size() - 1:
		var previous := keys[maxi(segment - 1, 0)]
		var next := keys[mini(segment + 2, keys.size() - 1)]
		for step in 9:
			points.append(keys[segment].cubic_interpolate(keys[segment+1], previous, next, step/9.0))
	points.append(keys[-1])
	return points

func _strip(points: PackedVector3Array, width: float, start: float, end: float, phase: float) -> void:
	var length_at := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		length_at.append(length_at[-1] + points[i-1].distance_to(points[i]))
	var base := _vertices.size()
	for i in points.size():
		var t := length_at[i] / maxf(.001, length_at[-1])
		var along := lerpf(start, end, t)
		var tangent := (points[mini(points.size()-1, i+1)] - points[maxi(0,i-1)]).normalized()
		var radius := width * lerpf(1.08, .58, along)
		if start == 0.0:
			radius *= smoothstep(-.04, .57, t)
		for edge in 2:
			_vertices.append(points[i])
			_tangents.append(tangent)
			_uvs.append(Vector2(along, float(edge)))
			_width_phase.append(Vector2(radius, phase))
		if i > 0:
			var p := base + i*2
			_indices.append_array(PackedInt32Array([p-2,p-1,p, p,p-1,p+1]))

func _build_surface() -> void:
	var buffers := []
	buffers.resize(Mesh.ARRAY_MAX)
	buffers[Mesh.ARRAY_VERTEX] = _vertices
	buffers[Mesh.ARRAY_NORMAL] = _tangents
	buffers[Mesh.ARRAY_TEX_UV] = _uvs
	buffers[Mesh.ARRAY_TEX_UV2] = _width_phase
	buffers[Mesh.ARRAY_INDEX] = _indices
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, buffers)
	mesh = surface
	_vertices.clear()
	_tangents.clear()
	_uvs.clear()
	_width_phase.clear()
	_indices.clear()
