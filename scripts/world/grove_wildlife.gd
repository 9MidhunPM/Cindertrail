extends Node3D
## Small visual-only flock. Its silhouettes never enter the navigation or enemy layers.

const PERCHES := [Vector3(1.52, .59, 10.28), Vector3(-6.25, .61, 7.05), Vector3(5.25, .60, 5.8)]
const FACING := [0.27, -1.05, 0.7]

var _herons: Array[Node3D] = []
var _dragonflies: Array[Node3D] = []
var _time := 0.0
var _flight := -1.0

func _ready() -> void:
	name = "WetlandWildlife"
	for i in PERCHES.size():
		var bird := _heron()
		bird.name = "Heron%d" % (i + 1)
		add_child(bird)
		bird.position = PERCHES[i]
		bird.rotation.y = FACING[i]
		_herons.append(bird)
	for i in 8:
		var dragonfly := _dragonfly()
		dragonfly.name = "Dragonfly%d" % (i + 1)
		add_child(dragonfly)
		_dragonflies.append(dragonfly)
	_process(0.0)

func lift_flock() -> void:
	if _flight < 0.0:
		_flight = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _flight >= 0.0:
		_flight += delta
		if _flight >= 18.0:
			_flight = -1.0
	for i in _herons.size():
		_update_heron(_herons[i], i)
	for i in _dragonflies.size():
		var insect := _dragonflies[i]
		var angle := _time * (1.1 + i * .087) + float(i) * 2.39996
		var home: Vector3 = PERCHES[i % PERCHES.size()]
		insect.position = home + Vector3(cos(angle) * 1.14, .30 + sin(angle * 1.66) * .23, sin(angle) * .88)
		insect.rotation.y = -angle
		insect.get_node(^"LeftWing").rotation.z = sin(_time * 104. + i * 2.5) * .9
		insect.get_node(^"RightWing").rotation.z = -insect.get_node(^"LeftWing").rotation.z

func _update_heron(bird: Node3D, index: int) -> void:
	var t := clampf((_flight - index * .21) / 15.5, 0., 1.)
	var amplitude := sin(t * PI)
	var taking_flight := smoothstep(0., .10, t) * (1. - smoothstep(.89, 1., t))
	var route := sin(t * TAU)
	bird.position = PERCHES[index] + Vector3(route * (5.6 + index), amplitude * 5.4, -amplitude * (9.5 + index * .82))
	bird.rotation.y = lerp_angle(FACING[index], route * -.60, taking_flight)
	bird.rotation.x = route * -.10 * taking_flight
	var wing_angle := lerpf(1.36, sin(t * TAU * 28. + index) * .65 - .16, taking_flight)
	bird.get_node(^"LeftWing").rotation.z = -wing_angle
	bird.get_node(^"RightWing").rotation.z = wing_angle
	bird.get_node(^"Legs").rotation.x = lerpf(0., -1.42, taking_flight)
	bird.get_node(^"Head").rotation.x = sin(_time * 1.25 + index * 1.4) * .12 * (1. - taking_flight)

func _heron() -> Node3D:
	var bird := Node3D.new()
	var pale := _material(Color("#d2e0d1"))
	var throat := _material(Color("#f1ead7"))
	var slate := _material(Color("#557682"))
	var dark := _material(Color("#2d4250"))
	var ochre := _material(Color("#b57642"))
	_oval(bird, pale, Vector3(0, .34, .03), Vector3(.28, .26, .50))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, .38, -.10)
	bird.add_child(head)
	_stalk(head, throat, Vector3.ZERO, Vector3(0, .27, -.13), .084, .055)
	_stalk(head, pale, Vector3(0, .26, -.13), Vector3(0, .36, -.27), .058, .047)
	_oval(head, throat, Vector3(0, .36, -.28), Vector3(.13, .11, .20))
	_stalk(head, ochre, Vector3(0, .355, -.34), Vector3(0, .325, -.57), .042, .002)
	for side in [-1., 1.]:
		_oval(head, dark, Vector3(.057 * side, .378, -.29), Vector3(.022, .020, .021))
	var legs := Node3D.new()
	legs.name = "Legs"
	legs.position = Vector3(0, .30, .03)
	bird.add_child(legs)
	_wing(bird, pale, dark, -.96, .30, &"LeftWing")
	_wing(bird, pale, dark, .96, .30, &"RightWing")
	for side in [-1., 1.]:
		var hip := Vector3(side * .072, 0., .06)
		var heel := hip + Vector3(0., -.29, -.04)
		_stalk(legs, ochre, hip, heel, .015, .010)
		_stalk(legs, ochre, heel, heel + Vector3(side * .035, 0., -.095), .012, .003)
	_stalk(bird, slate, Vector3(0, .33, .19), Vector3(0, .32, .39), .11, .054)
	return bird

func _dragonfly() -> Node3D:
	var insect := Node3D.new()
	var thorax := _material(Color("#96cbbd"))
	thorax.emission_enabled = true
	thorax.emission = Color("#239493")
	thorax.emission_energy_multiplier = .85
	var glass := _material(Color("#c8e5cd"))
	var veins := _material(Color("#75beae"))
	glass.emission_enabled = true
	glass.emission = Color("#7fc4a7")
	glass.emission_energy_multiplier = .32
	_oval(insect, thorax, Vector3.ZERO, Vector3(.044, .035, .24))
	_oval(insect, thorax, Vector3.FORWARD * .107, Vector3(.062, .048, .063))
	_wing(insect, glass, veins, -.24, 0., &"LeftWing")
	_wing(insect, glass, veins, .24, 0., &"RightWing")
	return insect

func _wing(parent_node: Node3D, cover: Material, edge: Material, span: float, y: float, wing_name: StringName) -> void:
	var joint := Node3D.new()
	joint.name = wing_name
	joint.position = Vector3(signf(span) * .055, y, 0.)
	parent_node.add_child(joint)
	var reach := absf(span)
	var root := Vector3(0, 0, -reach * .11)
	var knuckle := Vector3(span * .48, .036 * reach, -.18 * reach)
	var tip := Vector3(span, 0, .01 * reach)
	var back := Vector3(span * .52, -.035 * reach, .28 * reach)
	var inside := Vector3(span * .09, 0., .29 * reach)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(cover)
	for at in [root, knuckle, back, root, back, inside]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(at)
	var wing := MeshInstance3D.new()
	wing.mesh = surface.commit()
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	joint.add_child(wing)
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(edge)
	for feather in 4:
		var first := float(feather) / 4.
		var origin := knuckle.lerp(inside, first)
		var outer := tip.lerp(back, first)
		for at in [origin, outer, tip.lerp(back, first + .27) + Vector3.BACK * reach * .03]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(at)
	var tips := MeshInstance3D.new()
	tips.mesh = surface.commit()
	tips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	joint.add_child(tips)

func _stalk(parent_node: Node3D, material: Material, begin: Vector3, end: Vector3, start_radius: float, end_radius: float) -> void:
	var stem := CylinderMesh.new()
	stem.bottom_radius = start_radius
	stem.top_radius = end_radius
	stem.height = begin.distance_to(end)
	stem.radial_segments = 5
	var part := _part(parent_node, material, stem, (begin + end) * .5)
	part.basis = Basis(Quaternion(Vector3.UP, begin.direction_to(end)))

func _oval(parent_node: Node3D, material: Material, at: Vector3, size: Vector3) -> void:
	var ellipsoid := SphereMesh.new()
	ellipsoid.radial_segments = 8
	ellipsoid.rings = 4
	_part(parent_node, material, ellipsoid, at).scale = size

func _part(parent_node: Node3D, material: Material, shape: Mesh, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = shape
	part.position = at
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent_node.add_child(part)
	return part

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .77
	return material
