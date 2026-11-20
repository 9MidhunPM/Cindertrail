extends RefCounted
## Low plants and dislodged stones pick out the edge of each old terrace.

const MESH := preload("res://scripts/world/environment_mesh.gd")
const WATER := preload("res://art/materials/grove/terrace_shallows.gdshader")
const BRUSH := preload("res://art/textures/stylized/valley_brush.png")
const GREEN := Color("#668557")
const TEAL := Color("#48766c")
const GOLD := Color("#cb842d")
const STONE := Color("#99937f")

static func add_rim(host: Node3D, site: CinderSite) -> void:
	var rim := Node3D.new()
	rim.name = "WeatheredTerraceRim"
	host.add_child(rim)
	rim.global_transform = site.parcel_frame
	var rock := MESH.new()
	var leaves := MESH.new()
	var random := RandomNumberGenerator.new()
	random.seed = hash("%s:%s" % [site.parcel_id, site.checkpoint_id])
	for patch in 26:
		var angle := (patch + random.randf_range(-.24,.24)) * TAU / 26.0
		var radius := random.randf_range(11.0,12.55)
		var at := Vector3(cos(angle) * radius, .012, sin(angle) * radius)
		if not _clear(site, rim.to_global(at)):
			continue
		var moss := TEAL if site.wet else GREEN
		var accent := GOLD if patch % 3 != 0 else moss
		for tuft in 6:
			var tip := angle + TAU * float(tuft) / 6.0
			var direction := Vector3(cos(tip),0,sin(tip))
			var root := at + direction * random.randf_range(.02,.24)
			var side := direction.cross(Vector3.UP) * random.randf_range(.032,.07)
			var height := random.randf_range(.22, .49)
			var point := root + direction * .18 + Vector3.UP * height
			leaves.face(root - side, root + side, point, moss.lerp(accent, random.randf()), Vector3.UP)
			leaves.face(root, root - side, point, moss.darkened(.23), Vector3.UP)
		for stone in 2 + (patch % 3):
			var rump := at + Vector3(random.randf_range(-.45,.43),.045,random.randf_range(-.34,.34))
			var size := random.randf_range(.14,.34)
			rock.facets(rump, Vector3(size, size * .46, size * .74), 5 + stone % 2,
				STONE.lerp(moss, random.randf_range(.07,.44)), random.randf())
	for piece: MeshInstance3D in [
		rock.mount(rim, "LooseLimestone", MESH.pigment(), false),
		leaves.mount(rim, "TerracePlants", MESH.pigment(0, true), false),
	]:
		if piece:
			piece.visibility_range_end = 76.0
			piece.visibility_range_end_margin = 8.0
	if site.checkpoint_id == &"flooded_grove":
		_grove_fringe(site, rim, random)

static func _grove_fringe(site: CinderSite, rim: Node3D, random: RandomNumberGenerator) -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER
	material.set_shader_parameter("brush_detail", BRUSH)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The broad western pool includes the existing slow ford. The other two are
	# sheltered, ankle-deep hollows; their flat terrain remains traversable.
	if site.wet:
		_pool(surface, Vector3(-7.43,.088,1.7), Vector2(3.91, 3.37), random)
	_pool(surface, Vector3(-5.37,.065,-6.76), Vector2(2.68, 3.61), random)
	_pool(surface, Vector3(6.85,.065,5.1), Vector2(2.43, 3.02), random)
	var water := MeshInstance3D.new()
	water.name = "GroveShallows"
	water.mesh = surface.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.visibility_range_end = 78.0
	water.visibility_range_end_margin = 8.0
	rim.add_child(water)

	var ruin := MESH.new()
	var chalk := Color("#d0c7ab")
	for prop in [
		[Vector3(-7.6,.0,-7.45), 6],
		[Vector3(-10.5,.0,-5.04), 4],
		[Vector3(-7.8,.0,-9.35), 3],
		[Vector3(6.3,.0,-8.55), 5],
		[Vector3(8.95,.0,-7.5), 4],
	]:
		var foot: Vector3 = prop[0]
		if not _clear(site, rim.to_global(foot)):
			continue
		ruin.block(foot + Vector3.UP*.16, Vector3(.57,.16,.51), chalk.darkened(.2))
		var top := 0.32
		for row: int in prop[1]:
			var drift := Vector3(random.randf_range(-.055,.055),0,random.randf_range(-.04,.04))
			var tint := chalk.lerp(TEAL, random.randf_range(.06,.27))
			ruin.block(foot + drift + Vector3.UP*(top + .187), Vector3(.37,.182,.35),
				tint, random.randf_range(-.10,.12))
			top += .375
		ruin.block(foot + Vector3.UP*(top + .07), Vector3(.49,.07,.43),
			chalk, random.randf_range(-.15,.15))
		var ivy := foot + Vector3(.26,.06,.29)
		ruin.facets(ivy, Vector3(.33,.22,.28), 6, GREEN)
	ruin.mount(rim, "GroveLimestonePillars", MESH.pigment(), false)

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#a96d33")
	gold.emission_enabled = true
	gold.emission = Color("#eea548")
	gold.emission_energy_multiplier = .29
	gold.roughness = .67
	var inlays := MESH.new()
	var core_at := rim.to_local(site.anchor.global_position)
	for index in 9:
		var angle := (index + .18) * TAU / 9.0
		var point := core_at + Vector3(cos(angle)*2.14,.0,sin(angle)*2.14)
		point.y = .048
		inlays.block(point, Vector3(.19,.014,.036), Color.WHITE, -angle)
	inlays.mount(rim, "AmberTerraceInlays", gold, false)

static func _pool(tool: SurfaceTool, center: Vector3, extent: Vector2, random: RandomNumberGenerator) -> void:
	var edge := PackedVector2Array()
	var segments := 26
	for index in segments:
		var angle := float(index) * TAU / segments
		var bank := random.randf_range(.89,1.10)
		edge.append(Vector2(cos(angle),sin(angle))*bank)
	for index in segments:
		for uv in [Vector2.ZERO, edge[index], edge[(index+1)%segments]]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(uv)
			tool.add_vertex(center + Vector3(uv.x*extent.x,0,uv.y*extent.y))

static func _clear(site: CinderSite, at: Vector3) -> bool:
	var point := at.slide(Vector3.UP)
	for marker in site.sockets:
		if point.distance_to(marker.global_position.slide(Vector3.UP)) < 2.1:
			return false
	var paths := site.lanes.duplicate()
	paths.append(site.approach)
	for path in paths:
		for i in range(1,path.size()):
			var nearest := Geometry3D.get_closest_point_to_segment(point,
				path[i - 1].slide(Vector3.UP), path[i].slide(Vector3.UP))
			if point.distance_to(nearest) < 2.7:
				return false
	return true
