extends MeshInstance3D
## Short-lived strips of colored light. Each glyph uses one mesh and one draw.
var _ink: StandardMaterial3D
var _geometry := ImmediateMesh.new()
var _tint := Color.WHITE
var _life := 0.5
var _age := 0.0
var _quiet := false
var _kind: StringName
var _follow: Node3D
var _targeted := false
var _radius := 1.0

static func glyph(parent: Node, kind: StringName, point: Vector3, radius: float, color: Color,
		seconds: float, quiet: bool, direction := Vector3.FORWARD, follow: Node3D = null):
	var fx := new()
	parent.add_child(fx)
	fx._kind = kind
	fx._radius = radius
	fx._tint = color
	fx._follow = follow
	fx._targeted = follow != null
	fx._life = seconds
	fx._quiet = quiet
	fx.global_position = point
	fx.rotation.y = atan2(direction.x, direction.z)
	fx._begin()
	fx._shape()
	fx._geometry.surface_end()
	return fx

static func chain(parent: Node, points: PackedVector3Array, color: Color, seconds: float, quiet: bool) -> void:
	var fx := new()
	parent.add_child(fx)
	fx._life = seconds
	fx._tint = color
	fx._quiet = quiet
	fx._begin()
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var side := (b-a).normalized().cross(Vector3.UP).normalized()
		var previous := a
		for j in range(1, 5):
			var t := j * .25
			var v := a.lerp(b,t)
			if j < 4 and not quiet:
				v += (Vector3.UP * (-.09 if j % 2 else .15) + side * sin(j * 2.1) * .36)
			fx._bar(fx.to_local(previous), fx.to_local(v), .078 if not quiet else .055)
			previous = v
	fx._geometry.surface_end()

func _begin() -> void:
	if not _ink:
		_ink = StandardMaterial3D.new()
		_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ink.vertex_color_use_as_albedo = true
		_ink.vertex_color_is_srgb = true
		_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh = _geometry
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _ink)

func _shape() -> void:
	match _kind:
		&"flooded_grove":
			_ring(_radius, .047, 0.0)
			for i in 18:
				var angle := TAU * i / 18.0
				var stem := Vector3(cos(angle),0,sin(angle)) * _radius
				var tip := stem * .91 + Vector3.UP * (.23 + .14 * sin(i * 2.3))
				_bar(stem, tip, .034)
				_bar(tip.lerp(stem, .55), stem * 1.035 + Vector3.UP * .22, .018)
		&"broken_quarry":
			for branch in 5:
				var a := -.49 + .245 * branch
				var axis := Vector3(sin(a),0,cos(a))
				var p := Vector3.ZERO
				for i in range(1, 5):
					var v := axis * (_radius * i / 4.0) + Vector3(sin(i * 5.0 + branch) * .14,.03,0)
					_bar(p,v,.089)
					if i > 2:
						_bar(p,p.lerp(v,.6) + Vector3(.33,.06,.08), .028)
					p = v
		&"lanternwood":
			for i in 8:
				var a := TAU * i / 8.0
				var center := Vector3(cos(a) * .89, sin(a * 2.0) * .24, sin(a) * .89)
				var side := Vector3(-sin(a),0,cos(a))
				var near := center + Vector3.UP * .03
				for hand: float in [-1.0,1.0]:
					_triangle(near, center + side * hand * .22 + Vector3.UP * .17, center + side * hand * .105 - Vector3.UP * .09)
		&"sunken_aqueduct":
			for i in 3:
				var x := (i - 1) * .18
				_bar(Vector3(x,0,0), Vector3(x,.04,_radius * (.75 if i != 1 else 1.0)), .038)
		&"sunwatch_observatory":
			for i in 4:
				var a := TAU * i / 4.0
				var tip := Vector3(cos(a),sin(a),0) * .37
				var axis := Vector3(-sin(a),cos(a),0)
				_bar(tip, tip * 1.38 + axis*.065, .017)
				_bar(tip, tip * 1.38 - axis*.065, .017)
			_ring(.30,.025, 1.0)
		&"last_lantern_frontier":
			for i in 12:
				var a := lerpf(-1.06,1.06,i/12.0)
				var b := lerpf(-1.06,1.06,(i+1)/12.0)
				var left := Vector3(sin(a),.05,cos(a)) * .65
				var right := Vector3(sin(b),.05,cos(b)) * .65
				var inner_left := left * (1.0 - sin(PI*i/12.0)*.32)
				var inner_right := right * (1.0 - sin(PI*(i+1)/12.0)*.32)
				_triangle(left,right,inner_left)
				_triangle(inner_left,right,inner_right)

func _ring(radius: float, width: float, vertical: float) -> void:
	for i in 48:
		var a := TAU*i/48.0
		var b := TAU*(i+1)/48.0
		var left := Vector3(cos(a), vertical*sin(a), (1.0-vertical)*sin(a))
		var right := Vector3(cos(b), vertical*sin(b), (1.0-vertical)*sin(b))
		_triangle(left*radius, right*radius, left*(radius-width))
		_triangle(right*radius, right*(radius-width), left*(radius-width))

func _bar(a: Vector3, b: Vector3, thickness: float) -> void:
	var path := b-a
	if path.length_squared() < .000001:
		return
	var side := path.normalized().cross(Vector3.RIGHT if absf(path.normalized().y) > .94 else Vector3.UP).normalized() * thickness
	_triangle(a-side, b-side, b+side)
	_triangle(a-side, b+side, a+side)
	var upright := path.normalized().cross(side).normalized() * thickness*.62
	_triangle(a-upright, b-upright, b+upright)
	_triangle(a-upright, b+upright, a+upright)

func _triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	_geometry.surface_set_color(_tint)
	_geometry.surface_add_vertex(a)
	_geometry.surface_add_vertex(b)
	_geometry.surface_add_vertex(c)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _life or (_targeted and not is_instance_valid(_follow)):
		queue_free()
		return
	if _follow is CinderEnemy:
		if not _follow.lensmarked():
			queue_free()
			return
		global_position = _follow.body_center() + Vector3.UP * (_follow.stats.height*.55 + .13)
		var cam := get_viewport().get_camera_3d()
		if cam:
			global_basis = cam.global_basis
	elif _follow is SunCore:
		if _follow.ward_strength <= 0.0:
			queue_free()
			return
		global_position = _follow.get_node("Visual/SunCenter").global_position
		if not _quiet:
			rotate_y(delta * 1.4)
	elif _kind == &"last_lantern_frontier" and not _quiet:
		rotate_y(delta * 15.0)
	if _kind == &"broken_quarry" and not _quiet:
		scale.z = lerpf(.22,1.0,smoothstep(0.0,.15,_age))
	_ink.albedo_color.a = 1.0 - smoothstep(_life * .77, _life, _age)
