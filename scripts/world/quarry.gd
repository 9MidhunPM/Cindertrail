class_name CinderQuarry
extends Node3D

const DATA := preload("res://data/sites/quarry.tres")
const ARCH := preload("res://art/models/ruin_arch.glb")
const PILLAR := preload("res://art/models/ruin_pillar.glb")
const STONE_SHADER := preload("res://art/materials/highland/limestone.gdshader")
const SURFACE_DETAIL := preload("res://scripts/world/valley_surface_detail.gd")
const TREE := preload("res://art/models/orange_tree.glb")
const GROUND := Vector3(-53, 1.15, 0)
const TRAIL := [
	Vector3(-24.0, 0.68, 1.0), Vector3(-28.0, 0.68, 1.0),
	Vector3(-33.0, 0.82, 2.4), Vector3(-39.0, 1.02, 2.0),
	Vector3(-45.0, 1.15, 0.0), Vector3(-47.0, 1.15, 0.0),
]
const LIMESTONE := Color("#cbb28b")
const CHALK := Color("#ead4a9")
const SEDIMENT := Color("#796b60")
const SOIL := Color("#8f7962")
const TIMBER := Color("#976b44")
const BRONZE := Color("#936438")
const IRON := Color("#443e40")
const COPPER := Color("#bc652a")

var site: CinderSite
var layout_id := 0
var randomized_layout := false
var clearing_variant := 0
var _pad := GROUND
var caches := PackedVector3Array([Vector3(-36.0, 0.91, 5.76)])
const DROP_TIME := .42
var landmark_position := Vector3(-59.6, 1.15, -2.35)
var impact_position := Vector3(-62.21, 1.17, -.47)
var _cradle_pivot: Node3D
var _cradle: Node3D
var _rope: MeshInstance3D
var _target: MeshInstance3D
var _dust: CPUParticles3D
var _drop: Tween
var _hoist_depth := 1.55
var _drop_running := false
var _sway_time := 0.0
var _rng := RandomNumberGenerator.new()
var _solid := StaticBody3D.new()
var _surf := SurfaceTool.new()

func _ready() -> void:
	if randomized_layout:
		# The short crane-side hold exposes the traveler to the mine entrance.
		# The loading court gives a longer firing lane and a shorter retreat.
		_pad = Vector3(-57.2, 1.15, 1.4) if clearing_variant == 0 else Vector3(-49.4, 1.15, -1.6)
	_rng.seed = 41926
	_solid.name = "StaticQuarryCollision"
	add_child(_solid)
	_surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surf.set_smooth_group(-1)
	_build_trail()
	_build_court()
	_build_cut_faces()
	_extraction_gallery()
	_build_crane(Vector3(-60.0, 1.15, -4.15), -.54, 1.16, true)
	_build_crane(Vector3(-50.0, 5.70, -7.65), 0.48, 0.8)
	_loading_tracks()
	_finish_geometry()
	_configure_site()
	_relocate(CinderDistricts.offset("quarry", layout_id))

## Geometry is authored around the old origin; move it out along the valley.
func _relocate(shift: Vector3) -> void:
	position = shift
	site.shift_world(shift)
	for i in caches.size():
		caches[i] += shift

func world_landmark() -> Vector3:
	return landmark_position + position

func world_impact() -> Vector3:
	return impact_position + position

func map_paths() -> Array[PackedVector3Array]:
	var approach := PackedVector3Array(TRAIL)
	approach.append(_pad)
	return [global_transform * approach, global_transform * PackedVector3Array([
		Vector3(-36, .92, 2), Vector3(-36, .92, 6.5)])]

func _configure_site() -> void:
	site = CinderSite.new()
	site.name = "BrokenQuarrySite"
	var sockets := PackedVector3Array([
		Vector3(-55.0, 1.18, -2.58), Vector3(-50.1, 1.18, -3.0),
		Vector3(-51.0, 1.18, 2.9), Vector3(-57.0, 1.18, 2.45),
	])
	var lane := PackedVector3Array([
		Vector3(-68, 1.15, -0.5), Vector3(-65, 1.15, 0.15),
		Vector3(-61.0, 1.15, 0.15), Vector3(-57.5, 1.15, -0.6), _pad,
	])
	if randomized_layout:
		if clearing_variant == 0:
			lane[-2] = Vector3(-59.4, 1.15, .45)
			sockets = PackedVector3Array([Vector3(-58, 1.18, -2.9), Vector3(-54.1, 1.18, -.8),
				Vector3(-54.2, 1.18, 3.2), Vector3(-59.2, 1.18, 3.5)])
		else:
			sockets = PackedVector3Array([Vector3(-57.4, 1.18, 2.7), Vector3(-55.7, 1.18, -3.1),
				Vector3(-50.4, 1.18, 2.6), Vector3(-48, 1.18, .9)])
	var framing := (_pad - GROUND) * .40
	site.configure(DATA, _pad, sockets, [lane],
		Vector3(-64.0, 13.6, 16.8) + framing, Vector3(-55.6, 1.48, 0.0) + framing)
	site.habitat_frame.origin = GROUND
	add_child(site)

func _build_trail() -> void:
	for index in range(TRAIL.size() - 1):
		var from: Vector3 = TRAIL[index]
		var to: Vector3 = TRAIL[index + 1]
		var width := 3.1 + float(index) * 0.37
		_span_floor(from, to, width)
		var direction := to - from
		direction.y = 0.0
		var side := direction.normalized().cross(Vector3.UP)
		var count := ceili(direction.length() / 0.93)
		for row in range(count):
			var start := from.lerp(to, float(row) / count)
			var end := from.lerp(to, float(row + 1) / count)
			for col in range(3):
				var begin_offset := side * width * (float(col) / 3.0 - .5)
				var end_offset := side * width * (float(col + 1) / 3.0 - .5)
				_tile(start + begin_offset, start + end_offset, end + end_offset, end + begin_offset, _stone())
		if index > 0:
			for shoulder in [-1.0, 1.0]:
				var offset: Vector3 = side * shoulder * (width * .5 + .65)
				var bank := (from + to) * .5 + offset
				_rock(bank - Vector3.UP * .50, Vector3(direction.length() * .60, .7, 1.48), SEDIMENT)
				_rocks_and_grass(from + offset, index + 2)
	# The supply ledge opens to the south without pinching the main passage.
	var turn := Vector3(-36.0, 0.92, 2.0)
	var alcove := Vector3(-36.0, 0.92, 6.5)
	_span_floor(turn, alcove, 3.0)
	_slab(Vector3(-36.0, .9, 5.25), Vector2(3.15, 3.15), .39, LIMESTONE, true)
	_rock(Vector3(-37.5, .2, 6.8), Vector3(1.8, 1.45, 1.5), SEDIMENT)
	_rock(Vector3(-34.3, .36, 6.2), Vector3(1.22, 1.78, .98), LIMESTONE)
	_lantern(Vector3(-34.45, .93, 5.8))
	_asset(ARCH, Vector3(-31.15, 0.72, 1.9), Vector3(1.37, 1.46, 1.22), PI * 0.5)
	for z in [0.28, 3.52]:
		_box_shape(Vector3(-31.15, 1.85, z), Vector3(0.54, 2.35, 0.46))
	_asset(TREE, Vector3(-39.0, 1.0, 5.7), Vector3.ONE * 1.36, 1.6)
	_lantern(Vector3(-40.1, 1.03, 3.62))
	_lantern(Vector3(-45.5, 1.15, -2.55))
	_quarry_railing()

func _quarry_railing() -> void:
	# Openings in the handrail keep both the alcove and plaza exits easy to read.
	for p: Vector3 in [Vector3(-25.4, .69, 2.42), Vector3(-30.15, .74, 2.58),
			Vector3(-40.75, 1.03, 3.7), Vector3(-44.50, 1.14, 3.15)]:
		var direction := Vector3(-1, .025, .10)
		var last := p
		for bay in 3:
			var next := p + direction * (bay + 1.0) * 1.17
			_bar(last, last + Vector3.UP * .89, .18, TIMBER)
			_bar(last + Vector3.UP * .70, next + Vector3.UP * .70, .105, TIMBER.lightened(.15))
			_bar(last + Vector3.UP * .47, next + Vector3.UP * .47, .071, TIMBER.darkened(.16))
			_bar(last + Vector3.UP * .65, last + Vector3.UP * .78, .21, Color("#ba935a"))
			last = next
		_bar(last, last + Vector3.UP * .89, .18, TIMBER)

func _build_court() -> void:
	_box_shape(Vector3(-53.75, .56, 0.03), Vector3(13.7, 1.18, 9.5))
	_box_shape(Vector3(-64.18, .56, -0.18), Vector3(8.4, 1.18, 4.0))
	_slab(Vector3(-53.75, 1.06, 0.03), Vector2(13.65, 9.45), 1.22, SOIL)
	_slab(Vector3(-64.18, 1.06, -0.18), Vector2(8.36, 3.96), 1.0, SEDIMENT)
	for row in range(17):
		var x := -68.1 + float(row) * 1.22
		var width := 2.0 if x < -60.25 else 4.65
		var sections := 4 if x < -60.25 else 8
		for col in range(sections):
			var z := -width + float(col) * width * 2.0 / sections
			var next := z + width * 2.0 / sections
			var height := _rng.randf_range(1.12, 1.149)
			var break_line := .20 * sin(z * 2.35 + row * .9)
			var end_break := .20 * sin(next * 2.35 + row * .9)
			var end_line := .20 * sin(z * 2.35 + (row + 1) * .9)
			var end_next := .20 * sin(next * 2.35 + (row + 1) * .9)
			_tile(Vector3(x + break_line, height, z), Vector3(x + end_break, height, next),
				Vector3(x + 1.20 + end_next, height, next), Vector3(x + 1.20 + end_line, height, z), _stone())
	# A weathered inlaid sundial surrounds the deployment anchor.
	var radius := 1.45
	for step in range(28):
		var a := TAU * step / 28.0
		var b := TAU * (step + 1) / 28.0
		var inset := _pad + Vector3.UP * .017
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(b), 0, sin(b))
		_quad(inset + p * (radius - .08), inset + p * radius,
			inset + q * radius, inset + q * (radius - .08), BRONZE, Vector3.UP)
	for step in range(8):
		var a := TAU * step / 8.0
		var p := Vector3(cos(a), 0, sin(a))
		var side := p.cross(Vector3.UP) * .037
		var base := _pad + p * 1.13 + Vector3.UP * .019
		_tri(base - side, base + side, base + p * .2, BRONZE, Vector3.UP)
	_lantern(Vector3(-59.5, 1.15, 2.6))
	_lantern(Vector3(-51.3, 1.15, -4.25))
	_lantern(Vector3(-64.0, 1.15, -1.72))

func _build_cut_faces() -> void:
	# Inner ledges enforce the western choke. Upper terraces add tall silhouettes behind it.
	_rock_wall(-68.7, -61.2, -3.05, 4.6, 1.64)
	_rock_wall(-68.5, -61.0, 2.65, 1.16, 1.1)
	_rock_wall(-61.6, -44.0, -6.25, 5.3, 1.58)
	_rock_wall(-59.7, -45.2, 5.87, 1.28, 1.30)
	_rock_wall(-67.9, -46.2, -10.25, 8.05, 2.32)
	_rock_wall(-65.0, -38.6, 11.0, 2.15, 2.7)
	_build_scree()
	_rock_wall(-44.4, -32.75, -2.68, 2.75, 1.70)
	_rock_wall(-39.5, -27.4, -2.15, 1.87, 1.52)
	for i in range(22):
		var z: float = [-1.0, 1.0][i % 2] * _rng.randf_range(5.15, 7.3)
		var p := Vector3(_rng.randf_range(-61, -44), 1.15, z)
		_rocks_and_grass(p, 3)
	_asset(PILLAR, Vector3(-58.55, 1.15, -4.42), Vector3(1.12, 1.57, 1.12), .07)
	_asset(PILLAR, Vector3(-46.76, 1.15, -3.77), Vector3(1.1, 1.36, 1.1), .17)
	_asset(TREE, Vector3(-43.1, 1.15, -5.55), Vector3.ONE * 1.32, 1.8)
	_rock(Vector3(-64.3,-2.0,7.30),Vector3(2.6,3.2,2.15),SEDIMENT)
	_burnished_tree(Vector3(-64.3,1.15,7.3),1.0)

func _build_scree() -> void:
	# Below the carved terraces, broad sloping slabs connect the tall faces to the valley.
	for i in range(7):
		var x := -70.0 + float(i) * 5.3
		for side in [-1.0, 1.0]:
			var ledge := Vector3(x, -3.6, side * 8.1)
			_rock(ledge, Vector3(5.0, 4.0, 7.4), SEDIMENT.lerp(LIMESTONE, .23))
			var skirt := Vector3(x + 2.2, -8.4, side * 11.5)
			_rock(skirt, Vector3(6.9, 5.5, 10.0), Color("#46526a"))
	_rock(Vector3(-71.2, -3.9, -0.1), Vector3(5.2, 4.2, 5.1), SEDIMENT)

func _rock_wall(west: float, east: float, z: float, height: float, width: float) -> void:
	var step := 2.04
	var count := ceili((east - west) / step)
	for i in range(count):
		var x := lerpf(west, east, (float(i)+.48) / count)
		var varied_height := height * _rng.randf_range(.66, 1.16)
		var offset_z := _rng.randf_range(-.27, .27)
		var origin := Vector3(x, .6, z + offset_z)
		if is_equal_approx(z,-6.25) and x> -55.6 and x< -49.9:
			# The quarrymen cut back this section to accommodate the loading stage.
			origin.z-=2.25
			varied_height*=.65
		_rock(origin, Vector3(1.40, varied_height, width), _stone())
		_box_shape(origin + Vector3.UP * (varied_height * .42), Vector3(2.14, varied_height, width * 1.66))
		if height > 4.3:
			var ledge := origin + Vector3(0.16, varied_height * .53, signf(z) * .69)
			_rock(ledge, Vector3(1.39, varied_height * .60, width * .79), LIMESTONE.lightened(.06))
		if i % 2 == 0:
			var split := origin + Vector3(.52, .08, -signf(z) * width * .65)
			_rock(split, Vector3(.68, varied_height * .55, width * .57), SEDIMENT.lerp(LIMESTONE, .58))

## Rectangular quarry benches, unfinished stone and the elevated timber winch
## distinguish the cut faces from the natural scree below the road.
func _extraction_gallery() -> void:
	for i in 13:
		var x := -68.5+i*1.97
		var z := -7.4+.38*sin(i*.74)
		var top := 3.6+(.54 if i%4 in [1,2] else .1)+.8*cos(i*.69)
		_slab(Vector3(x,top,z),Vector2(2.02,3.48),top-1.05,LIMESTONE.darkened(.08*(i%3)))
		_slab(Vector3(x+.12,top+1.84,z-1.28),Vector2(2.39,2.22),2.04,_stone())
		if i%2==0:
			for k in 4:
				var start := Vector3(x-.52+k*.24,top-.12,z+1.745)
				_bar(start,start+Vector3(.04,-.55-_rng.randf_range(.0,.28),.0),.019,SEDIMENT)
	for i in 3:
		var step := Vector3(-60.4+i*1.10,1.15+i*.21,-4.98)
		_slab(step,Vector2(1.33,1.12),.82,_stone(),true)
	for i in 7:
		var x := -48.6+(i%3)*.74
		var z := -4.5-(i/3)*.86
		var high := 1.70+(.32 if i in [2,6] else .0)
		_slab(Vector3(x,high,z),Vector2(.69,.77),high-1.12,_stone(),true)
	for i in 5:
		var x := -54.7+i*1.05
		_slab(Vector3(x,3.81,-5.93),Vector2(1.02,1.62),.19,TIMBER,true)
	for x: float in [-54.6,-52.55,-50.65]:
		for z: float in [-5.22,-6.6]:
			var foot := Vector3(x,1.12,z)
			_bar(foot,foot+Vector3.UP*2.85,.16,TIMBER)
			_bar(foot+Vector3.UP*1.38,foot+Vector3(.73,2.56,0),.12,TIMBER.lightened(.1))
	for i in 2:
		_bar(Vector3(-54.67,1.16,-4.90-i*.46),Vector3(-54.67,3.79,-5.45-i*.46),.088,TIMBER)
	for i in 8:
		var foot := Vector3(-54.67,1.27+i*.33,-4.93-i*.069)
		_bar(foot,foot+Vector3.FORWARD*.46,.069,TIMBER)
	_loading_awning(Vector3(-52.65, 3.81, -5.93))
	_lantern(Vector3(-54.62,3.85,-5.43))
	_lantern(Vector3(-60.52,1.15,-3.02))
	# Timber cap and curved stone lintel at the mouth of the crawler lane.
	var entry := Vector3(-67.70,1.15,-.15)
	for side: float in [-1.,1.]:
		var post := entry+Vector3(0,0,side*1.71)
		_bar(post,post+Vector3.UP*2.56,.26,TIMBER)
		_bar(post+Vector3.UP*1.75,post+Vector3(0,2.48,-side*.65),.17,TIMBER)
		_slab(post+Vector3.UP*.23,Vector2(.62,.6),.25,SEDIMENT)
	_bar(entry+Vector3(0,2.64,-1.98),entry+Vector3(0,2.64,1.98),.34,TIMBER.lightened(.09))
	_lantern(entry+Vector3(.22,0,1.42))
	# Foreground sumac and leaves caught on the pale ledges.
	for grove in [[-61.8,2.36,6.57,.79],[-63.7,2.05,-3.55,.65],[-44.7,1.77,5.79,.70],[-52.2,4.11,-7.10,.60],
		[-33.8,1.03,-1.55,.62],[-40.3,1.26,5.4,.70],[-56.,2.3,6.25,.74]]:
		var base := Vector3(grove[0],grove[1],grove[2])
		_sumac(base,float(grove[3]))
	for i in 75:
		var z: float = [-1.,1.][i%2]*_rng.randf_range(3.55,4.55)
		var p := Vector3(_rng.randf_range(-60.0,-47.3),1.157,z)
		var along := Vector3(cos(i*1.84),0,sin(i*1.84))*_rng.randf_range(.08,.16)
		var side := along.cross(Vector3.UP)*.42
		_quad(p-along,p+side,p+along,p-side,COPPER.lerp(CHALK,_rng.randf_range(.13,.45)),Vector3.UP)

func _burnished_tree(base: Vector3, size: float) -> void:
	var fork := base+Vector3(.22,1.78,-.12)*size
	_bar(base,fork,.22*size,TIMBER.darkened(.21))
	for b in 6:
		var a := b*2.39996
		var branch := fork+Vector3(cos(a),.57+b*.08,sin(a))*size
		_bar(fork-Vector3.UP*.35,branch,.12*size,TIMBER)
		_rock(branch-Vector3.UP*.16,Vector3(.70,.42,.63)*size,COPPER.lerp(Color("#d28b40"),b*.09))
		_sumac(branch-Vector3.UP*.42,.65*size)

func _sumac(base: Vector3, scale_factor: float) -> void:
	var trunk := base+Vector3.UP*scale_factor*1.10
	_bar(base,trunk,.10*scale_factor,TIMBER.darkened(.24))
	for b in 8:
		var a := b*TAU/8.0+.35
		var radial := Vector3(cos(a),.15+sin(b*1.84)*.18,sin(a))
		var branch := trunk+radial*scale_factor
		_bar(trunk-Vector3.UP*.29,branch,.049*scale_factor,TIMBER)
		for leaf in 21:
			var color := COPPER.lerp(Color("#e7a242"),_rng.randf_range(.06,.65))
			var angle := _rng.randf()*TAU
			var dir := Vector3(cos(angle),-.44,sin(angle))*scale_factor
			var start := trunk.lerp(branch,_rng.randf_range(.38,1.))+dir*_rng.randf_range(.0,.42)
			var width := dir.cross(Vector3.UP)*.085
			_quad(start,start+dir*.18+width,start+dir*.43,start+dir*.18-width,color,Vector3.UP)
			_quad(start,start+dir*.18+width,start+dir*.43,start+dir*.18-width,color.darkened(.16),Vector3.DOWN)

func _build_crane(base: Vector3, rotation_y: float, scale_factor: float, working := false) -> void:
	var transform_crane := Transform3D(Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor), base)
	var front := transform_crane * Vector3(0, 4.5, 3.7)
	var rear := transform_crane * Vector3(0, 4.5, -1.52)
	_slab(base + Vector3.UP * .04, Vector2(1.6, 1.67) * scale_factor, .4, SEDIMENT)
	for side in [-1.0, 1.0]:
		var shoulder := transform_crane * Vector3(side * .31, 4.48, -.16)
		var foot := transform_crane * Vector3(side * .44, 0, -.31)
		_bar(foot, shoulder, .35 * scale_factor, TIMBER)
		_bar(transform_crane * Vector3(side * .41, .12, -1.55), shoulder, .22 * scale_factor, TIMBER)
		_bar(transform_crane * Vector3(side * .36, 2.45, -.16), transform_crane * Vector3(side * .23, 4.45, 2.79), .26 * scale_factor, TIMBER)
		for height in [1.13, 3.02, 4.27]:
			var collar := transform_crane * Vector3(side * .35, height, -.18)
			_rock(collar - Vector3.UP * .09, Vector3(.23, .18, .24) * scale_factor, BRONZE)
	_bar(rear, front, .32 * scale_factor, TIMBER.lightened(.07))
	_bar(rear + Vector3.UP * .24, front + Vector3.UP * .24, .07 * scale_factor, IRON)
	if working:
		_install_ore_cradle(front)
	else:
		_bar(front, front - Vector3.UP * (2.15 * scale_factor), .031 * scale_factor, IRON)
		_rock(front - Vector3.UP * (2.58 * scale_factor), Vector3(.50, .45, .38) * scale_factor, LIMESTONE)
	_rock(rear - Vector3.UP * .71, Vector3(.43, .73, .48) * scale_factor, SEDIMENT)
	_bar(transform_crane * Vector3(-.62, 2.75, -.26), transform_crane * Vector3(.61, 2.75, -.26), .12, BRONZE)
	# Twin wheels, spoke bracing and anti-slip pawl on the ore winch.
	for flank: float in [-1.,1.]:
		var center := transform_crane*Vector3(flank*.60,2.77,-.26)
		var axle := transform_crane.basis.x.normalized()
		var radius := .67*scale_factor
		var across := transform_crane.basis.z.normalized()
		for tooth in 15:
			var angle := TAU*tooth/15.
			var next := TAU*(tooth+1)/15.
			var r := (across*cos(angle)+Vector3.UP*sin(angle))*radius
			var q := (across*cos(next)+Vector3.UP*sin(next))*radius
			_bar(center+r,center+q,.10*scale_factor,BRONZE.lightened(.14))
			if tooth%3==0:
				_bar(center,center+r,.093*scale_factor,TIMBER.lightened(.10))
		_bar(center,center+axle*.16*scale_factor,.14*scale_factor,BRONZE)
	# A hanging caution pennant and brass keeper distinguish the moving end.
	var pole := transform_crane * Vector3(.46, 4.20, 2.34)
	var hem := transform_crane * Vector3(.58, 3.32, 2.23)
	_quad(pole, pole + Vector3.FORWARD * .35, hem + Vector3.FORWARD * .35, hem, COPPER, Vector3.RIGHT)
	_quad(pole, pole + Vector3.FORWARD * .35, hem + Vector3.FORWARD * .35, hem, COPPER.darkened(.13), Vector3.LEFT)
	_box_shape(base + Vector3.UP * .85, Vector3(1.15, 1.7, .83) * scale_factor)

func _loading_tracks() -> void:
	for row in 15:
		var x := -67.0 + row * .43
		_bar(Vector3(x, 1.167, -1.12), Vector3(x, 1.165, 1.05), .05, TIMBER.darkened(.30))
	for side: float in [-.71, .71]:
		for run in 4:
			var x := -67.0 + run * 1.61
			_bar(Vector3(x, 1.184, side), Vector3(x + 1.52, 1.182, side), .047, IRON.lightened(.22))
	_lantern(landmark_position + Vector3(0, 0, -.34))
	_slab(landmark_position + Vector3(0, .33, -.38), Vector2(.38, .40), .34, SEDIMENT)
	_bar(landmark_position + Vector3(0, .31, -.38), landmark_position + Vector3(0, .95, -.02), .105, BRONZE)
	_bar(landmark_position + Vector3(-.18, .94, -.02), landmark_position + Vector3(.18, .94, -.02), .105, COPPER)

func _loading_awning(deck: Vector3) -> void:
	var shore := deck + Vector3(0, 1.95, -.79)
	var end := deck + Vector3(0, 1.57, 1.12)
	for side: float in [-1., 1.]:
		var offset := Vector3.RIGHT * side * 2.0
		_bar(deck + offset + Vector3.FORWARD * .79, shore + offset, .13, TIMBER.darkened(.20))
		_bar(deck + offset + Vector3.BACK * 1.12, end + offset, .15, TIMBER)
		_bar(shore + offset, end + offset, .11, TIMBER)
	_bar(shore + Vector3.LEFT * 2.15, shore + Vector3.RIGHT * 2.15, .09, TIMBER)
	_bar(end + Vector3.LEFT * 2.15, end + Vector3.RIGHT * 2.15, .09, TIMBER)
	var canvas := Color("#b77a50")
	for strip in 12:
		var offset := Vector3.RIGHT * (-2.15 + strip * .36)
		var width := Vector3.RIGHT * .36
		var dip := Vector3.DOWN * (.16 + .07 * sin(strip * 1.7))
		var fold := shore.lerp(end, .46) + offset + dip
		var pale := canvas.lerp(CHALK, .35 if strip % 3 == 0 else .13)
		_quad(shore + offset, shore + offset + width, fold + width, fold, pale, Vector3.UP)
		_quad(fold, fold + width, end + offset + width, end + offset, pale.darkened(.12), Vector3.UP)
		_quad(end + offset, end + offset + width, end + offset + width + dip, end + offset + dip,
			pale.darkened(.26), Vector3.BACK)

func _install_ore_cradle(tip: Vector3) -> void:
	impact_position = Vector3(tip.x, 1.17, tip.z)
	_cradle_pivot = Node3D.new()
	_cradle_pivot.name = "OreHoist"
	_cradle_pivot.position = tip
	add_child(_cradle_pivot)
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = .035
	rope_mesh.bottom_radius = .035
	rope_mesh.radial_segments = 6
	rope_mesh.rings = 1
	rope_mesh.height = 1.0
	_rope = _crane_part(_cradle_pivot, rope_mesh, Vector3.ZERO, IRON)
	_rope.material_override = preload("res://art/materials/stylized/painted_rope.tres")
	_cradle = Node3D.new()
	_cradle.name = "OreCradle"
	_cradle_pivot.add_child(_cradle)
	_crane_box(_cradle, Vector3(1.28, .16, 1.04), Vector3(0, -.44, 0), TIMBER)
	for side: float in [-1., 1.]:
		_crane_box(_cradle, Vector3(.10, .43, 1.08), Vector3(side * .65, -.22, 0), BRONZE)
		_crane_box(_cradle, Vector3(1.33, .10, .12), Vector3(0, -.23, side * .50), IRON)
		for edge: float in [-1., 1.]:
			var eye := Vector3(side * .63, .05, edge * .48)
			_crane_box(_cradle, Vector3(.12, .59, .13), eye + Vector3.DOWN * .15, BRONZE)
			var sling := _crane_box(_cradle, Vector3(.048, eye.length(), .048), eye * .5, BRONZE)
			sling.quaternion = Quaternion(Vector3.UP, eye.normalized())
	for i in 4:
		var stone := PrismMesh.new()
		stone.size = Vector3(.62, .36, .48)
		var chunk := _crane_part(_cradle, stone, Vector3((i % 2 - .5) * .61, -.15, (floori(i / 2.) - .5) * .50),
			LIMESTONE.lerp(CHALK, float(i) * .21))
		chunk.rotation.y = i * .73
	var mark := TorusMesh.new()
	mark.inner_radius = 1.18
	mark.outer_radius = 1.27
	mark.rings = 24
	mark.ring_segments = 6
	_target = _crane_part(self, mark, impact_position + Vector3.UP * .055, Color("#e37631"), true)
	_target.hide()
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = .16
	dust_mesh.height = .26
	dust_mesh.radial_segments = 5
	dust_mesh.rings = 2
	var dust_material := StandardMaterial3D.new()
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.vertex_color_use_as_albedo = true
	dust_mesh.material = dust_material
	var color := Gradient.new()
	color.colors = PackedColorArray([Color(1.0, .74, .46, .55), Color(.78, .58, .42, 0.0)])
	_dust = CPUParticles3D.new()
	_dust.position = impact_position + Vector3.UP * .15
	_dust.mesh = dust_mesh
	_dust.amount = 30
	_dust.lifetime = .85
	_dust.one_shot = true
	_dust.emitting = false
	_dust.explosiveness = .97
	_dust.direction = Vector3.UP
	_dust.spread = 68.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.6
	_dust.gravity = Vector3(0, .45, .28)
	_dust.color_ramp = color
	add_child(_dust)
	_set_cradle_depth(_hoist_depth)

func _process(delta: float) -> void:
	if _cradle_pivot == null or _drop_running:
		return
	_sway_time += delta
	_cradle_pivot.rotation.x = sin(_sway_time * 1.7) * .075
	_cradle_pivot.rotation.z = sin(_sway_time * 1.29 + .5) * .045
	_cradle.rotation.y = sin(_sway_time * .91) * .13

func release_crane() -> void:
	if _drop_running:
		return
	_drop_running = true
	_target.show()
	_cradle_pivot.rotation = Vector3.ZERO
	_drop = create_tween()
	var lowest := _cradle_pivot.position.y - impact_position.y - .56
	_drop.tween_method(_set_cradle_depth, _hoist_depth, lowest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop.tween_callback(_strike_crane)
	_drop.tween_interval(.22)
	_drop.tween_method(_set_cradle_depth, lowest, 1.55, 1.23).set_trans(Tween.TRANS_SINE)
	_drop.tween_callback(func() -> void: _drop_running = false)

func _strike_crane() -> void:
	_target.hide()
	_dust.restart()
	_dust.emitting = true

func _set_cradle_depth(depth: float) -> void:
	_hoist_depth = depth
	_cradle.position.y = -depth
	_rope.position.y = -.5 * depth
	_rope.scale.y = depth

func _crane_box(parent: Node3D, size: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _crane_part(parent, shape, at, tint)

func _crane_part(parent: Node3D, shape: Mesh, at: Vector3, tint: Color, luminous := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = tint
	surface.roughness = .86
	surface.emission_enabled = luminous
	surface.emission = tint
	surface.emission_energy_multiplier = .8
	part.mesh = shape
	part.material_override = surface
	part.position = at
	parent.add_child(part)
	return part

func _lantern(base: Vector3) -> void:
	var top := base + Vector3.UP * 1.46
	_bar(base, top, .11, TIMBER)
	_bar(top, top + Vector3.RIGHT * .38, .10, BRONZE)
	var lantern_position := top + Vector3(.32, -.28, 0.0)
	_bar(top + Vector3.RIGHT * .32, lantern_position, .043, IRON)
	var glow := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = .105
	body.bottom_radius = .122
	body.height = .19
	body.radial_segments = 6
	glow.mesh = body
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#c47827")
	material.emission_enabled = true
	material.emission = Color("#ffae4e")
	material.emission_energy_multiplier = 1.45
	glow.material_override = material
	glow.position = lantern_position
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var lamp := OmniLight3D.new()
	lamp.position = lantern_position
	lamp.omni_range = 3.0
	lamp.light_energy = .66
	lamp.light_color = Color("#ffb368")
	add_child(lamp)

func _rocks_and_grass(center: Vector3, count: int) -> void:
	for i in range(count):
		var p := center + Vector3(_rng.randf_range(-.85, .85), 0, _rng.randf_range(-.48, .47))
		var scale_factor := _rng.randf_range(.09, .29)
		_rock(p - Vector3.UP * .077, Vector3(1.46, .7, 1.07) * scale_factor, _stone().darkened(.1))
		var grass := p + Vector3(.12, .017, -.07)
		for blade in range(4):
			var angle := _rng.randf() * TAU
			var forward := Vector3(cos(angle), 0, sin(angle))
			var side := forward.cross(Vector3.UP) * .025
			var point := grass + Vector3.UP * _rng.randf_range(.20, .44) + forward * .14
			var hue := Color("#926041").lerp(Color("#e9b75c"), _rng.randf())
			_tri(grass - side, grass + side, point, hue, forward)
			_tri(grass - side, grass + side, point, hue, -forward)

func _span_floor(a: Vector3, b: Vector3, width: float) -> void:
	var along := b - a
	var across := along.cross(Vector3.UP).normalized()
	var up := across.cross(along).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, .62, along.length() + .15)
	var body := CollisionShape3D.new()
	body.shape = shape
	body.transform = Transform3D(Basis(-across, up, along.normalized()), (a + b) * .5 - up * .31)
	_solid.add_child(body)
	var left := across * width * .5
	_quad(a - left - up * .037, a + left - up * .037, b + left - up * .037,
		b - left - up * .037, SEDIMENT, Vector3.UP)
	for side in [-1.0, 1.0]:
		var p: Vector3 = a + left * side
		var q: Vector3 = b + left * side
		_quad(p - up * .62, q - up * .62, q, p, SEDIMENT, across * side)

func _tile(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var center := (a + b + c + d) * .25
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	for corner in [a, b, c, d]:
		var jitter := Vector3(_rng.randf_range(-.045, .045), 0, _rng.randf_range(-.048, .048))
		top.append(corner.lerp(center, .042) + jitter)
		bottom.append(corner.lerp(center, .013) + jitter - Vector3.UP * .065)
	_quad(top[0], top[1], top[2], top[3], color, Vector3.UP)
	for i in range(4):
		var j := (i + 1) % 4
		_quad(top[i], top[j], bottom[j], bottom[i], color.darkened(.16), (top[i] + top[j]) * .5 - center)

func _slab(top_center: Vector3, size: Vector2, depth: float, color: Color, walkable := false) -> void:
	if walkable:
		_box_shape(top_center + Vector3.DOWN * depth * .5, Vector3(size.x, depth, size.y))
	var x := Vector3.RIGHT * size.x * .5
	var z := Vector3.BACK * size.y * .5
	var a := top_center - x - z
	var b := top_center + x - z
	var c := top_center + x + z
	var d := top_center - x + z
	var below := Vector3.DOWN * depth
	_quad(a, b, c, d, color, Vector3.UP)
	_quad(a, a + below, b + below, b, color.darkened(.18), Vector3.FORWARD)
	_quad(b, b + below, c + below, c, color.darkened(.24), Vector3.RIGHT)
	_quad(c, c + below, d + below, d, color.darkened(.18), Vector3.BACK)
	_quad(d, d + below, a + below, a, color.darkened(.25), Vector3.LEFT)

func _rock(origin: Vector3, size: Vector3, color: Color) -> void:
	var lower := PackedVector3Array()
	var shoulder := PackedVector3Array()
	var cap := PackedVector3Array()
	var turn := _rng.randf_range(-.2, .2)
	var slope := Vector3(_rng.randf_range(-.15, .15) * size.x, 0, _rng.randf_range(-.18, .18) * size.z)
	for i in range(7):
		var angle := TAU * i / 7.0 + turn
		var shift := Vector3(cos(angle) * size.x, 0, sin(angle) * size.z)
		lower.append(origin + shift * _rng.randf_range(.79, 1.12))
		shoulder.append(origin + shift * _rng.randf_range(.86, 1.04) + Vector3.UP * size.y * _rng.randf_range(.58, .82))
		cap.append(origin + shift * _rng.randf_range(.48, .69) + slope + Vector3.UP * size.y * _rng.randf_range(.88, 1.04))
	for i in range(7):
		var j := (i + 1) % 7
		var out := (lower[i] + lower[j]) * .5 - origin
		var shade := color.lerp(SEDIMENT, _rng.randf_range(.08, .32))
		if size.y > 1.45 and size.x > .9 and i % 3 != 0:
			SURFACE_DETAIL.quarry_cut_face(lower[i], lower[j], shoulder[j], shoulder[i], out, shade, _quad)
		else:
			_quad(lower[i], lower[j], shoulder[j], shoulder[i], shade, out)
		_quad(shoulder[i], shoulder[j], cap[j], cap[i], shade.lightened(.065), (out + Vector3.UP).normalized())
		_tri(cap[i], cap[j], origin + slope + Vector3.UP * size.y, color.lightened(.16), Vector3.UP)

func _bar(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var forward := (b - a).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < .5:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var x := right * width * .5
	var y := up * width * .5
	var corners := [x + y, x - y, -x - y, -x + y]
	for i in range(4):
		var j := (i + 1) % 4
		_quad(a + corners[i], b + corners[i], b + corners[j], a + corners[j],
			color.lightened(.056 * i), corners[i] + corners[j])
	_quad(a + corners[0], a + corners[1], a + corners[2], a + corners[3], color, -forward)
	_quad(b + corners[0], b + corners[1], b + corners[2], b + corners[3], color, forward)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	_tri(a, b, c, color, outward)
	_tri(a, c, d, color, outward)

func _tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.00000001:
		return
	var vertices := [a, b, c] if normal.dot(outward) >= 0.0 else [a, c, b]
	for vertex in vertices:
		_surf.set_color(color)
		_surf.add_vertex(vertex)

func _box_shape(center: Vector3, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = center
	_solid.add_child(collider)

func _stone() -> Color:
	return LIMESTONE.lerp(CHALK, _rng.randf_range(.02, .73)).darkened(_rng.randf_range(0, .13))

func _asset(scene: PackedScene, at: Vector3, scale_factor: Vector3, yaw: float) -> void:
	var model := scene.instantiate() as Node3D
	model.position = at
	model.scale = scale_factor
	model.rotation.y = yaw
	add_child(model)

func _finish_geometry() -> void:
	_surf.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = _surf.commit()
	var material := ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter("route_paint", preload("res://art/textures/stylized/route_paint.png"))
	material.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	material.set_shader_parameter("mineral_tint", Vector3(1.17, 1.02, .78))
	mesh.material_override = material
	add_child(mesh)
