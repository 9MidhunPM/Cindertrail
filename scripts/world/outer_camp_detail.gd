extends Node3D

const BRONZE := preload("res://art/materials/bronze.tres")
const BRASS := preload("res://art/materials/brass.tres")
const STONE := preload("res://art/materials/stone_cream.tres")
const WOOD := preload("res://art/materials/wood.tres")
const FALL := preload("res://art/materials/grove/waterfall.gdshader")

var _lamps: Array[Node3D] = []
var _moths: Array[Node3D] = []
var _birds: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _mirrors: Array[Node3D] = []
var _lantern: MeshInstance3D
var _lamp_light: OmniLight3D
var _wood: Node3D
var _sluice: Node3D
var _summit: Node3D
var _wheel: Node3D
var _sluice_spray: Node3D
var _sluice_flow: Node3D
var _sunbeam: Node3D
var _hatch: Node3D
var _night_glass := StandardMaterial3D.new()
var _amber_glass := StandardMaterial3D.new()
var _blue_glass := StandardMaterial3D.new()
var _age := 0.0
var _variant := 0.0
var _wheel_turn := 0.0
var _surge_remaining := 0.0
var _beam_remaining := 0.0
var _flash_remaining := 0.0
var _lamp_lit := false

func setup(landmarks: Dictionary, world_spots: Dictionary) -> void:
	_night_glass.albedo_color = Color("#324347")
	_amber_glass = _glow(Color("#ffc470"), 1.5)
	_blue_glass = _glow(Color("#7be9e0"), 0.9)
	_wood = _pivot(self, world_spots.west)
	_sluice = _pivot(self, world_spots.south)
	_summit = _pivot(self, world_spots.east)
	var lamp_positions: PackedVector3Array = landmarks[&"lanternwood"]
	var wheel_positions: PackedVector3Array = landmarks[&"sunken_aqueduct"]
	var mirror_positions: PackedVector3Array = landmarks[&"sunwatch_observatory"]
	_make_lanternwood(lamp_positions[0] - _wood.position)
	_make_sluice(wheel_positions[0] - _sluice.position)
	_make_observatory(mirror_positions[0] - _summit.position, mirror_positions[1] - _summit.position)

func seed_life(value: int) -> void:
	_variant = float(posmod(value, 514)) * .037

func activate(id: StringName, stage: int) -> void:
	match id:
		&"lanternwood":
			if stage == 0:
				show_progress(id, 1)
			else:
				_flash_remaining = 1.8
		&"sunken_aqueduct":
			_wheel_turn += TAU
			_surge_remaining = 2.2
			_sluice_flow.show()
		&"sunwatch_observatory":
			if stage < 2:
				var mirror := _mirrors[stage]
				var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				turn.tween_property(mirror, "rotation:y", -.45 if stage == 0 else .50, .48)
				if stage == 1:
					turn.parallel().tween_property(_hatch, "rotation:x", -.62, .70)
			else:
				_beam_remaining = 1.3
				_sunbeam.show()

func show_progress(id: StringName, steps: int) -> void:
	if id == &"lanternwood":
		_lamp_lit = steps > 0
		_lantern.material_override = _amber_glass if steps > 0 else _night_glass
		_lamp_light.light_energy = 1.25 if steps > 0 else .20
	elif id == &"sunwatch_observatory":
		for i in _mirrors.size():
			_mirrors[i].rotation.y = (-.45 if i == 0 else .50) if steps > i else (-1.30 if i == 0 else 1.30)
		_hatch.rotation.x = -.62 if steps >= 2 else 0.0

func _process(delta: float) -> void:
	if _wood == null:
		return
	_age += delta
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(_wood.global_position) < 6400:
		for i in _lamps.size():
			_lamps[i].rotation.z = sin(_age * 1.18 + i * .86) * .095
		for i in _moths.size():
			var t := _age * (1.18 + .08 * (i % 3)) + i * 1.31 + _variant
			var f := float(i) / _moths.size()
			if _lamp_lit:
				f = lerpf(.68, 1.0, f)
			_moths[i].position = Vector3(lerpf(-1.6, 5.0, f) + sin(t * 1.3) * .86,
				.9 + absf(cos(t * .75)) * .85, lerpf(1.7, -4.0, f) + cos(t) * .76)
			_moths[i].rotation.y = t
			_moths[i].scale.y = .36 + .64 * absf(sin(t * 13.0))
	if camera != null and camera.global_position.distance_squared_to(_sluice.global_position) < 9604:
		for i in _birds.size():
			var t := _age * .52 + i * .23 + _variant
			var circle := Vector3(cos(t) * (9.1 + i * 1.4), 6.9 + sin(t * 2.0) * .67,
				sin(t) * (7.0 + i * 1.1) - 9.1)
			_birds[i].position = circle
			_birds[i].rotation.y = atan2(-sin(t), cos(t))
			_wings[2 * i].rotation.z = sin(_age * 13.0 + i * .36) * .57
			_wings[2 * i + 1].rotation.z = -_wings[2 * i].rotation.z
		for i in _sluice_spray.get_child_count():
			var spray := _sluice_spray.get_child(i) as Node3D
			var flow := fposmod(_age * (1.21 + (i % 3) * .17) + i * .31, 1.0)
			spray.position.y = -.15 + sin(flow * PI) * .47
			spray.scale = Vector3(1.0, .25 + flow * .75, 1.0) * (1.0 - flow * .52)
	_wheel.rotation.z = lerpf(_wheel.rotation.z, _wheel_turn, 1.0 - exp(-6.0 * delta))
	if _surge_remaining > 0.0:
		_surge_remaining = maxf(0, _surge_remaining - delta)
		_sluice_flow.position.z = lerpf(-13.0, -1.0, 1.0 - _surge_remaining / 2.2)
		_sluice_flow.visible = _surge_remaining > 0.0
	if _beam_remaining > 0.0:
		_beam_remaining = maxf(0, _beam_remaining - delta)
		_sunbeam.rotation.y = lerpf(-.68, -.23, 1.0 - _beam_remaining / 1.3)
		_sunbeam.visible = _beam_remaining > 0.0
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0, _flash_remaining - delta)
		_lamp_light.light_energy = 1.25 + _flash_remaining * 2.4

func _make_lanternwood(point: Vector3) -> void:
	var lamp_stand := _pivot(_wood, point)
	_cylinder(lamp_stand, Vector3(0, 1.42, 0), .115, .22, 2.84, WOOD)
	_box(lamp_stand, Vector3(.25, 2.64, 0), Vector3(.9, .13, .20), WOOD)
	var lamp := _hanging_lamp(lamp_stand, Vector3(.65, 2.61, 0), _night_glass)
	_lantern = lamp.get_child(0) as MeshInstance3D
	_lamp_light = OmniLight3D.new()
	_lamp_light.light_color = Color("#ffae58")
	_lamp_light.light_energy = .2
	_lamp_light.omni_range = 5.4
	_lamp_light.position.y = -.49
	lamp.add_child(_lamp_light)
	for loc: Vector3 in [Vector3(-9, 4.8, -8),Vector3(-3, 4.2, -8),
			Vector3(2, 4.0, -8),Vector3(8, 4.7, -7),Vector3(-7, 3.7, 2)]:
		_hanging_lamp(_wood, loc, _amber_glass)
	for i in 14:
		var moth := _pivot(_wood, point + Vector3.UP)
		var left := _box(moth, Vector3(-.04, 0, 0), Vector3(.075,.012,.064), _amber_glass)
		left.rotation.y = -.42
		var right := _box(moth, Vector3(.04, 0, 0), Vector3(.075,.012,.064), _amber_glass)
		right.rotation.y = .42
		_moths.append(moth)

func _hanging_lamp(parent: Node3D, at: Vector3, glass: Material) -> Node3D:
	var lamp := _pivot(parent, at)
	_cylinder(lamp, Vector3(0, -.36, 0), .18, .16, .31, glass)
	_cylinder(lamp, Vector3(0, -.17, 0), .075, .24, .15, BRONZE)
	_cylinder(lamp, Vector3(0, -.55, 0), .23, .11, .12, BRASS)
	for side in 6:
		var angle := TAU * side / 6.0
		_cylinder(lamp, Vector3(cos(angle) * .184, -.38, sin(angle) * .184), .021, .022, .32, BRONZE)
	_lamps.append(lamp)
	return lamp

func _make_sluice(point: Vector3) -> void:
	var stand := _pivot(_sluice, point)
	_box(stand, Vector3(0,.12,0), Vector3(1.7,.24,1.34), STONE)
	_box(stand, Vector3(0,.58,-.14), Vector3(.45,1.10,.41), WOOD)
	_wheel = _pivot(stand, Vector3(0,1.24,.14))
	var torus := TorusMesh.new()
	torus.inner_radius = .54
	torus.outer_radius = .68
	torus.rings = 18
	torus.ring_segments = 8
	var rim := _mesh(_wheel, Vector3.ZERO, torus, BRONZE)
	rim.rotation.x = PI * .5
	for i in 6:
		var spoke := _box(_wheel, Vector3.ZERO, Vector3(.073,1.17,.10), BRASS)
		spoke.rotation.z = i * PI / 6.0
	_box(_wheel, Vector3(0,.0,.048), Vector3(.20,.20,.17), BRONZE)
	var cascade := ShaderMaterial.new()
	cascade.shader = FALL
	_cascade(-10.3, -17.20, 6.96, 1.28, cascade)
	_cascade(-9.62, -17.14, 6.88, .38, cascade)
	_cascade(12.65, -17.21, 6.95, .88, cascade)
	_cascade(12.11, -17.17, 6.86, .34, cascade)
	_sluice_spray = _pivot(_sluice, Vector3(0,-.2,0))
	for i in 12:
		var side := i % 2
		var index := floorf(i * .5)
		var x := -12.1 + index * .69 if side == 0 else 6.65 + sin(float(i)) * .64
		var z := -5.1 + cos(i) * .62 if side == 0 else -12.8 + index * 1.15
		var spray := _box(_sluice_spray, Vector3(x,.0,z), Vector3(.035,.17,.035), _blue_glass)
		spray.rotation.z = .40 * cos(i)
	_sluice_flow = _pivot(_sluice, Vector3(1.2,.1,-13))
	for i in 3:
		_box(_sluice_flow, Vector3(0,.0,-i*.52), Vector3(2.6-i*.3,.043,.13), _blue_glass)
	_sluice_flow.hide()
	for i in 4:
		var bird := _pivot(_sluice, Vector3(0, 7, -8))
		_birds.append(bird)
		_box(bird, Vector3.ZERO, Vector3(.075,.06,.28), WOOD)
		for side: float in [-1.0, 1.0]:
			var wing := _pivot(bird, Vector3(side * .02, 0, 0))
			var feather := _box(wing, Vector3(side*.18,0,0), Vector3(.34,.022,.09), _night_glass)
			feather.rotation.y = side * .35
			_wings.append(wing)

func _cascade(x: float, z: float, height: float, width: float, material: Material) -> void:
	var ribbon := QuadMesh.new()
	ribbon.size = Vector2(width, height)
	_mesh(_sluice, Vector3(x, height * .5 - .04, z), ribbon, material)

func _make_observatory(first: Vector3, second: Vector3) -> void:
	for point in [first, second]:
		var frame := _pivot(_summit, point)
		_cylinder(frame, Vector3(0,.20,0), .58, .68, .40, STONE)
		_cylinder(frame, Vector3(0,.62,0), .18, .30, .58, BRONZE)
		var mirror := _pivot(frame, Vector3(0,1.22,0))
		var border := _cylinder(mirror, Vector3.ZERO, .54, .54, .14, BRONZE)
		border.rotation.x = PI * .5
		var face := _cylinder(mirror, Vector3(0,0,.099), .45, .45, .020, _blue_glass)
		face.rotation.x = PI * .5
		_mirrors.append(mirror)
	_hatch = _pivot(_summit, Vector3(0,.08,6.72))
	_box(_hatch, Vector3(0,0,.43), Vector3(1.45,.14,.88), BRONZE)
	_sunbeam = _pivot(_summit, first + Vector3.UP * 1.22)
	_box(_sunbeam, Vector3(0,-.25,-5.3), Vector3(.09,.09,10.6), _amber_glass)
	_sunbeam.hide()
	show_progress(&"sunwatch_observatory", 0)

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot

func _mesh(parent: Node3D, at: Vector3, shape: Mesh, material: Material) -> MeshInstance3D:
	var detail := MeshInstance3D.new()
	detail.mesh = shape
	detail.material_override = material
	detail.position = at
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(detail)
	return detail

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, at, shape, material)

func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float,
		material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 12
	shape.rings = 0
	return _mesh(parent, at, shape, material)
