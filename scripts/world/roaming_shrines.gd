extends RefCounted
## The bake supplies continuous floors and road spurs. Only encounter pieces move.

const WAYMARK := preload("res://scripts/world/waymark.gd")
const KIT := preload("res://scripts/world/roaming_shrine_kit.gd")
const SPECS := {
	&"flooded_grove": preload("res://data/sites/grove.tres"),
	&"broken_quarry": preload("res://data/sites/quarry.tres"),
	&"fallen_relay": preload("res://data/sites/relay.tres"),
	&"lanternwood": preload("res://data/sites/lanternwood.tres"),
	&"sunken_aqueduct": preload("res://data/sites/sunken_aqueduct.tres"),
	&"sunwatch_observatory": preload("res://data/sites/sunwatch.tres"),
	&"last_lantern_frontier": preload("res://data/sites/frontier.tres"),
}
const SOCKETS := [Vector3(-5.4,.06,-3.8), Vector3(5.4,.06,-3.8),
	Vector3(-5.1,.06,5.1), Vector3(5.1,.06,5.1), Vector3(3.9,.06,-6.1)]
const APPROACHES := [
	[Vector3(-9.2,.035,2.05), Vector3(-6.3,.035,1.7), Vector3(-4.4,.035,1.25)],
	[Vector3(9.2,.035,2.05), Vector3(6.3,.035,1.7), Vector3(4.4,.035,1.25)],
	[Vector3(1.0,.035,9.2), Vector3(.9,.035,6.25), Vector3(.8,.035,4.4)],
]

static func parcel_definitions(layout_id: int) -> Array:
	return CinderJourneyLayout.parcel_definitions(layout_id)

static func install(parent: Node3D, layout: CinderJourneyLayout) -> Array[CinderSite]:
	var points := {}
	for parcel: Dictionary in parcel_definitions(layout.layout_id):
		points[parcel.id] = parcel
	var returned: Array[CinderSite] = []
	if points.is_empty() or layout.roaming_placements.size() != SPECS.size():
		push_error("Roaming camps require a complete parcel catalogue and placement")
		return returned
	var packed := load("res://art/outer_valley/roaming_parcels_%d.glb" % layout.layout_id) as PackedScene
	if packed == null:
		push_error("Roaming parcel terrain is missing")
		return returned
	var flooring := packed.instantiate() as Node3D
	flooring.name = "RoamingParcelTerrain"
	parent.add_child(flooring)
	_paint_terrain(flooring)
	for id: StringName in CinderJourneyLayout.CAMPS:
		var selection: Dictionary = layout.roaming_placements[id]
		var parcel: Dictionary = points[selection.parcel]
		var frame := Transform3D(Basis(Vector3.UP, float(parcel.yaw)), vector(parcel.center))
		var site := _camp(parent, SPECS[id], parcel, frame, selection.offset)
		returned.append(site)
	return returned

static func _paint_terrain(flooring: Node3D) -> void:
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://art/outer_valley/valley_pigment.gdshader")
	stone.set_shader_parameter("route_paint", preload("res://art/textures/stylized/route_paint.png"))
	stone.set_shader_parameter("brush_detail", preload("res://art/textures/stylized/valley_brush.png"))
	var soil := stone.duplicate() as ShaderMaterial
	soil.set_shader_parameter("family", 1)
	for part: MeshInstance3D in flooring.find_children("*", "MeshInstance3D", true, false):
		var is_deck := str(part.name).begins_with("Deck")
		part.material_override = soil if is_deck else stone
		# The deck casts a single terrain shadow for the low-relief dressing.
		if not is_deck:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func apply_habitats(sites: Array[CinderSite], grove: CinderGrove, quarry: CinderQuarry,
		relay: CinderRelay, frontier: CinderFrontier, valley: CinderOuterValley) -> void:
	for site in sites:
		match site.checkpoint_id:
			&"flooded_grove":
				site.habitat_frame = grove.habitat_transform()
			&"broken_quarry":
				site.habitat_frame = quarry.habitat_transform()
			&"fallen_relay":
				site.habitat_frame = relay.habitat_transform()
			&"last_lantern_frontier":
				site.habitat_frame = frontier.habitat_transform()
			_:
				site.habitat_frame = valley.habitat_transform(site.checkpoint_id)

static func _camp(parent: Node3D, spec: CinderSiteSpec, parcel: Dictionary, frame: Transform3D,
		anchor: Vector3) -> CinderSite:
	var site := CinderSite.new()
	site.name = spec.label.to_pascal_case() + "Camp"
	parent.add_child(site)
	var pad := frame * anchor
	var sockets := PackedVector3Array()
	var count := 5 if spec.id == &"sunwatch_observatory" else 4
	for i in count:
		sockets.append(site.to_local(frame * SOCKETS[i]))
	var lanes: Array[PackedVector3Array] = []
	for arm in spec.lane_names.size():
		var lane := frame * PackedVector3Array(APPROACHES[arm])
		lane.append(pad)
		lanes.append(lane)
	var look := frame * Vector3(anchor.x * .45, .5, anchor.z * .45)
	site.configure(spec, site.to_local(pad), sockets, lanes, frame * Vector3(12.5, 18.2, 18.7), look)
	site.parcel_id = parcel.id
	site.parcel_frame = frame
	site.recovery_point = frame * Vector3(0, .11, -4.4)
	site.approach = path(parcel)
	site.approach.append(site.recovery_point)
	site.approach.append(pad)
	site.wet = spec.id == &"flooded_grove" and bool(parcel.wet)
	var kit := KIT.new()
	site.add_child(kit)
	kit.build_camp(site, Transform3D(frame.basis, pad))
	_sign(site, frame)
	return site

static func path(parcel: Dictionary) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Array in parcel.access:
		result.append(vector(point))
	return result

static func vector(xyz: Array) -> Vector3:
	return Vector3(xyz[0], xyz[1], xyz[2])

static func _sign(site: CinderSite, frame: Transform3D) -> void:
	var point := site.approach[0]
	var direction := point.direction_to(site.approach[1])
	var mark: CinderWaymark = WAYMARK.new()
	site.add_child(mark)
	# Plunge the footing into the verge where the new path meets the through road.
	mark.global_position = point + direction * 1.1 + direction.cross(Vector3.UP) * .74
	mark.set_destination(site.label + " Shrine", direction)
	var camp_mark: CinderWaymark = WAYMARK.new()
	site.add_child(camp_mark)
	camp_mark.global_position = frame * Vector3(-1.35,.0,-8.3)
	camp_mark.set_destination(site.label + " Shrine", frame.basis.z)
