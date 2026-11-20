extends Node3D

const BRONZE := preload("res://art/materials/stylized/route_bronze.tres")
const STONE := preload("res://art/materials/stylized/route_limestone.tres")
const TIMBER := preload("res://art/materials/stylized/route_timber.tres")
const BRASS := preload("res://art/materials/stylized/route_brass.tres")
const MOSS := preload("res://art/materials/stylized/route_moss.tres")
const LENGTH := 12.4

var code: String
var title: String
var opened := false
var handle: Vector3
var _hinge := AnimatableBody3D.new()
var _crank := Node3D.new()
var _motion: Tween

func configure(id: String, label: String, center: Vector3, along: Vector3, slope: float) -> void:
	code = id
	title = label
	name = id.to_pascal_case()
	# Local +Z points across the cut. The axle sits on the approach side.
	position = center - along * (LENGTH * .5)
	position.y -= slope * LENGTH * .5 + .055
	rotation.y = atan2(along.x, along.z)
	_landing(-3.8, 0.10, -.48, 0., slope)
	_landing(LENGTH - .12, LENGTH + 3.65, 0., -.48, slope)
	add_child(_hinge)
	_hinge.name = "Drawbridge"
	_hinge.sync_to_physics = false
	_hinge.set_meta("rest_angle", -atan(slope))
	for row in 21:
		var z := (row + .5) * LENGTH / 21.
		_box(_hinge, Vector3(0, -.08, z), Vector3(3.45, .16, LENGTH / 21. - .025), TIMBER)
	_deck_fittings()
	for side in [-1., 1.]:
		var x: float = side * 1.68
		_box(_hinge, Vector3(x, -.15, LENGTH * .5), Vector3(.12, .28, LENGTH + .12), BRONZE)
		_box(self, Vector3(x, .59, -.15), Vector3(.28, 1.22, .35), BRONZE)
		_box(self, Vector3(x, .18, -.16), Vector3(.45, .36, .56), STONE)
		_box(self, Vector3(x, 1.21, -.15), Vector3(.34, .10, .41), BRASS)
	_axle()
	var floor_shape := CollisionShape3D.new()
	var deck := BoxShape3D.new()
	deck.size = Vector3(3.5, .19, LENGTH)
	floor_shape.shape = deck
	floor_shape.position = Vector3(0, -.095, LENGTH * .5)
	_hinge.add_child(floor_shape)
	_hinge.rotation.x = deg_to_rad(-77)
	var post := Vector3(-2.5, 0, -.45)
	_box(self, post + Vector3.UP * .54, Vector3(.42, 1.08, .42), TIMBER)
	_box(self, post + Vector3.UP * .11, Vector3(.72, .26, .68), STONE)
	_box(self, post + Vector3.UP * .81, Vector3(.48, .18, .47), BRONZE)
	add_child(_crank)
	_crank.position = post + Vector3.UP * 1.10
	var wheel := MeshInstance3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = .39
	rim.outer_radius = .49
	rim.rings = 18
	rim.ring_segments = 5
	wheel.mesh = rim
	wheel.material_override = BRASS
	wheel.rotation.x = PI * .5
	_crank.add_child(wheel)
	for i in 3:
		var spoke := _box(_crank, Vector3.ZERO, Vector3(.10, .84, .10), BRASS)
		spoke.rotation.z = i * PI / 3.0
	var hub := _box(_crank, Vector3.ZERO, Vector3(.17, .17, .18), BRONZE)
	hub.rotation.z = PI * .25
	_box(_crank, Vector3(0, rim.outer_radius, .105), Vector3(.105, .12, .23), TIMBER)
	handle = to_global(post + Vector3.UP * .5)

func _deck_fittings() -> void:
	for x in [-1.53, 1.53]:
		for i in 4:
			var z := float(i) * LENGTH * .25 + .35
			_box(_hinge, Vector3(x, -.012, z), Vector3(.23, .063, .25), BRONZE)
		_box(_hinge, Vector3(x, -.25, LENGTH * .5), Vector3(.24, .24, LENGTH * .98), TIMBER)

func _axle() -> void:
	var axle := CylinderMesh.new()
	axle.top_radius = .14
	axle.bottom_radius = .14
	axle.height = 3.55
	axle.radial_segments = 10
	var shaft := MeshInstance3D.new()
	shaft.mesh = axle
	shaft.material_override = BRONZE
	shaft.rotation.z = PI * .5
	shaft.position = Vector3(0, .11, -.09)
	add_child(shaft)

func _landing(start: float, end: float, start_lip: float, end_lip: float, grade: float) -> void:
	var y0 := start * grade + start_lip
	var y1 := end * grade + end_lip
	var body := StaticBody3D.new()
	var depth := Vector2(end - start, y1 - y0).length()
	body.position = Vector3(0, (y0 + y1) * .5, (start + end) * .5)
	body.rotation.x = -atan2(y1 - y0, end - start)
	add_child(body)
	var size := Vector3(3.76, .32, depth)
	_box(body, Vector3.DOWN * .16, size, STONE)
	var moss_mesh := CylinderMesh.new()
	moss_mesh.top_radius = .05
	moss_mesh.bottom_radius = .068
	moss_mesh.height = .022
	moss_mesh.radial_segments = 6
	moss_mesh.rings = 0
	for side in [-1.0, 1.0]:
		for index in 3:
			var patch := MeshInstance3D.new()
			patch.mesh = moss_mesh
			patch.material_override = MOSS
			patch.position = Vector3(side * (1.78 - index * .08), .006 + index * .003,
				side * depth * .22 + index * .12)
			patch.scale = Vector3(1.1 + index * .14, 1.0, 4.5 - index * .61)
			patch.rotation.y = side * .18 + index * .33
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body.add_child(patch)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.position = Vector3.DOWN * .16
	collider.shape = shape
	body.add_child(collider)

func set_open(value: bool, animate: bool) -> void:
	if _motion:
		_motion.kill()
	opened = value
	var angle := float(_hinge.get_meta("rest_angle")) if value else deg_to_rad(-77)
	if not animate:
		_hinge.rotation.x = angle
		return
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(_hinge, "rotation:x", angle, 1.35)
	_motion.tween_property(_crank, "rotation:z", _crank.rotation.z + TAU * 1.5, 1.32)

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material
	visual.position = at
	parent.add_child(visual)
	return visual
