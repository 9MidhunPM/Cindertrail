class_name CinderGrove
extends Node3D
## Hand-laid Flooded Grove. Geometry is baked once into static vertex-coloured batches.
## All points on the causeways and in the flooded lanes belong to the same physics space.

const ARCH = preload("res://art/models/ruin_arch.glb")
const PILLAR = preload("res://art/models/ruin_pillar.glb")
const TREE = preload("res://art/models/teal_tree.glb")
const COPPER_TREE = preload("res://art/models/orange_tree.glb")
const WATER = preload("res://art/materials/grove/shallows.gdshader")
const PALETTE = preload("res://art/materials/grove/weathered_palette.gdshader")
const FALL = preload("res://art/materials/grove/waterfall.gdshader")
const CREAM = Color("#c1a57f")
const LIGHT = Color("#ddcbaa")
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
	_finish_mesh()

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
				var poly := PackedVector2Array([start+side*x0+forward*.027,start+side*x1+forward*.027,end+side*x2-forward*.027,end+side*x3-forward*.027])
				var high := rng.randf_range(.642,.70)
				_slab(poly,.38+rng.randf_range(-.13,.03),high,_stone())
				if rng.randf()<.27:
					_crack((start+end)*.5+side*(x0+x1)*.5,high+.002,forward,side)
				if lane!=1 and rng.randf()<.38:
					_litter(start+side*(x0 if lane==0 else x1),high+.015)

			previous_seam = seam
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
	for p in [[-8.5,-6.8,1.9,-.22],[-13.70,-10.15,.90,-.42],[7.4,-10.2,2.18,.31],[16.6,-13.3,1.13,.22],[-5.6,-18.0,1.18,-.10]]:
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
		for i in 5:
			var a := rng.randf()*TAU
			var at := pos+Vector3(cos(a),0,sin(a))*rng.randf_range(1.,float(bank[2])*.80)
			var sc := rng.randf_range(.70,1.25)
			_asset(TREE,at+Vector3.UP*float(bank[3])*.48,Vector3(sc*1.45,sc,sc*1.45),a)
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

func _cascade(p: Vector2) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := ShaderMaterial.new()
	mat.shader = FALL
	st.set_material(mat)
	for i in 8:
		var x := p.x+i*.17
		var h := 1.51+.19*sin(float(i))
		var z := p.y+.09*sin(i*.78)
		var a := Vector3(x,h,z)
		var b := a+Vector3(.174,.06,0)
		var c := Vector3(x+.22,.25,z+.55)
		var d := Vector3(x-.055,.25,z+.55)
		for v in [a,b,c,a,c,d]:
			st.set_normal(Vector3.FORWARD)
			st.add_vertex(v)
		var pt := Vector3(x,.263,z+.61+rng.randf_range(-.19,.25))
		_rock(pt,Vector3(.22,.025,.14),Color("#92c5b4"))
	var mesh := MeshInstance3D.new()
	mesh.name = "Cascade"
	mesh.mesh = st.commit()
	add_child(mesh)

func _plantings() -> void:
	# Foreground branches deliberately overhang at the frame edges. The broad grove
	# canopy is made of clustered new foliage layered on the original kit trees.
	var groups := [[-10.0,11.2,1.7],[-15.2,8.6,2.35],[-18,12.7,2.4],[12.7,11.7,2.2],[20.,8.2,2.1],[-19,-11.5,2.25],[-16,-14.2,2.2],[-11.5,-14.5,1.75],[-8.0,-16.3,2.25],[-4.0,-20.0,1.66],[4.8,-20.8,2.16],[10.,-19.5,2.2],[16.7,-18.3,2.18],[20.,-13.5,2.1],[17.,-5.,1.74],[-16,18.8,2.15],[14.3,20.,2.1]]
	for i in groups.size():
		var p: Array = groups[i]
		var size := float(p[2])
		var copper := i in [0,4,13]
		var at := Vector3(p[0],.0,p[1])
		var crown := at+Vector3(0,size*2.32,0)
		_box_floor(at+Vector3.UP*size*1.03,Vector3(.42,2.06,.42)*size)
		_rock(at,Vector3(size*.82,.79,size*.77),Color("#63715c"))
		_asset(COPPER_TREE if copper else TREE,at,Vector3(size*1.32,size,size*1.32),rng.randf()*TAU)
		for j in 18:
			var a := j*TAU/7.0+.37*(j/7)
			var r := (1.0-float(j)/25.0)*size*1.08
			var leaf := crown+Vector3(r*cos(a),size*(.19*(j/7)+rng.randf_range(-.26,.06)),r*sin(a))
			var col := Color("#bc6a29") if copper else Color("#257763")
			col = col.lightened(rng.randf_range(.0,.075)) if j>7 else col.darkened(rng.randf_range(.04,.22))
			_rock(leaf,Vector3(size*.61,size*.26,size*.56)*rng.randf_range(.76,1.27),col,7)
			_leaf_spray(leaf,size,col,copper)
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

func _leaf_spray(base: Vector3, size: float, color: Color, copper: bool) -> void:
	for i in 20:
		var a := rng.randf()*TAU
		var r := rng.randf_range(.35,.86)*size
		var d := Vector3(cos(a),rng.randf_range(-.28,.04),sin(a))
		var pos := base+d*r+Vector3.UP*rng.randf_range(-.16,.23)*size
		var across := Vector3(-d.z,.28,d.x)*rng.randf_range(.044,.084)*size
		var v := rng.randf_range(.15,.28)*size
		var tint := color.lerp(Color("#e0a548") if copper else Color("#56a275"),rng.randf_range(.16,.73))
		_face(pos-d*v,pos+across,pos+d*v,tint,Vector3.UP)
		_face(pos-d*v,pos+d*v,pos-across,tint.darkened(.105),Vector3.UP)

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
		_tri(base-across*w,bend,base+across*w,color)
		_tri(base+across*w,bend,tip,color.lightened(.07))
		_tri(bend,base-across*w,tip,color.darkened(.06))

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
