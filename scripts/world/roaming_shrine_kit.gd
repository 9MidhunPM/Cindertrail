extends Node3D
## The stonework is an empty binding site. Only the player's SunCore ever occupies it.
const STONE := preload("res://art/materials/stylized/painted_stone_cream.tres")
const SHADE := preload("res://art/materials/stylized/painted_stone_shadow.tres")
const WOOD := preload("res://art/materials/stylized/painted_wood.tres")
const BRONZE := preload("res://art/materials/stylized/painted_bronze.tres")
const GOLD := preload("res://art/materials/stylized/painted_brass.tres")
const GLASS := preload("res://art/materials/stylized/painted_glazed_mirror.tres")
const ROPE := preload("res://art/materials/stylized/painted_rope.tres")
const ARCH := preload("res://art/models/ruin_arch.glb")
const PILLAR := preload("res://art/models/ruin_pillar.glb")
const AMBER_TREE := preload("res://art/models/orange_tree.glb")
const THEMES := preload("res://scripts/fx/site_draw.gd").STREAMS
const RIM_DRESSING := preload("res://scripts/world/shrine_rim_dressing.gd")

var _site: CinderSite
var _handles := PackedVector3Array()
var _origins := PackedVector3Array()
var _parts: Array[Node3D] = []
var _motion: Tween
var _lit := StandardMaterial3D.new()
var _dark_glass := StandardMaterial3D.new()
var _lamp_light: OmniLight3D
var _lantern_glass: MeshInstance3D
var _cache := Vector3.ZERO
var _impact := Vector3.ZERO

func build_camp(site: CinderSite, frame: Transform3D) -> void:
	_site = site
	name = "RoamingShrineKit"
	global_transform = frame
	site.mark_clearing()
	var id := site.checkpoint_id
	var tint: Color = THEMES[id][0]
	_lit.albedo_color = tint
	_lit.emission_enabled = true
	_lit.emission = tint
	_lit.emission_energy_multiplier = .65
	_dark_glass.albedo_color = Color("#31454c")
	_dark_glass.metallic = .36
	var location := _choose_socket(Vector3(2.65, 0, -2.45))
	var stand := _footing(location)
	_handles.append(location)
	match id:
		&"flooded_grove":
			_bell(stand)
		&"broken_quarry":
			_crane(stand)
		&"fallen_relay":
			_pylon(stand)
		&"lanternwood":
			_lantern(stand)
		&"sunken_aqueduct":
			_wheel(stand)
		&"sunwatch_observatory":
			_mirror(stand, -.65)
			var second := _choose_socket(Vector3(-3, 0, -1.8))
			_handles.append(second)
			_mirror(_footing(second), .55)
			_cache = second + second.slide(Vector3.UP).normalized() * 1.4
		&"last_lantern_frontier":
			_watchfire(stand)
	# The three glass wells give extraction streams a visible, physical origin.
	# Their shallow stone footings also communicate the extraction circle from the air.
	for i in 3:
		var angle := TAU * i / 3.0 + .45
		var well := Vector3(cos(angle),0,sin(angle)) * 1.65
		_disc(self, well + Vector3.DOWN*.08, .25, .31, .24, SHADE)
		_disc(self, well + Vector3.UP*.063, .21, .25, .07, GOLD)
		_disc(self, well + Vector3.UP*.11, .127, .16, .04, _lit)
		_origins.append(well + Vector3.UP*.14)
	RIM_DRESSING.add_rim(self, site)

func _choose_socket(preferred: Vector3) -> Vector3:
	# Move the device around the rear half of the pad when a tower socket or lane
	# would coincide with it. Keep the central retreat path and both mirror handles clear.
	var best := preferred
	var best_score := -INF
	for i in 25:
		var angle := atan2(preferred.z, preferred.x) + (i - 12) * PI / 36.0
		var point := Vector3(cos(angle), 0, sin(angle)) * preferred.length()
		var world := to_global(point)
		var gap := INF
		for marker in _site.sockets:
			gap = minf(gap, world.distance_to(marker.global_position))
		for lane in _site.lanes:
			for j in range(1, lane.size()):
				var nearest := Geometry3D.get_closest_point_to_segment(world, lane[j-1], lane[j])
				gap = minf(gap, world.distance_to(nearest))
		for previous in _handles:
			gap = minf(gap, point.distance_to(previous) - 2.4)
		var approach := Geometry3D.get_closest_point_to_segment(point, Vector3(0,0,-5), Vector3.ZERO)
		gap = minf(gap, point.distance_to(approach))
		var score := minf(gap, 2.15) - point.distance_to(preferred)*.09
		if score > best_score:
			best_score = score
			best = point
	return best

func handle_positions() -> PackedVector3Array:
	return global_transform * _handles

func handle_position() -> Vector3:
	return to_global(_handles[-1])

func energy_origins() -> PackedVector3Array:
	return global_transform * _origins

func cache_position() -> Vector3:
	return to_global(_cache)

func impact_position() -> Vector3:
	return to_global(_impact)

func show_progress(steps: int) -> void:
	match _site.checkpoint_id:
		&"lanternwood":
			_lantern_glass.material_override = _lit if steps > 0 else _dark_glass
			_lamp_light.light_energy = .56 if steps > 0 else 0.
		&"sunwatch_observatory":
			for i in _parts.size():
				_parts[i].rotation.y = .22 if steps > i else (-.65 if i == 0 else .55)

func activate(stage: int = 0) -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween()
	match _site.checkpoint_id:
		&"flooded_grove":
			var bell := _parts[0]
			bell.rotation.z = -.48
			_motion.tween_property(bell, "rotation:z", 0., 1.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		&"broken_quarry":
			var basket := _parts[0]
			_motion.tween_property(basket, "position:y", .29, .42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_motion.tween_property(basket, "position:y", 1.6, .95).set_delay(.24)
		&"fallen_relay":
			_motion.tween_property(_parts[0], "rotation:y", _parts[0].rotation.y + TAU/3, .55)
			_glimmer()
		&"sunken_aqueduct":
			_motion.tween_property(_parts[0], "rotation:z", _parts[0].rotation.z + TAU*.75, 1.2)
			_glimmer()
		&"sunwatch_observatory":
			if stage < 2:
				_motion.tween_property(_parts[stage], "rotation:y", .22, .45)
			else:
				_glimmer()
		&"lanternwood":
			show_progress(1)
			_glimmer()
		_:
			_glimmer()

func _glimmer() -> void:
	_lit.emission_energy_multiplier = 2.9
	_motion.parallel().tween_property(_lit, "emission_energy_multiplier", .65, .85)

func _bell(stand: Node3D) -> void:
	_model(stand, ARCH, Vector3(0,0,-.08), Vector3(.69, .98, .79))
	_disc(stand, Vector3(0,2.17,0), .13,.16,1.38, WOOD).rotation.z = PI/2
	var pivot := _pivot(stand, Vector3(0,2.12,0))
	_parts.append(pivot)
	_disc(pivot, Vector3(0,-.19,0), .13,.23,.29,BRONZE)
	_disc(pivot, Vector3(0,-.46,0), .22,.36,.31,BRONZE)
	_disc(pivot, Vector3(0,-.67,0), .36,.49,.16,GOLD)
	_disc(pivot, Vector3(0,-.82,0), .08,.11,.22,BRONZE)

func _crane(stand: Node3D) -> void:
	# Point the jib towards the choke so the falling basket and the damage match.
	var nearest := stand.global_position
	var gap := INF
	for lane in _site.lanes:
		for i in range(1, lane.size()):
			var projection := Geometry3D.get_closest_point_to_segment(stand.global_position, lane[i-1], lane[i])
			var distance := stand.global_position.distance_to(projection)
			if distance < gap:
				gap = distance
				nearest = projection
	var heading := to_local(nearest) - stand.position
	var reach := clampf(heading.slide(Vector3.UP).length(), .74, 2.85)
	stand.rotation.y = atan2(-heading.z, heading.x)
	_strut(stand, Vector3(-.3,0,0), Vector3(-.3,2.55,0), .16,.12,WOOD)
	_strut(stand, Vector3(-.3,1.75,0), Vector3(reach*.86,2.6,0), .10,.08,WOOD)
	_strut(stand, Vector3(-.68,2.44,0), Vector3(reach+.13,2.62,0), .14,.11,BRONZE)
	_disc(stand, Vector3(reach,2.51,0), .18,.18,.15,GOLD).rotation.x = PI/2
	_strut(stand, Vector3(reach,2.49,0), Vector3(reach,1.70,0), .026,.026,ROPE)
	var cage := _pivot(stand, Vector3(reach,1.60,0))
	_parts.append(cage)
	for side: float in [-1.,1.]:
		_strut(cage, Vector3(side*.35,-.19,0), Vector3(0,.18,0), .03,.03,GOLD)
	_disc(cage, Vector3(0,-.22,0), .43,.28,.27,BRONZE)
	for i in 3:
		var ore := _disc(cage, Vector3((i-1)*.16,-.03,-.06*i), .10,.16,.24,SHADE)
		ore.rotation.z = (i-1)*.46
	_impact = to_local(cage.global_position)
	_impact.y = 0.0

func _pylon(stand: Node3D) -> void:
	for side: float in [-1.,1.]:
		_strut(stand, Vector3(side*.47,0,0), Vector3(side*.25,1.8,0), .19,.10,STONE)
	var rotor := _pivot(stand, Vector3(0,1.98,0))
	_parts.append(rotor)
	_ring(rotor, Vector3.ZERO, .45, GOLD).rotation.x = PI/2
	_ring(rotor, Vector3.ZERO, .30, BRONZE).rotation.z = PI/2
	_disc(rotor, Vector3.ZERO, .035,.13,.49,_lit)

func _lantern(stand: Node3D) -> void:
	_model(stand, AMBER_TREE, Vector3(-.74,-.05,-.52), Vector3(.93,1.03,.93))
	_strut(stand, Vector3(-.38,0,0), Vector3(-.43,2.26,0), .16,.10,WOOD)
	_strut(stand, Vector3(-.50,1.56,0), Vector3(.40,2.27,0), .105,.072,WOOD)
	_strut(stand, Vector3(-.64,2.22,0), Vector3(.51,2.29,0), .082,.06,BRONZE)
	_strut(stand, Vector3(.39,2.26,0), Vector3(.39,1.91,0), .023,.023,ROPE)
	_disc(stand, Vector3(.39,1.85,0), .08,.30,.18,GOLD)
	_lantern_glass = _disc(stand, Vector3(.39,1.58,0), .22,.18,.42,_dark_glass)
	_lamp_light = _lamplight(stand, Vector3(.39,1.58,.14), 0.)
	_disc(stand, Vector3(.39,1.33,0), .27,.09,.16,BRONZE)
	for i in 5:
		var angle := i*TAU/5
		var edge := Vector3(cos(angle),0,sin(angle))*.20
		_strut(stand,Vector3(.39,1.36,0)+edge,Vector3(.39,1.78,0)+edge,.025,.025,GOLD)

func _wheel(stand: Node3D) -> void:
	_model(stand, ARCH, Vector3(0,-.04,-.51), Vector3(.68,.84,.90))
	for side: float in [-1.,1.]:
		_disc(stand, Vector3(side*.50,.46,-.07), .19,.23,.92,STONE)
	var wheel := _pivot(stand, Vector3(0,1.05,.11))
	_parts.append(wheel)
	_ring(wheel, Vector3.ZERO, .68, BRONZE).rotation.x = PI/2
	_disc(wheel,Vector3.ZERO,.13,.14,.39,GOLD).rotation.x = PI/2
	for i in 8:
		var tip := Vector3(cos(TAU*i/8.),sin(TAU*i/8.),0)
		_strut(wheel, Vector3.ZERO,tip*.67,.036,.05,WOOD)
		_disc(wheel,tip*.68,.068,.085,.32,GOLD).rotation.x = PI/2

func _mirror(stand: Node3D, yaw: float) -> void:
	_disc(stand,Vector3(0,.72,0),.14,.22,1.37,STONE)
	var lens := _pivot(stand,Vector3(0,1.63,0))
	_parts.append(lens)
	lens.rotation.y = yaw
	_ring(lens,Vector3.ZERO,.53,GOLD).rotation.x = PI/2
	var glass := _disc(lens,Vector3.ZERO,.49,.48,.085,GLASS)
	glass.rotation.x = PI/2
	_disc(lens,Vector3(0,0,.07),.10,.13,.06,_lit).rotation.x = PI/2

func _watchfire(stand: Node3D) -> void:
	_model(stand, PILLAR, Vector3.ZERO, Vector3(1.35,.69,1.35))
	_disc(stand, Vector3(0,1.7,0), .59,.36,.22,GOLD)
	for i in 3:
		var a := TAU * i / 3.0
		var foot := Vector3(cos(a),0,sin(a)) * .38
		_strut(stand, foot+Vector3.UP*1.72, foot*1.45+Vector3.UP*(2.26+.22*i), .11,.036,BRONZE)
	_disc(stand, Vector3(0,1.98,0), .036,.15,.36,_lit)
	_lamp_light = _lamplight(stand, Vector3(0,2.06,0), .62)

func _lamplight(host: Node3D, at: Vector3, energy: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffc078")
	lamp.light_energy = energy
	lamp.omni_range = 3.65
	lamp.shadow_enabled = false
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 20.
	lamp.distance_fade_length = 8.
	host.add_child(lamp)
	lamp.position = at
	return lamp

func _model(host: Node3D, scene: PackedScene, at: Vector3, size: Vector3) -> void:
	var model := scene.instantiate() as Node3D
	host.add_child(model)
	model.position = at
	model.scale = size
	for piece: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.visibility_range_end = 105.

func _footing(at: Vector3) -> Node3D:
	var base := _pivot(self, at)
	_disc(base, Vector3(0,-.14,0), .73,.85,.40,SHADE)
	_disc(base, Vector3(0,.08,0), .66,.75,.13,STONE)
	_disc(base, Vector3(0,.16,0), .46,.54,.06,BRONZE)
	return base

func _pivot(host: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	host.add_child(node)
	node.position = at
	return node

func _strut(host: Node3D, a: Vector3, b: Vector3, bottom: float, top: float, material: Material) -> MeshInstance3D:
	var line := b-a
	var rod := _disc(host,(a+b)*.5,top,bottom,line.length(),material)
	rod.quaternion = Quaternion(Vector3.UP, line.normalized())
	return rod

func _disc(host: Node3D, at: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.radial_segments = 10
	shape.rings = 0
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	return _mesh(host, at, shape, material)

func _ring(host: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.rings = 20
	shape.ring_segments = 5
	shape.inner_radius = radius-.043
	shape.outer_radius = radius+.043
	return _mesh(host, at, shape, material)

func _mesh(host: Node3D, at: Vector3, shape: Mesh, material: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = shape
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.visibility_range_end = 105.
	piece.visibility_range_end_margin = 5.
	host.add_child(piece)
	piece.position = at
	return piece
