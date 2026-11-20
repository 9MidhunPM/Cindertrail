class_name CinderGrove
extends Node3D
## Hand-laid Flooded Grove. Geometry is baked once into static vertex-coloured batches.
## All points on the causeways and in the flooded lanes belong to the same physics space.

const ARCH = preload("res://art/models/ruin_arch.glb")
const PILLAR = preload("res://art/models/ruin_pillar.glb")
const WATER = preload("res://art/materials/grove/shallows.gdshader")
const PALETTE = preload("res://art/materials/grove/weathered_palette.gdshader")
const FALL = preload("res://art/materials/grove/waterfall.gdshader")
const WILDLIFE = preload("res://scripts/world/grove_wildlife.gd")
const ROUTE_PAINT = preload("res://art/textures/stylized/route_paint.png")
const BELL_POSITION := Vector3(-3.65, 0.72, 2.60)
const CREAM = Color("#d6b584")
const LIGHT = Color("#f4d8a5")
const SHADE = Color("#827d73")
const MOSS = Color("#687e51")
const REED = Color("#597f58")
const BARK = Color("#534840")

var rng := RandomNumberGenerator.new()
var ground := StaticBody3D.new()
var templates := {}
var points := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var _wildlife: Node3D
var _bell := Node3D.new()
var _bell_wave: MeshInstance3D
var _bell_tween: Tween

func _ready() -> void:
	rng.seed = 871202
	ground.name = "WalkableGrove"
	add_child(ground)
	_box_floor(Vector3(0,-0.25,0),Vector3(49,.5,49))
	_pool()
	_island()
	_walk([Vector2(-1,25),Vector2(-3.4,16),Vector2(-2.6,10),Vector2(.2,4.5)], 3.45)
	_walk([Vector2(-24.5,1),Vector2(-15,1),Vector2(-9,2),Vector2(-4.4,1)], 2.9)
	_walk([Vector2(0,-25),Vector2(0,-19),Vector2(2,-12.5),Vector2(.5,-4.4)], 3.1)
	# Wading lines climb out of the pool via broad submerged limestone ramps.
	_wade(Vector2(-12,-5),Vector2(-4,-.2))
	_wade(Vector2(12,-4),Vector2(4,.6))
	_architecture()
	_shore()
	_plantings()
	_water_garden()
	_ruin_gardens()
	_exposed_roots()
	_bell_shrine()
	_finish_mesh()
	_wildlife = WILDLIFE.new()
	add_child(_wildlife)

func release_herons() -> void:
	_wildlife.lift_flock()

func ring_bell() -> void:
	if _bell_tween:
		_bell_tween.kill()
	_bell.rotation.x = -0.54
	_bell_wave.scale = Vector3.ONE
	_bell_wave.show()
	var glow := _bell_wave.material_override as StandardMaterial3D
	glow.albedo_color.a = 0.72
	_bell_tween = create_tween().set_parallel()
	_bell_tween.tween_property(_bell, "rotation:x", 0.0, 1.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_bell_tween.tween_property(_bell_wave, "scale", Vector3(9., 1., 9.), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bell_tween.tween_property(glow, "albedo_color:a", 0.0, 0.85)
	_bell_tween.tween_callback(_bell_wave.hide).set_delay(.85)

func _exposed_roots() -> void:
	for at: Vector3 in WILDLIFE.PERCHES:
		_rock(at - Vector3.UP * .38, Vector3(.43, .38, .53), SHADE.lerp(MOSS, .32), 8)
	# Alder roots follow the waterline around the old paving.
	for pair in [
		[Vector3(-8.4, .45, 15.7), Vector3(-4.77, .27, 13.43)],
		[Vector3(-8.1, .68, 13.7), Vector3(-4.63, .25, 11.05)],
		[Vector3(-8.1, .57, 13.7), Vector3(-6.15, .29, 16.47)],
		[Vector3(-12.7, .80, 9.4), Vector3(-9.11, .25, 10.55)],
		[Vector3(-10.4, .66, -15.), Vector3(-5.18, .27, -11.0)],
		[Vector3(14.1, .49, 13.7), Vector3(7.8, .23, 12.05)],
		[Vector3(14.1, .50, 13.7), Vector3(10.8, .25, 16.28)],
		[Vector3(17., .70, -5.), Vector3(13.8, .25, -1.85)],
	]:
		var source: Vector3 = pair[0]
		var tip: Vector3 = pair[1]
		var side := (tip - source).cross(Vector3.UP).normalized()
		var knot := source.lerp(tip, .37) + side * .41 + Vector3.UP * .26
		var elbow := source.lerp(tip, .71) - side * .25 + Vector3.UP * .12
		var wood := BARK.lerp(Color("#815639"), .32)
		_limb(source, knot, .33, .20, wood, 7)
		_limb(knot, elbow, .21, .12, wood, 7)
		_limb(elbow, tip, .125, .045, wood, 6)
		for fork in [-1.0, 1.0]:
			var branch := elbow + side * float(fork) * .59 + (tip - elbow) * .35
			var end := tip + side * float(fork) * .82
			_limb(knot, branch, .106, .067, wood.lightened(.071), 6)
			_limb(branch, end, .069, .032, wood, 6)
		_fern(knot + Vector3.UP * .19, .77)
		_grass(Vector2(tip.x, tip.z), tip.y, 13)
		for i in 4:
			var at := source.lerp(knot, .2 + .19 * i)
			at += side * sin(i * 1.5) * .19 + Vector3.UP * .23
			_rock(at, Vector3(.25, .085, .24), MOSS.darkened(.07), 6)

func _bell_shrine() -> void:
	var base := Vector2(BELL_POSITION.x, BELL_POSITION.z)
	_disc(base, .56, .69, .81, SHADE, 9)
	_disc(base, .49, .79, .89, CREAM, 9)
	var crown := BELL_POSITION + Vector3.UP * 1.65
	for hand in [-1.0, 1.0]:
		var toe := BELL_POSITION + Vector3.RIGHT * float(hand) * .47
		var joint := crown + Vector3.RIGHT * float(hand) * .34
		_limb(toe, joint, .076, .06, BARK, 5)
		_limb(toe + Vector3.BACK * .29, joint, .066, .055, BARK, 5)
		_limb(joint, crown + Vector3.RIGHT * float(hand) * .08, .069, .064, Color("#ad8050"), 6)
		for wrap in 3:
			var inset := Vector3.DOWN * float(wrap) * .039
			_limb(joint + inset, joint + inset + Vector3.DOWN * .028, .086, .086, Color("#cf9862"), 8)
	_bell.name = "FloodedFordBell"
	_bell.position = crown + Vector3.DOWN * .16
	add_child(_bell)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#c48647")
	metal.metallic = .44
	metal.roughness = .47
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color("#7e8a61")
	copper.metallic = .43
	copper.roughness = .61
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("#f4bb69")
	edge.metallic = .53
	edge.roughness = .35
	edge.emission_enabled = true
	edge.emission = Color("#a85626")
	edge.emission_energy_multiplier = .14
	for segment in [
		[.10, .16, .16, -.10, metal],
		[.16, .20, .18, -.27, copper],
		[.20, .30, .20, -.46, metal],
		[.295, .32, .053, -.58, edge],
		[.043, .049, .20, -.57, copper],
	]:
		var shape := CylinderMesh.new()
		shape.top_radius = segment[0]
		shape.bottom_radius = segment[1]
		shape.height = segment[2]
		shape.radial_segments = 14
		var piece := MeshInstance3D.new()
		piece.mesh = shape
		piece.position.y = segment[3]
		piece.material_override = segment[4]
		_bell.add_child(piece)
	_bell_wave = MeshInstance3D.new()
	var wave := TorusMesh.new()
	wave.inner_radius = .44
	wave.outer_radius = .48
	wave.rings = 32
	wave.ring_segments = 5
	var shimmer := StandardMaterial3D.new()
	shimmer.albedo_color = Color(.62, .96, .82, .72)
	shimmer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shimmer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bell_wave.mesh = wave
	_bell_wave.position = BELL_POSITION + Vector3.UP * .06
	_bell_wave.material_override = shimmer
	_bell_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bell_wave)
	_bell_wave.hide()

func _box_floor(p: Vector3, size: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.transform = Transform3D(Basis(Vector3.UP,yaw) * Basis(Vector3.RIGHT,pitch),p)
	ground.add_child(collision)

func _pool() -> void:
	# The transparent surface reveals the flooded flagstone courses below it.
	_slab(PackedVector2Array([Vector2(-24.5,-24.5),Vector2(24.5,-24.5),Vector2(24.5,24.5),Vector2(-24.5,24.5)]),-.21,-.19,Color("#246e66"))
	for patch in [Vector2(.5,13),Vector2(5.8,7.3),Vector2(-7.4,4.0),Vector2(8.6,-4.0),Vector2(-11.5,-5.2),Vector2(-4,-11.7),Vector2(4.3,17.4)]:
		for row in 5:
			for col in 4:
				if rng.randf()<.18: continue
				var loc: Vector2 = patch + Vector2(col*.68+(row%2)*.29,row*.64)
				_rock(Vector3(loc.x,-.10,loc.y),Vector3(.48,.16,.39)*rng.randf_range(.79,1.05),Color("#689280").darkened(rng.randf_range(.0,.29)),6)
	# Stream-bed cobbles sit below the refracting surface, with quiet patches of open water.
	for bank in [Vector2(2.1,13.6),Vector2(4.4,9.4),Vector2(-6.1,13.1),Vector2(-5.1,7.1),Vector2(7.6,3.6),Vector2(2.8,-6.9)]:
		for i in 50:
			var p: Vector2=bank+Vector2(rng.randfn(0.,1.65),rng.randfn(0.,1.44))
			var r:=rng.randf_range(.12,.49)
			var shade:=Color("#537f76").lerp(Color("#94a67d"),rng.randf())
			_rock(Vector3(p.x,-.035,p.y),Vector3(r,.105,r*.82),shade,6)
	var plane := PlaneMesh.new()
	plane.size = Vector2(49,49)
	var water := MeshInstance3D.new()
	water.name = "TurquoiseShallows"
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = WATER
	water.material_override = mat
	water.position.y = .245
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _island() -> void:
	var edge := PackedVector2Array()
	for i in 28:
		var a := i*TAU/28
		edge.append(Vector2(cos(a),sin(a))*rng.randf_range(5.38,5.65))
	_slab(edge,-.18,.61,SHADE)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 5.46
	cylinder.height = .72
	var collision := CollisionShape3D.new()
	collision.shape = cylinder
	collision.position.y = .34
	ground.add_child(collision)
	# Broad segments laid around the old ritual disk, with narrow joints and lichen.
	for row in 4:
		var inner := [.94,2.0,3.10,4.20][row] as float
		var outer := [2.0,3.1,4.20,5.5][row] as float
		var count := 9+row*4
		for i in count:
			var a := (i+.42*(row%2))*TAU/count
			var b := a+TAU/count
			var poly := PackedVector2Array()
			for sample in [[inner+.015,a+.006],[outer-.012,a+.006],[outer-.012,(a+b)*.5],[outer-.012,b-.006],[inner+.015,b-.006],[inner+.015,(a+b)*.5]]:
				poly.append(Vector2(cos(sample[1]),sin(sample[1]))*float(sample[0]))
			_slab(poly,.58,.695+rng.randf_range(-.015,.012),_stone())
	_disc(Vector2.ZERO,.93,.60,.71,LIGHT,18)
	for i in 12:
		var a := TAU*i/12
		var rad := Vector2(cos(a),sin(a))
		var tangent := Vector2(-rad.y,rad.x)
		_slab(PackedVector2Array([rad*.62-tangent*.052,rad*.89,rad*.62+tangent*.052]),.712,.717,Color("#8c7555"))
	for i in 54:
		var a := TAU*rng.randf()
		var p := Vector2(cos(a),sin(a))*rng.randf_range(4.88,5.39)
		_litter(p,.716)
	for i in 42:
		var a := rng.randf()*TAU
		var pos := Vector2(cos(a),sin(a))*rng.randf_range(5.37,5.85)
		if abs(pos.x)<2.4 or abs(pos.y)<1.8: continue
		_rock(Vector3(pos.x,.12,pos.y),Vector3(.42,.33,.53)*rng.randf_range(.6,1.6),SHADE)
		if i%2==0: _grass(pos,.3,7)

func _walk(path: Array, width: float) -> void:
	for segment in range(path.size()-1):
		var a: Vector2 = path[segment]
		var b: Vector2 = path[segment+1]
		var forward := (b-a).normalized()
		var side := Vector2(-forward.y,forward.x)
		var length := a.distance_to(b)
		var n := ceili(length/.89)
		var base_poly := PackedVector2Array([a-side*width*.51,b-side*width*.51,b+side*width*.51,a+side*width*.51])
		_slab(base_poly,-.08,.52,SHADE.darkened(.29))
		_box_floor(Vector3((a.x+b.x)*.5,.32,(a.y+b.y)*.5),Vector3(width,.72,length+.33),atan2(forward.x,forward.y))
		var previous_seam := 0.0
		for row in n:
			var start := a+forward*(length*row/n)
			var end := a+forward*(length*(row+1)/n)
			var seam := rng.randf_range(-.24,.24)*width
			for lane in 3:
				var w := width/3.0
				var seams0 := [-width*.5,-w*.5+previous_seam*.42,w*.5+previous_seam*.25,width*.5]
				var seams1 := [-width*.5,-w*.5+seam*.42,w*.5+seam*.25,width*.5]
				var x0 := float(seams0[lane])+.026
				var x1 := float(seams0[lane+1])-.026
				var x2 := float(seams1[lane+1])-.026
				var x3 := float(seams1[lane])+.026
				if lane==0: x0 += rng.randf_range(-.13,.07)
				if lane==2: x2 += rng.randf_range(-.07,.13)
				# Clip corners, with a drifting outer edge and moss showing at the joints.
				var p0 := start+side*x0+forward*rng.randf_range(.012,.046)
				var p1 := start+side*x1+forward*rng.randf_range(.014,.046)
				var p2 := end+side*x2-forward*rng.randf_range(.012,.050)
				var p3 := end+side*x3-forward*rng.randf_range(.010,.050)
				var chip := rng.randf_range(.04,.27)
				var poly := PackedVector2Array([p0.lerp(p1,chip*.66),p1.lerp(p0,.05),p1.lerp(p2,.1),p2.lerp(p1,.06),p2.lerp(p3,.06),p3.lerp(p2,chip*.52),p3.lerp(p0,chip),p0.lerp(p3,chip*.78)])
				var high := rng.randf_range(.642,.70)
				_slab(poly,.38+rng.randf_range(-.13,.03),high,_stone())
				if rng.randf()<.27:
					_crack((start+end)*.5+side*(x0+x1)*.5,high+.002,forward,side)
				if lane!=1 and rng.randf()<.38:
					_litter(start+side*(x0 if lane==0 else x1),high+.015)

			previous_seam = seam
			if row%3!=1:
				var sign_side := -1. if row%3==0 else 1.
				var edge := start+side*sign_side*(width*.52+rng.randf_range(.12,.34))
				var toe := rng.randf_range(.14,.45)
				_rock(Vector3(edge.x,toe,edge.y),Vector3(.46,.19,.61)*rng.randf_range(.72,1.34),_stone(),7)
				if row%3==0:
					_grass(edge,toe+.10,7)
			if row%2==0:
				var p := start+side*(width*.5+.23)*(-1 if row%4==0 else 1)
				_rock(Vector3(p.x,.20,p.y),Vector3(.41,.32,.61),SHADE)
				_grass(p,.33,rng.randi_range(4,11))

func _wade(start: Vector2, end: Vector2) -> void:
	var f := (end-start).normalized()
	var side := Vector2(-f.y,f.x)
	var length := start.distance_to(end)
	var crest := start.lerp(end,.75)
	var ramp_length := start.distance_to(crest)
	var yaw := atan2(f.x,f.y)
	_box_floor(Vector3((start.x+crest.x)*.5,.22,(start.y+crest.y)*.5),Vector3(3.3,.24,ramp_length+.12),yaw,-atan2(.68,ramp_length))
	_box_floor(Vector3((end.x+crest.x)*.5,.56,(end.y+crest.y)*.5),Vector3(3.3,.24,length-ramp_length+.12),yaw)
	for i in 10:
		var p := start.lerp(end,i/10.0)+side*rng.randf_range(-.36,.36)
		var y := .025+.65*minf(1.0,i/7.5)
		_rock(Vector3(p.x,y-.06,p.y),Vector3(rng.randf_range(.8,1.2),.08,.58),_stone())
		if i%3==0: _grass(p+side*1.38,.20,9)

func _architecture() -> void:
	# Ruined processional arcade, flooded except for surviving capitals and arches.
	for p in [[-8.5,-6.8,1.9,-.22],[-13.70,-10.15,.90,-.42],[7.4,-10.2,2.18,.31],[16.6,-13.3,1.13,.22],[-5.6,-18.0,1.18,-.10],[8.45,3.35,1.91,-.64]]:
		var ruined: bool = p[0] < -12 or p[0] > 15
		_asset(ARCH,Vector3(p[0],.02,p[1]),Vector3.ONE*p[2],p[3],ruined)
		var arch_scale := float(p[2])
		var axis := Vector3(cos(float(p[3])),0,-sin(float(p[3])))
		for end in [-1.0,1.0]:
			var pier: Vector3 = Vector3(p[0],arch_scale*.70,p[1])+axis*arch_scale*end*1.18
			_box_floor(pier,Vector3(.38,1.40,.5)*arch_scale,float(p[3]))
		if not ruined:
			_box_floor(Vector3(p[0],arch_scale*2.48,p[1]),Vector3(1.65,.30,.49)*arch_scale,float(p[3]))
		var base := Vector2(p[0],p[1])
		_grass(base+Vector2(1.8,0),.22,13)
		_vine(base, float(p[2])*2.55, float(p[2]))
	for p in [[-4.55,-8.6,1.22],[-15.4,-5.9,.86],[5.0,-12.2,1.42],[14.3,-6.4,.67],[9.6,3.7,.55],[-8.4,4.7,.67],[4.7,-17.0,.8],[-5.2,-13.5,.86]]:
		_asset(PILLAR,Vector3(p[0],-.05,p[1]),Vector3(p[2],p[2],p[2]),.19)
		_box_floor(Vector3(p[0],float(p[2])*1.20,p[1]),Vector3(.49,2.5,.49)*float(p[2]),.19)
		_rock(Vector3(p[0],.12,p[1]),Vector3(.73,.30,.72),SHADE)
	for i in 13:
		var p := Vector2(rng.randf_range(7,17),rng.randf_range(-10.2,-7.9))
		_rock(Vector3(p.x,.21,p.y),Vector3(.65,.33,.48)*rng.randf_range(.52,1.24),_stone())

func _vine(base: Vector2, height: float, scale_factor: float) -> void:
	for branch in 3:
		var x := base.x + (rng.randf_range(-.65,.65) if branch==0 else rng.randf_range(.77,1.07))*scale_factor
		for i in rng.randi_range(5,13):
			var p := Vector3(x+sin(i*.6)*.09,height-i*.105,base.y+.26*scale_factor)
			_rock(p,Vector3(.11,.088,.084),[MOSS,Color("#356657"),Color("#74935c")][i%3])

func _shore() -> void:
	# Broken banks frame the pool, deliberately leaving both wading routes open.
	# Distant banks rise above the waterline along the visible lake perimeter.
	for bank in [[-23.,-22.,9.,3.6],[-14.,-24.,7.,2.7],[-6.9,-25.,4.1,1.15],[7.9,-25.,4.8,1.5],[16.8,-24.,7.2,2.9],[24.,-20.,7.1,3.8],[24.5,-10.,5.,2.2],[24.,1.,4.3,1.7],[-24.2,-10.,5.8,2.3],[-25.,10.,4.8,1.6],[22.8,19.8,5.2,2.1],[-23.,20.,6.,2.3]]:
		var pos := Vector3(bank[0],-.25,bank[1])
		_rock(pos,Vector3(bank[2],bank[3],float(bank[2])*.87),Color("#526b63"),10)
		_rock(pos+Vector3.UP*float(bank[3])*.60,Vector3(float(bank[2])*.76,float(bank[3])*.58,float(bank[2])*.54),Color("#526852"),8)
		for i in 3:
			var a := rng.randf()*TAU
			var at := pos+Vector3(cos(a),0,sin(a))*rng.randf_range(1.,float(bank[2])*.80)
			var sc := rng.randf_range(.70,1.25)
			_alder(at+Vector3.UP*float(bank[3])*.48,sc*4.4,false,a,true)
	# A dry remnant of the road supports the optional supply cache beside the trail.
	_disc(Vector2(-6.1,9.),1.09,.02,.68,SHADE,8)
	_disc(Vector2(-6.1,9.),.94,.60,.71,_stone(),7)
	_box_floor(Vector3(-6.1,.30,9.),Vector3(1.50,.78,1.58))
	for i in 3:
		var x := -5.32+i*.44
		_rock(Vector3(x,.37,9.),Vector3(.42,.29,.44),CREAM)
		_box_floor(Vector3(x,.30,9.),Vector3(.72,.62,.69))
	for cluster in [[-17.5,10.2,5.1,2.6],[-18.6,-12.0,5.4,2.9],[20.,8.2,6.,3.4],[16.5,-18.0,5.,2.2],[8.,-22.,4.,2.3],[-9.,-21.,4.8,2.1]]:
		var x := float(cluster[0])
		var z := float(cluster[1])
		var extent := float(cluster[2])
		var h := float(cluster[3])
		_rock(Vector3(x,-.55,z),Vector3(extent,h,extent*.70),Color("#68716c"))
		for i in 12:
			var a := rng.randf()*TAU
			var stretch := rng.randf_range(.55,.99)
			var p := Vector3(x+cos(a)*extent*stretch,.0,z+sin(a)*extent*.65*stretch)
			var size := rng.randf_range(.4,1.25)
			_rock(p,Vector3(size*1.4,size*.81,size),[SHADE,Color("#596d6b"),Color("#8c9480")][i%3])
			_grass(Vector2(p.x,p.z),.22,9)
	for i in 8:
		var p := Vector3(-13.5+(i%4)*.60,-.10,3.3+float(i/4)*.65)
		_rock(p,Vector3(1.15,2.15+(i%3)*.28,1.18),Color("#727f75"))
		_grass(Vector2(p.x,p.z),1.78,11)
	for p in [Vector2(-12.7,4.75),Vector2(-11.85,4.64),Vector2(-15.6,-9.5)]:
		_cascade(p)

func _cascade(p: Vector2, crest := 1.51, pool_height := .25, width := 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := ShaderMaterial.new()
	mat.shader = FALL
	st.set_material(mat)
	var course := [Vector2(-.65,1.),Vector2(-.22,1.),Vector2(0,.98),Vector2(.22,.86),Vector2(.39,.62),Vector2(.54,.07),Vector2(.66,0.)]
	for i in 9:
		for j in range(course.size()-1):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var u: float = (i+corner.x)/9.
				var stop: Vector2 = course[j+corner.y]
				var ripple:=sin(u*4.77)*.056
				var y:=lerpf(pool_height,crest+ripple,stop.y)
				var z:=p.y+stop.x+sin(u*6.3)*.08
				st.set_uv(Vector2(u,1.-stop.y))
				st.set_normal(Vector3(0,.23,1.).normalized())
				st.add_vertex(Vector3(p.x+u*1.41*width,y,z))
		var pt := Vector3(p.x+i*.16*width,pool_height+.013,p.y+.66+rng.randf_range(-.08,.09))
		_rock(pt,Vector3(.21,.018,.09),Color("#b0ded1"))
	for i in 3:
		var center:=Vector3(p.x+.72*width,pool_height+.018,p.y+.48)
		var r:=.48+i*.27
		for j in 8:
			var a:=(j+.23*i)*PI/8.
			var b:=a+PI/9.25
			var dir:=Vector3(cos(a),0,sin(a)*.57)
			var end:=Vector3(cos(b),0,sin(b)*.57)
			_face(center+dir*r,center+end*r,center+end*(r+.032),Color("#94cbbb"),Vector3.UP)
	var mesh := MeshInstance3D.new()
	mesh.name = "Cascade"
	mesh.mesh = st.commit()
	add_child(mesh)

func _plantings() -> void:
	# High crowns flank the walk while the tactical camera can see under the near limbs.
	var groups := [[-8.4,15.7,6.8,.12],[-12.7,9.4,8.8,-.36],[-18,12.7,8.2,.4],[14.1,13.7,5.6,2.85],[19.,8.2,8.1,1.3],[-18,-11.5,9.6,.32],[-14.4,-15.9,8.4,.22],[-10.4,-15.,10.7,.4],[-6.2,-17.7,8.3,-.4],[-3.6,-22.,6.8,-.8],[5.6,-19.8,8.3,.3],[10.5,-18.9,9.1,1.7],[17.,-18.3,8.6,1.3],[20.,-13.5,8.1,-.9],[17.,-5.,6.7,-.1],[-16,18.8,7.5,-.8],[14.3,20.,7.1,.6]]
	for i in groups.size():
		var tree: Array = groups[i]
		var at := Vector3(tree[0],.0,tree[1])
		var h := float(tree[2])
		_box_floor(at+Vector3.UP*h*.19,Vector3(.085,.4,.085)*h)
		_rock(at,Vector3(h*.19,.80,h*.16),Color("#5d715d"))
		_alder(at,h,i in [0,4,13],float(tree[3]))
	# Rushes and floating leaves decorate coves away from socket silhouettes.
	for c in [Vector2(-5.5,8.2),Vector2(2.4,10.5),Vector2(8.8,6.4),Vector2(-10,7),Vector2(7.2,-6.5),Vector2(-9,-11),Vector2(12.8,-4),Vector2(-8.6,-2.1),Vector2(5.9,3.9),Vector2(4.,16),Vector2(-7,16)]:
		for i in 8:
			var p: Vector2 = c + Vector2(rng.randf_range(-1.25,1.25),rng.randf_range(-1.,1.))
			_grass(p,.18,rng.randi_range(6,14))
			var l := p+Vector2(rng.randf_range(.4,1.3),.6)
			_disc(l,rng.randf_range(.11,.27),.247,.257,Color("#4b8765"),7)
	for at in [Vector2(-5.3,15.9),Vector2(-5.1,13.7),Vector2(-.4,12.8),Vector2(-6.1,10.1),Vector2(-7.4,6.8),Vector2(4.4,5.9),Vector2(-5.7,-2.4),Vector2(7.5,-8.9),Vector2(10.,-13.6),Vector2(-9.8,-7.8)]:
		for i in 5:
			_fern(Vector3(at.x+rng.randf_range(-.43,.43),.25,at.y+rng.randf_range(-.4,.4)),rng.randf_range(.52,1.0))
	for i in 85:
		var p := Vector2(rng.randf_range(-22,22),rng.randf_range(-22,22))
		if abs(p.x)<4 or p.length()<6: continue
		_rock(Vector3(p.x,.251,p.y),Vector3(.19,.004,.022)*rng.randf_range(.5,2.),Color("#69a899"),5)

func _water_garden() -> void:
	for c in [Vector2(.7,13.6),Vector2(2.1,9.1),Vector2(-5.8,11.3),Vector2(-8.8,3.4),Vector2(5.4,5.9),Vector2(10.,-3.2),Vector2(-6.8,-6.4),Vector2(4.,-8.4)]:
		for i in 17:
			var at: Vector2=c+Vector2(rng.randfn(0,.94),rng.randfn(0,.62))
			_lily(at,rng.randf_range(.12,.30),i==0 or i==5)
	for i in 44:
		var p:=Vector2(rng.randf_range(-6.4,.2),rng.randf_range(10.5,16.0))
		_litter(p,.258)
	# A broken, moss-capped aqueduct spills down a near bank in two tiers.
	for i in 4:
		var p:=Vector3(-9.5+i*.63,.13,7.3+sin(i*.7)*.24)
		_rock(p,Vector3(.84,1.16,.82),Color("#778d81"),7)
		_rock(p+Vector3(-.18,.8,-.84),Vector3(.86,1.46,1.0),Color("#60716d"),7)
		_rock(p+Vector3(-.18,1.88,-.82),Vector3(.74,.28,.74),MOSS,7)
	_cascade(Vector2(-9.44,7.91),1.18,.24,.94)
	_cascade(Vector2(-9.38,7.0),2.14,1.02,.81)
	# High beside the return trail, one bronze brazier marks the ruins at dusk.
	# The amber ceremonial paving catches a warmer bounce than the shaded banks.
	for pool in [Vector3(-2.7,3.2,9.5),Vector3(.48,3.8,-.34)]:
		var bounce:=OmniLight3D.new()
		bounce.position=pool
		bounce.light_color=Color("#ffca86")
		bounce.light_energy=2.15
		bounce.omni_range=6.9
		add_child(bounce)
	for pos in [Vector3(5.43,2.75,-10.15),Vector3(-10.35,2.20,-6.66)]:
		_lantern(pos)

func _ruin_gardens() -> void:
	# Fragmentary wall footings root each span in the water. Offset, stepped courses
	# leave space between both arches for waders and the retreat to the north.
	for cluster in [Vector3(-11.1,0,-6.6),Vector3(9.82,0,-10.6),Vector3(4.93,0,-10.1)]:
		for i in 5:
			var p: Vector3=cluster+Vector3(rng.randf_range(-.20,.47),0,(i-2)*.65)
			var w:=rng.randf_range(.48,.84)
			var poly:=PackedVector2Array([Vector2(-.81,-.40),Vector2(.64,-.46),Vector2(.83,-.13),Vector2(.62,.40),Vector2(-.71,.38)])
			for v in poly.size(): poly[v]=Vector2(p.x,p.z)+poly[v]*w
			_slab(poly,.04,.49+float(i%2)*.18,_stone())
			if i%2==0: _fern(p+Vector3.UP*.55,.77)
	# Interleaved vine runners and carved plinths make the closest arch a garden ruin.
	var origin:=Vector3(8.45,0,3.35)
	var basis:=Basis(Vector3.UP,-.64)
	for sign_side in [-1.,1.]:
		var column:=origin+basis*Vector3(2.25*float(sign_side),0,.07)
		_disc(Vector2(column.x,column.z),.88,.12,.53,_stone(),8)
		_disc(Vector2(column.x,column.z),.70,.51,.69,LIGHT,8)
		for vine in 4:
			var last:=column+basis*Vector3(-.29+vine*.15,3.77,.39)
			for step in 13:
				var at:=last+basis*Vector3(sin(step*.72+vine)*.047,-.18-rng.randf_range(0,.07),.02*cos(step*.68))
				_limb(last,at,.025,.021,MOSS,4)
				var leaf:=at+basis*Vector3((.19 if step%2==0 else -.17),-.10,.10)
				var tint:=Color("#4d834f").lerp(Color("#9aac55"),rng.randf_range(.1,.74))
				_face(at,at+basis*Vector3(.05,-.12,.09),leaf,tint,Vector3.BACK)
				last=at
		for clump in 3:
			var root:=origin+basis*Vector3((.73+.23*clump)*float(sign_side),4.53-.14*clump,.13)
			for j in 4:
				var direction:=basis*Vector3(rng.randf_range(-.22,.22),-.63,.29)
				var tip:=root+direction*rng.randf_range(.64,1.62)
				_limb(root,tip,.021,.011,MOSS,4)
				for n in 5:
					var leaf:=root.lerp(tip,n*.19)+basis*Vector3(.066 if n%2==0 else -.073,0,0)
					_face(leaf,leaf+basis*Vector3(.07,-.13,.04),leaf+basis*Vector3(-.02,-.20,.03),Color("#76a64f"),Vector3.BACK)
		for j in 4:
			_fern(column+Vector3(rng.randf_range(-.43,.43),.62,rng.randf_range(-.24,.24)),.70)
	# Near-right shallows catch the amber leaves framing the crossing illustration.
	for item in [[4.85,13.3,.90],[6.4,13.8,1.15],[6.7,12.8,.72],[3.1,17.6,.55],[-7.1,12.4,.61]]:
		var at:=Vector3(item[0],.15,item[1])
		var r:=float(item[2])
		_rock(at,Vector3(r*1.28,r*.71,r),Color("#738383"),8)
		_rock(at+Vector3.UP*r*.45,Vector3(r*.94,r*.29,r*.78),Color("#78915d"),7)
		for j in 3:
			var base:=at+Vector3(rng.randf_range(-.4,.4),r*.55,rng.randf_range(-.34,.34))
			_copper_frond(base,r*rng.randf_range(.65,1.03))
	for item in [Vector3(-6.1,.55,13.3),Vector3(-5.34,.60,16.3),Vector3(3.9,.44,5.75),Vector3(-7.3,.5,-6.2)]:
		for j in 4: _copper_frond(item+Vector3(rng.randf_range(-.33,.33),0,rng.randf_range(-.22,.22)),rng.randf_range(.62,1.))
	# A lateral branch sits in the camera's left margin several metres in front
	# of the traveler. Small clusters show their orange faces against open sky.
	var start:=Vector3(-8.1,.5,13.7)
	var elbow:=Vector3(-7.45,3.15,12.8)
	var tip:=Vector3(-5.8,4.0,11.45)
	_limb(start,elbow,.29,.16,BARK,7)
	_limb(elbow,tip,.16,.065,BARK,6)
	for i in 8:
		var t:=i/8.
		var at:=elbow.lerp(tip,t)
		var d:=Vector3(.44+.38*t,.28+sin(i)*.30,(.48 if i%2==0 else -.52))
		_limb(at,at+d,.062,.023,BARK,5)
		_crown(at+d,.42,true,false)

func _copper_frond(at: Vector3,size: float) -> void:
	var direction:=Vector3(rng.randf_range(-.65,.65),1.,rng.randf_range(-.68,.68)).normalized()
	var end:=at+direction*size*.82
	var crosswise:=Vector3(-direction.z,.13,direction.x).normalized()
	_limb(at,end,.013,.005,BARK,4)
	for i in 5:
		var t:=(i+1)/6.
		var p:=at.lerp(end,t)
		for hand in [-1.,1.]:
			var v:=crosswise*float(hand)*size*(.34-t*.14)+direction*size*.20
			var w:=direction*size*(.069-.025*t)
			var tint:=Color("#d4672d").lerp(Color("#f7ad44"),t*.72+rng.randf_range(-.1,.1))
			tint.a=.65
			_face(p,p+v*.5+w,p+v,tint,Vector3.UP)
			_face(p,p+v,p+v*.5-w,tint.darkened(.08),Vector3.UP)

func _lily(p: Vector2,r: float,flower: bool) -> void:
	var at:=Vector3(p.x,.266,p.y)
	var angle:=rng.randf()*TAU
	var tint:=Color("#418761").lerp(Color("#96b467"),rng.randf())
	for j in 9:
		var a:=angle+.19+j*(TAU-.38)/9
		var b:=angle+.19+(j+1)*(TAU-.38)/9
		var s:=Vector3(cos(a)*r,.004,sin(a)*r*.84)
		var t:=Vector3(cos(b)*r,.004,sin(b)*r*.84)
		_face(at,at+s,at+t,tint.lerp(tint.lightened(.12),float(j%2)),Vector3.UP)
	if flower:
		at.y+=.025
		for j in 7:
			var d:=Vector3(cos(j*TAU/7),.72,sin(j*TAU/7))*r*.56
			var w:=Vector3(-d.z,0,d.x)*.36
			_face(at,at+d*.6+w,at+d,Color("#eac7ab"),Vector3.UP)
			_face(at,at+d,at+d*.6-w,Color("#f5e3bb"),Vector3.UP)

func _lantern(p: Vector3) -> void:
	var anchor:=p+Vector3(-.53,.91,-.17)
	_limb(anchor,p+Vector3.UP*.79,.048,.026,BARK,6)
	_limb(p+Vector3.UP*.80,p+Vector3.UP*.26,.018,.018,BARK,5)
	for i in 4:
		var v:=Vector3(cos(i*PI*.5),0,sin(i*PI*.5))*.124
		_limb(p+v-Vector3.UP*.07,p+v+Vector3.UP*.21,.015,.018,BARK,4)
	_rock(p+Vector3.UP*.24,Vector3(.24,.12,.24),Color("#977448"),6)
	_rock(p-Vector3.UP*.09,Vector3(.16,.075,.16),Color("#72573b"),6)
	var glass:=MeshInstance3D.new()
	var shade:=CylinderMesh.new()
	shade.top_radius=.120
	shade.bottom_radius=.102
	shade.height=.27
	shade.radial_segments=4
	var glow:=StandardMaterial3D.new()
	glow.albedo_color=Color("#ffbf4b")
	glow.emission_enabled=true
	glow.emission=Color("#ffac32")
	glow.emission_energy_multiplier=3.4
	shade.material=glow
	glass.mesh=shade
	glass.position=p+Vector3.UP*.07
	add_child(glass)
	var light:=OmniLight3D.new()
	light.light_color=Color("#ffb257")
	light.light_energy=3.2
	light.omni_range=4.
	light.position=p+Vector3.FORWARD*.22
	add_child(light)

func _fern(base: Vector3,size: float) -> void:
	for i in 7:
		var a := TAU*i/7+rng.randf_range(-.15,.15)
		var dir := Vector3(cos(a),0,sin(a))
		var side := Vector3(-dir.z,.18,dir.x)
		var green := Color("#548245").lerp(Color("#8e9a41"),rng.randf())
		var reach := rng.randf_range(.60,.92)*size
		for pair in 5:
			var t := (pair+1)/6.0
			var at := base+dir*t*reach+Vector3.UP*(sin(t*2.05)*.60)*size
			var end := at+dir*.12*size
			var width := (1.-t*.75)*size*.18
			for hand in [-1.0,1.0]:
				var tip: Vector3 = at+side*width*float(hand)+dir*.09*size
				_face(at,tip,end,green,Vector3.UP)
				_face(at,end,at+side*.015*size,green.darkened(.16),Vector3.UP)

func _alder(at: Vector3, height: float, copper: bool, bearing: float, distant := false) -> void:
	var b := Color("#684e3b") if copper else Color("#425761")
	var along := Vector3(cos(bearing),0,sin(bearing))
	var crosswise := Vector3(-along.z,0,along.x)
	var heel := at+along*height*.06+Vector3.UP*height*.27
	var fork := at+along*height*.16+Vector3.UP*height*.53
	_limb(at,heel,height*.094,height*.062,b,8)
	_limb(heel,fork,height*.064,height*.048,b,8)
	if not distant:
		for j in 6:
			var a := bearing+j*TAU/6
			var r := Vector3(cos(a),0,sin(a))
			var root := at+r*height*rng.randf_range(.13,.21)
			_limb(root+Vector3.DOWN*.06,at+r*.18+Vector3.UP*height*.12,height*.015,height*.062,b,5)
	var heads := 6 if distant else 10
	for j in heads:
		var a := bearing+TAU*j*.382
		var radial := Vector3(cos(a),0,sin(a))
		var reach := height*(.42-.02*j)
		var elbow := fork+radial*reach*.49+Vector3.UP*height*(.05+.013*j)
		var twig := fork+radial*reach+Vector3.UP*height*(.14+.026*j)
		_limb(fork,elbow,height*.035,height*.022,b,6)
		_limb(elbow,twig,height*.024,height*.009,b,5)
		var spread := height*rng.randf_range(.15,.23)
		_crown(twig,spread,copper,distant)
		if not distant:
			var secondary := elbow+crosswise*spread*(1 if j%2==0 else -1)+Vector3.UP*spread*.53
			_limb(elbow,secondary,height*.018,height*.006,b,5)
			_crown(secondary,spread*.68,copper,false)

func _limb(a: Vector3,b: Vector3,r0: float,r1: float,col: Color,sides: int) -> void:
	var axis := (b-a).normalized()
	var right := axis.cross(Vector3.BACK)
	if right.length_squared()<.01: right=axis.cross(Vector3.RIGHT)
	right=right.normalized()
	var up:=axis.cross(right)
	for j in sides:
		var t:=TAU*j/sides
		var s:=TAU*(j+1)/sides
		var d:=right*cos(t)+up*sin(t)
		var e:=right*cos(s)+up*sin(s)
		var tint:=col.darkened(.11+.10*sin(t*2.0))
		tint.a = .86
		_face(a+d*r0,a+e*r0,b+e*r1,tint,d+e)
		_face(a+d*r0,b+e*r1,b+d*r1,tint,d+e)

func _crown(center: Vector3, spread: float, copper: bool, distant: bool) -> void:
	# Each branch carries a canopy of overlapping pointed foliage fans. Clear gaps
	# between fans let sky and moonlight show through the outer silhouettes.
	var shade := Color("#bb4d12") if copper else Color("#065962")
	var bright := Color("#ffc043") if copper else Color("#15bca8")
	var sprays := 9 if distant else 15
	for j in sprays:
		var angle:=j*2.39996+rng.randf_range(-.18,.18)
		var r:=sqrt((j+.5)/sprays)
		var d:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-d.z,0,d.x)
		var p:=center+d*r*spread+Vector3.UP*spread*(.37*(1.-r*r)+rng.randf_range(-.15,.13))
		var tint:=shade.lerp(bright,rng.randf_range(.11,.82)*(1.-r*.31))
		tint.a=.65
		var leaf_length:=spread*rng.randf_range(.42,.68)
		for leaf in 5:
			var f:=d.rotated(Vector3.UP,(leaf-2)*.37)
			var width:=Vector3(-f.z,rng.randf_range(-.35,.36),f.x)*spread*.146
			var tip:=p+f*leaf_length-Vector3.UP*spread*(.15+absf(leaf-2)*.025)
			var vein:=p.lerp(tip,.46)+Vector3.UP*spread*.075
			var near:=p-f*.12*spread
			_face(near,vein+width,tip,tint,Vector3.UP)
			_face(near,tip,vein-width,tint.darkened(.09),Vector3.UP)
		if not distant and j%5==0:
			var end:=p+d*spread*.45-Vector3.UP*spread*.46
			_limb(p,end,spread*.021,spread*.008,BARK,4)
			var elm:=shade.lerp(bright,.73)
			elm.a=.65
			_face(end,end+side*.16*spread+Vector3.UP*.23*spread,end-d*.16*spread+Vector3.UP*.40*spread,elm,Vector3.UP)

func _crack(p: Vector2, h: float, f: Vector2, side: Vector2) -> void:
	var offset := side*rng.randf_range(-.13,.13)
	var cur := p-f*.41
	for i in 3:
		var end := cur+f*rng.randf_range(.10,.21)+side*rng.randf_range(-.10,.10)
		var s := side*.009
		_face(Vector3(cur.x,h,cur.y),Vector3(end.x+s.x,h,end.y+s.y),Vector3(end.x-s.x,h,end.y-s.y),Color("#867c66"),Vector3.UP)
		cur = end+offset*.08

func _litter(p: Vector2,h: float) -> void:
	for i in rng.randi_range(4,9):
		var at := p+Vector2(rng.randf_range(-.24,.24),rng.randf_range(-.22,.22))
		var a := rng.randf()*TAU
		var d := Vector3(cos(a),0,sin(a))*rng.randf_range(.043,.10)
		var across := Vector3(-d.z,0,d.x)*.42
		var center := Vector3(at.x,h,at.y)
		var tint := Color("#b57731").lerp(Color("#96874e"),rng.randf())
		_face(center-d,center+across,center+d,tint,Vector3.UP)
		_face(center+d,center-across,center-d,tint.darkened(.1),Vector3.UP)

func _grass(p: Vector2, y: float, count: int) -> void:
	for i in count:
		var a := rng.randf()*TAU
		var dir := Vector3(cos(a),0,sin(a))
		var across := Vector3(-dir.z,0,dir.x)
		var base := Vector3(p.x,y,p.y)+dir*rng.randf_range(.01,.19)
		var h := rng.randf_range(.21,.72)
		var tip := base+Vector3.UP*h+dir*h*.45
		var bend := base+Vector3.UP*h*.59+dir*h*.13
		var w := rng.randf_range(.024,.051)
		var color := REED.lerp(Color("#a89652"),rng.randf_range(.0,.60))
		_reed_face(base-across*w, bend, base+across*w, color, Vector3(0, .52, 0))
		_reed_face(base+across*w, bend, tip, color.lightened(.07), Vector3(0, .52, 1))
		_reed_face(bend, base-across*w, tip, color.darkened(.06), Vector3(.52, 0, 1))

func _reed_face(a: Vector3, b: Vector3, c: Vector3, tint: Color, weights: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	points.append_array(PackedVector3Array([a, b, c]))
	for amount in [weights.x, weights.y, weights.z]:
		var shade := tint
		shade.a = .44 - float(amount) * .32
		normals.append(normal)
		colors.append(shade)

func _stone() -> Color:
	return CREAM.lerp(LIGHT,rng.randf_range(-.27,.88)).lerp(SHADE,rng.randf_range(0,.19))

func _disc(center: Vector2, radius: float, low: float, high: float, color: Color, sides: int) -> void:
	var poly := PackedVector2Array()
	for i in sides:
		poly.append(center+Vector2(cos(TAU*i/sides),sin(TAU*i/sides))*radius)
	_slab(poly,low,high,color)

func _slab(poly: PackedVector2Array, low: float, high: float, color: Color) -> void:
	var center := Vector2.ZERO
	for p in poly: center += p
	center /= poly.size()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i+1)%poly.size()]
		var a := Vector3(p.x,high,p.y)
		var b := Vector3(q.x,high,q.y)
		var outer_a := Vector3(p.x,high-minf(.045,(high-low)*.25),p.y)
		var outer_b := Vector3(q.x,outer_a.y,q.y)
		var mid := Vector3(center.x,high,center.y)
		a = a.lerp(mid,.020)
		b = b.lerp(mid,.020)
		_face(a,b,mid,color,Vector3.UP)
		_face(outer_a,outer_b,b,color.darkened(.035),Vector3.UP*.6+(outer_a-mid).normalized()*.4)
		_face(outer_a,b,a,color.darkened(.035),Vector3.UP*.6+(outer_a-mid).normalized()*.4)
		var foot := Vector3(p.x,low,p.y)
		var far_foot := Vector3(q.x,low,q.y)
		var normal := Vector3((p.x+q.x)*.5-center.x,0,(p.y+q.y)*.5-center.y).normalized()
		_face(outer_a,foot,far_foot,color.darkened(.12),normal)
		_face(outer_a,far_foot,outer_b,color.darkened(.12),normal)

func _rock(origin: Vector3, extent: Vector3, tint: Color, sides:=7) -> void:
	var rim := PackedVector3Array()
	var cap := PackedVector3Array()
	var shift := rng.randf()*TAU
	for i in sides:
		var a := TAU*i/sides+shift
		var reach := rng.randf_range(.82,1.08)
		var v := Vector3(cos(a)*extent.x,0,sin(a)*extent.z)*reach
		rim.append(origin+v+Vector3.UP*extent.y*rng.randf_range(-.35,.21))
		cap.append(origin+v*rng.randf_range(.46,.83)+Vector3.UP*extent.y*rng.randf_range(.65,1.0))
	var top := origin+Vector3.UP*extent.y
	var bottom := origin-Vector3.UP*extent.y*.75
	# The solid shoreline and tree footings also stop the camera's sweep.
	if extent.y>.6 and origin.y<2.2 and extent.x>.5:
		var hull := ConvexPolygonShape3D.new()
		var hull_points := rim.duplicate()
		hull_points.append_array(cap)
		hull_points.append(top)
		hull_points.append(bottom)
		hull.points = hull_points
		var collision := CollisionShape3D.new()
		collision.shape = hull
		ground.add_child(collision)
	for i in sides:
		var j := (i+1)%sides
		var col := tint.darkened(rng.randf_range(.0,.10))
		_face(top,cap[i],cap[j],col,Vector3.UP)
		_face(cap[i],rim[i],rim[j],col,(cap[i]+rim[j])*.5-origin)
		_face(rim[j],cap[j],cap[i],col,(cap[i]+rim[j])*.5-origin)
		_face(rim[i],bottom,rim[j],col.darkened(.12),rim[i]-origin)

func _face(a: Vector3,b: Vector3,c: Vector3,col: Color,out: Vector3) -> void:
	if (c-a).cross(b-a).dot(out)<0:
		_tri(a,c,b,col)
	else:
		_tri(a,b,c,col)

func _tri(a: Vector3,b: Vector3,c: Vector3,col: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	points.append(a)
	points.append(b)
	points.append(c)
	for i in 3:
		normals.append(normal)
		colors.append(col)

func _asset(scene: PackedScene, pos: Vector3, size: Vector3, yaw: float, ruined := false) -> void:
	if not templates.has(scene):
		var target: Node3D = scene.instantiate()
		var shapes: Array = []
		_collect_mesh(target,Transform3D.IDENTITY,shapes)
		target.free()
		templates[scene] = shapes
	var placement := Transform3D(Basis(Vector3.UP,yaw).scaled_local(size),pos)
	for shape in templates[scene]:
		var verts: PackedVector3Array = shape[0]
		if ruined and shape[3].y>1.60 and shape[3].x<.71 and shape[3].x>-.99:
			continue
		var ns: PackedVector3Array = shape[1]
		var col: Color = shape[2]
		var basis := placement.basis.inverse().transposed()
		for i in verts.size():
			points.append(placement*verts[i])
			normals.append((basis*ns[i]).normalized())
			colors.append(col)

func _collect_mesh(node: Node, parent: Transform3D, output: Array) -> void:
	var t := parent
	if node is Node3D: t = parent*node.transform
	if node is MeshInstance3D:
		for s in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(s)
			var tint: Color = mat.albedo_color if mat is BaseMaterial3D else CREAM
			var data: Array = node.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
			var ids: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			var v := PackedVector3Array()
			var n := PackedVector3Array()
			var basis := t.basis.inverse().transposed()
			for k in (vs.size() if ids.is_empty() else ids.size()):
				var ix := k if ids.is_empty() else ids[k]
				v.append(t*vs[ix])
				n.append((basis*ns[ix]).normalized())
			var center := Vector3.ZERO
			for vertex in v: center += vertex
			center /= maxf(v.size(),1)
			output.append([v,n,tint,center])
	for child in node.get_children(): _collect_mesh(child,t,output)

func _finish_mesh() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = PALETTE
	mat.set_shader_parameter("route_paint", ROUTE_PAINT)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,mat)
	var geometry := MeshInstance3D.new()
	geometry.name = "CausewaysAndFloodedArcade"
	geometry.mesh = mesh
	add_child(geometry)
	points.clear()
	normals.clear()
	colors.clear()
	templates.clear()
