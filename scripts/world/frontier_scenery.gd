extends Node3D
## Static walkable bridge spans and pads with painted masonry, distant rock shelves, and warm ruin lights.

const ARCH := preload("res://art/models/ruin_arch.glb")
const PILLAR := preload("res://art/models/ruin_pillar.glb")
const TREE := preload("res://art/models/teal_tree.glb")
const COPPER_TREE := preload("res://art/models/orange_tree.glb")
const CACHE := preload("res://art/models/supply_crate.glb")
const WATER := preload("res://art/materials/frontier_water.gdshader")
const FALL := preload("res://art/materials/grove/waterfall.gdshader")
const PAINT := preload("res://art/materials/grove/weathered_palette.gdshader")

var _random := RandomNumberGenerator.new()
var _ground := StaticBody3D.new()
var _stone: ShaderMaterial
var _bronze: Material
var _lantern: StandardMaterial3D
var _wood: Material
var _rock_mesh := CylinderMesh.new()
var _slab_mesh := BoxMesh.new()
var _batches: Dictionary = {}
var _moth_groups: Array[Node3D] = []
var _clock := 0.0

func initialize(scenery_seed: int) -> void:
	_random.seed = scenery_seed
	_ground.name = "TrailCollision"
	add_child(_ground)
	_rock_mesh.top_radius = .44
	_rock_mesh.bottom_radius = .66
	_rock_mesh.height = 1.0
	_rock_mesh.radial_segments = 6
	_stone = ShaderMaterial.new()
	_stone.shader = PAINT
	_stone.set_shader_parameter("route_paint", preload("res://art/textures/stylized/route_paint.png"))
	_stone.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	_stone.set_shader_parameter("waterline", -.5)
	_bronze = preload("res://art/materials/stylized/painted_bronze.tres")
	_wood = preload("res://art/materials/stylized/painted_wood.tres")
	_lantern = _tint(Color("#ffd08d"), .58)
	_lantern.emission_enabled = true
	_lantern.emission = Color("#f2914d")
	_lantern.emission_energy_multiplier = 1.7

func surroundings() -> void:
	# Low turquoise water and staggered, deep silhouettes define the quarry's flooded outlet.
	var plane := PlaneMesh.new()
	plane.size = Vector2(265, 340)
	var water := ShaderMaterial.new()
	water.shader = WATER
	water.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	_instance(plane, Vector3(52, -.5, 378), water, false)
	for i in 27:
		var z := 235.0 + 12.5 * i
		for side in [-1.0, 1.0]:
			var x: float = 53 + side * _random.randf_range(87, 112)
			var y := _random.randf_range(7.2, 18)
			var position := Vector3(x, -.35, z)
			_shelf(position, Vector3(_random.randf_range(13, 24), y, _random.randf_range(14, 27)), Color("#445c65"))
			if i % 2 == 0:
				_asset(TREE if i % 4 == 0 else COPPER_TREE,
					position + Vector3.UP * (y + 1.5), _random.randf_range(1.15, 2.2), _random.randf_range(0, TAU), 120.0)
	for i in 16:
		var z := _random.randf_range(308, 449)
		var point := Vector3(_random.randf_range(38, 73), -.42, z)
		var scale := Vector3(_random.randf_range(5.5, 13), _random.randf_range(1.2, 4.5), _random.randf_range(4, 10))
		_shelf(point, scale, Color("#3e6865"))
		if i % 3 == 0:
			_asset(TREE if i % 2 == 0 else COPPER_TREE, point + Vector3.UP * (scale.y + .65), .9, i * .66, 100.0)

func walkway(path: PackedVector3Array, style: int) -> void:
	var palette := [Color("#aaa68a"), Color("#b2a180"), Color("#82968f")]
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var direction := a.direction_to(b)
		var rotation := atan2(direction.x, direction.z)
		var side := direction.cross(Vector3.UP)
		var length := a.distance_to(b)
		var width := 4.9 if style == 0 else 5.4
		var middle := (a + b) * .5
		_floor(middle, Vector3(width, 1.05, length + 1.0), rotation)
		_queue(_slab_mesh, middle - Vector3.UP * .56, Vector3(width, .99, length + .67),
			rotation, palette[style].darkened(.36))
		var tile_count := ceili(length / 2.3)
		for row in tile_count:
			var along := a.lerp(b, (row + .5) / tile_count)
			for j in 3:
				var tile_side := side * ((float(j) - 1.0) * width / 3.0 + _random.randf_range(-.065, .065))
				var tile_size := Vector3(width / 3.0 - _random.randf_range(.05, .15), .22, length / tile_count - .075)
				var dye: Color = palette[style].lightened(_random.randf_range(-.11, .12))
				_queue(_slab_mesh, along + tile_side - Vector3.UP * .106, tile_size, rotation, dye)
			if row % 3 == 0:
				var sign_side := -1.0 if row % 2 == 0 else 1.0
				var edge := along + side * sign_side * (width * .49)
				_queue(_rock_mesh, edge - Vector3.UP * .98, Vector3(.88, 6.65, 1.87),
					rotation, palette[style].darkened(.29))
				_queue(_slab_mesh, edge + Vector3.UP * .17, Vector3(.30, .37, .88),
					rotation, palette[style].lightened(.06))
			if row % 6 == 1 and style != 0:
				var shore_side := -1.0 if style == 1 else 1.0
				var shore := along + side * (shore_side * _random.randf_range(6.8, 10.0))
				var height := _random.randf_range(4.0, 6.0)
				_shelf(Vector3(shore.x, -.5, shore.z), Vector3(5, height, 7.6), Color("#47655e"))
				_asset(COPPER_TREE if row % 2 == 0 else TREE,
					Vector3(shore.x, height + .1, shore.z), _random.randf_range(.8, 1.5), rotation, 85.0)
		if i < path.size() - 1:
			island(b, width * .54, 7, palette[style])
		if style == 1:
			_cliff_terrace(a, b, side)
		elif style == 2:
			_drowned_span(middle, rotation, width)
		# Sparse lanterns mark bends and keep the route visible in the fog.
		if i % 2 == 1:
			var nook := a.lerp(b, .78) + side * (width * .43)
			_road_lantern(nook, false)
			_shelf(middle - Vector3.UP * 6.1, Vector3(4, 4.6, 9.5), palette[style].darkened(.33))

func _cliff_terrace(a: Vector3, b: Vector3, side: Vector3) -> void:
	var stages := ceili(a.distance_to(b) / 9.0)
	for i in stages:
		var at := a.lerp(b, (float(i) + .5) / stages)
		at -= side * _random.randf_range(7.6, 9.4)
		var rise := _random.randf_range(8.0, 13.0)
		_shelf(Vector3(at.x, -1.6, at.z), Vector3(6.8, rise, 10.2), Color("#786f65"))
		if i == floori(stages * .5):
			_asset(COPPER_TREE, Vector3(at.x, rise - .8, at.z), .78, i * 1.4, 80.0)

func _drowned_span(at: Vector3, yaw: float, width: float) -> void:
	# Broken parapets frame the water while leaving the plank deck free for travel and pursuers.
	var toward := Basis(Vector3.UP, yaw)
	for side in [-1.0, 1.0]:
		var foot: Vector3 = at + toward.x * side * (width * .5 + .25)
		_asset(PILLAR, foot - Vector3.UP * 1.53, .78, yaw + .16 * side, 65.0)
		for i in 3:
			var slab := foot + toward.z * (float(i) - 1.0) * 1.52
			_queue(_slab_mesh, slab + Vector3.UP * .24, Vector3(.47,.49,_random.randf_range(.8,1.4)),
				yaw, Color("#79958e"))

func island(at: Vector3, radius: float, sides: int, color: Color) -> void:
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = radius
	floor_shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = floor_shape
	collision.position = at - Vector3.UP * .6
	_ground.add_child(collision)
	var platform := CylinderMesh.new()
	platform.top_radius = radius
	platform.bottom_radius = radius * .79
	platform.radial_segments = sides
	platform.height = .9
	_instance(platform, at - Vector3.UP * .45, _tint(color, .92))
	_shelf(at - Vector3.UP * 5.2,
		Vector3(radius * 1.55, 4.8, radius * 1.55), color.darkened(.39))

func camp(at: Vector3) -> void:
	_asset(ARCH, at + Vector3(0, 0, 6.5), 2.15, 0.0, 105.0)
	_asset(PILLAR, at + Vector3(-5.5, 0, 3.3), 1.12, -.25, 80.0)
	_asset(PILLAR, at + Vector3(5.8, 0, 3.6), 1.30, .10, 80.0)
	for side in [-1.0, 1.0]:
		_road_lantern(at + Vector3(side * 4.6, 0, 4.8), true)
		var shelf := at + Vector3(side * 12.0, -5.65, 10)
		_shelf(shelf, Vector3(8.0, 7.5, 11.5), Color("#476660"))
		_asset(COPPER_TREE, shelf + Vector3.UP * 8.5, 1.9, -side * .9, 100.0)
	for index in 18:
		var angle := TAU * index / 18.0
		var rim := Vector3(cos(angle), 0, sin(angle))
		var brand := at + rim * 6.2 + Vector3.UP * .016
		_queue(_slab_mesh, brand, Vector3(.16, .021, .83), -angle + PI * .5, Color("#78634b"))

func spillway(left: Vector3, right: Vector3) -> void:
	var origin := (left + right) * .5
	_asset(ARCH, origin + Vector3.UP * .10, 1.6, 0.0, 100.0)
	for edge in [left, right]:
		var steps: Vector3 = edge + Vector3(0, -3.1, 1.7)
		var fall := QuadMesh.new()
		fall.size = Vector2(2.2, 4.0)
		var water := ShaderMaterial.new()
		water.shader = FALL
		_instance(fall, steps + Vector3.UP, water, false)
		_shelf(edge - Vector3.UP * 5.4, Vector3(5.4, 4.8, 8.0), Color("#50736e"))
		_road_lantern(edge + Vector3(0, 0, -1.3), true)

func discovery(kind: int, start: Vector3, end: Vector3, facing: Vector3) -> Dictionary:
	var yaw := atan2(-facing.x, -facing.z)
	var machinery := Node3D.new()
	machinery.position = start
	machinery.rotation.y = yaw
	add_child(machinery)
	match kind:
		0:
			_asset(PILLAR, start - Vector3.UP * .18, .57, yaw + .33, 50.0)
			_road_lantern(start, false)
		1:
			# A rope trails from the beam to the animated cradle, tucked beside the walkway.
			for x in [-.77, .77]:
				_attach(machinery, Vector3(x, 1.24, 0), Vector3(.19, 2.5, .25), _wood)
			_attach(machinery, Vector3(0, 2.5, 0), Vector3(1.96, .21, .30), _wood)
			var cradle := Node3D.new()
			cradle.position = start + Vector3.UP * 1.76
			add_child(cradle)
			_attach(cradle, Vector3.ZERO, Vector3(1.14, .33, .78), _bronze)
			for x in [-.45, .45]:
				_attach(cradle, Vector3(x, .43, 0), Vector3(.031, .86, .031), preload("res://art/materials/stylized/painted_rope.tres"))
			machinery = cradle
		2:
			_road_lantern(start, false)
			var disk := CylinderMesh.new()
			disk.top_radius = .61
			disk.bottom_radius = .64
			disk.height = .10
			disk.radial_segments = 12
			var mirror := MeshInstance3D.new()
			mirror.mesh = disk
			mirror.material_override = preload("res://art/materials/stylized/painted_glazed_mirror.tres")
			mirror.position = Vector3.UP * 1.38
			mirror.rotation.x = PI * .46
			machinery.add_child(mirror)
	var guide := Node3D.new()
	guide.position = start
	add_child(guide)
	for i in 7:
		var wing := SphereMesh.new()
		wing.radial_segments = 5
		wing.rings = 3
		wing.radius = .052
		wing.height = .11
		var mote := MeshInstance3D.new()
		mote.mesh = wing
		mote.material_override = _lantern
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mote.visibility_range_end = 30.0
		guide.add_child(mote)
	_moth_groups.append(guide)
	var reward := _asset(CACHE, end, .88, yaw, 40.0)
	reward.visible = false
	var beam: MeshInstance3D
	if kind == 2:
		var ray_start := start + Vector3.UP * 1.37
		var ray_end := end + Vector3.UP * .5
		var shaft := CylinderMesh.new()
		shaft.top_radius = .028
		shaft.bottom_radius = .095
		shaft.height = ray_start.distance_to(ray_end)
		shaft.radial_segments = 5
		beam = _instance(shaft, ray_start.lerp(ray_end, .5), _lantern, false)
		beam.basis = Basis(Quaternion(Vector3.UP, ray_start.direction_to(ray_end)))
		beam.visible = false
	return {"marker": reward, "guide": guide, "moving": machinery, "beam": beam}

func finish() -> void:
	for mesh: Mesh in _batches:
		var transforms: Array = _batches[mesh]
		var collection := MultiMesh.new()
		collection.transform_format = MultiMesh.TRANSFORM_3D
		collection.use_colors = true
		collection.mesh = mesh
		collection.instance_count = transforms.size()
		for i in transforms.size():
			collection.set_instance_transform(i, transforms[i][0])
			collection.set_instance_color(i, transforms[i][1])
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = collection
		visual.material_override = _stone
		add_child(visual)
	_batches.clear()

func _process(delta: float) -> void:
	_clock += delta
	for group in _moth_groups:
		if not group.visible:
			continue
		for i in group.get_child_count():
			var mote := group.get_child(i) as Node3D
			var phase := _clock * (1.15 + .035 * i) + TAU * i / 7.0
			mote.position = Vector3(cos(phase) * (.65 + .13 * i),
				.98 + sin(phase * 1.8) * .40 + .073 * i, sin(phase) * (.67 + .048 * i))

func _floor(at: Vector3, size: Vector3, yaw: float) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = at - Vector3.UP * (size.y * .5)
	collision.rotation.y = yaw
	_ground.add_child(collision)

func _shelf(at: Vector3, scale: Vector3, pigment: Color) -> void:
	for layer in 3:
		var band := float(layer) / 3.0
		var color := pigment.lightened(band * .19 + _random.randf_range(-.06, .055))
		var layer_scale := scale * Vector3(1.08 - .14 * band, .57, 1.06 - .12 * band)
		var position := at + Vector3(_random.randf_range(-1.1, 1.1), scale.y * (.2 + band), _random.randf_range(-1.1, 1.1))
		_queue(_rock_mesh, position, layer_scale, _random.randf_range(-.5, .5), color)

func _road_lantern(at: Vector3, lit: bool) -> void:
	var frame := Vector3(.28, 1.06, .29)
	_instance(_slab_mesh, at + Vector3.UP * .51, _bronze).scale = frame
	_instance(_slab_mesh, at + Vector3.UP * 1.11, _lantern, false).scale = Vector3(.31, .24, .31)
	var cap := CylinderMesh.new()
	cap.top_radius = .06
	cap.bottom_radius = .27
	cap.height = .22
	cap.radial_segments = 6
	_instance(cap, at + Vector3.UP * 1.34, _bronze)
	if lit:
		var light := OmniLight3D.new()
		light.position = at + Vector3.UP * 1.13
		light.light_color = Color("#e9a563")
		light.light_energy = 1.16
		light.omni_range = 4.8
		add_child(light)

func _tint(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _queue(mesh: Mesh, at: Vector3, size: Vector3, yaw: float, pigment: Color) -> void:
	if not _batches.has(mesh):
		_batches[mesh] = []
	var transform := Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), at)
	_batches[mesh].append([transform, pigment])

func _instance(mesh: Mesh, at: Vector3, material: Material, shadow := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	if not shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _asset(scene: PackedScene, at: Vector3, size: float, yaw: float, distance: float) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = at
	node.scale = Vector3.ONE * size
	node.rotation.y = yaw
	add_child(node)
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	for visual: MeshInstance3D in meshes:
		visual.visibility_range_end = distance
	return node

func _attach(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _slab_mesh
	node.position = at
	node.scale = size
	node.material_override = material
	parent.add_child(node)
