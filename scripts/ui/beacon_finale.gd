extends CanvasLayer
## One continuous camera and three original paintings echo the prologue.
## All staging is visual. The game owns delivery, dawn and victory persistence.
signal finished
signal score_cue(cue: StringName)

const INK := preload("res://scripts/ui/dawn_paint.gdshader")
const PLATES: Array[String] = [
	"res://art/comic/ending/01_arch.webp", "res://art/comic/ending/02_ford.webp",
	"res://art/comic/ending/03_relay.webp"]
const BEATS := [&"handoff", &"arch", &"ford", &"relay", &"return", &"settled"]
const TIMES := [0.0, 4.0, 9.0, 15.0, 21.0, 26.0]
const DISSOLVE := .70

var active := false
var elapsed := 0.0
var phase: StringName = &""
var _beat := 0
var _still := false
var _blocked := false
var _director: CinderCamera
var _traveler: Node3D
var _beacon: Node3D
var _opening_pose: Transform3D
var _opening_lens := 46.0
var _normal_mask: int
var _plates: Array[TextureRect] = []
@onready var _page: Control = $Page
@onready var _skip: Button = $Page/SkipEnding

func _ready() -> void:
	_page.hide()
	set_process(false)
	set_process_input(false)
	_skip.pressed.connect(skip)

func play(director: CinderCamera, traveler: Node3D, beacon: Node3D, reduced_motion: bool) -> void:
	if active or phase == &"settled":
		return
	_director = director
	_traveler = traveler
	_beacon = beacon
	_still = reduced_motion
	_opening_pose = director.camera.global_transform
	_opening_lens = director.camera.fov
	_normal_mask = director.camera.cull_mask
	for index in PLATES.size():
		var painting := TextureRect.new()
		painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		painting.texture = load(PLATES[index]) as Texture2D
		var ink := ShaderMaterial.new()
		ink.shader = INK
		ink.set_shader_parameter(&"plate", index)
		ink.set_shader_parameter(&"still", _still)
		painting.material = ink
		$Page/Paintings.add_child(painting)
		painting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		painting.hide()
		_plates.append(painting)
	active = true
	phase = BEATS[0]
	_page.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_skip.grab_focus()
	set_process(true)
	set_process_input(true)
	_render()
	score_cue.emit(phase)

func _process(delta: float) -> void:
	if not active:
		return
	elapsed = minf(elapsed + delta / maxf(Engine.time_scale, .001), TIMES[-1])
	while _beat < BEATS.size() - 2 and elapsed >= TIMES[_beat + 1]:
		_beat += 1
		phase = BEATS[_beat]
		if phase == &"arch":
			_block_traveler()
		score_cue.emit(phase)
		if not active:
			return
	_render()
	if elapsed >= TIMES[-1]:
		_complete()

func _input(event: InputEvent) -> void:
	if not active or event.is_echo():
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()

func skip() -> void:
	if active:
		_complete()

func _complete() -> void:
	if not active:
		return
	active = false
	set_process(false)
	set_process_input(false)
	elapsed = TIMES[-1]
	phase = &"settled"
	_block_traveler()
	_director.camera.cull_mask = _normal_mask
	_wide(1.0)
	_page.hide()
	score_cue.emit(phase)
	finished.emit()

func _render() -> void:
	# Keep the live world and its single sun in place. Opaque paintings can spare
	# the renderer the valley geometry until the dissolve back to the beacon.
	var covered := elapsed >= TIMES[1] and elapsed < TIMES[4] - DISSOLVE
	var mask := 0 if covered else _normal_mask
	if _director.camera.cull_mask != mask:
		_director.camera.cull_mask = mask
	for i in _plates.size():
		var plate := _plates[i]
		var starts: float = TIMES[i + 1]
		var ends: float = TIMES[i + 2]
		plate.visible = elapsed >= starts - DISSOLVE and elapsed < ends
		if plate.visible:
			var mix_in := smoothstep(starts - DISSOLVE, starts, elapsed)
			# Later paintings cover earlier ones. The last dissolves to the 3D valley.
			if i == _plates.size() - 1:
				mix_in *= 1.0 - smoothstep(ends - DISSOLVE, ends, elapsed)
			plate.modulate.a = mix_in
			var age := clampf((elapsed - starts + DISSOLVE) / (ends - starts + DISSOLVE), 0.0, 1.0)
			(plate.material as ShaderMaterial).set_shader_parameter(&"progress", age)
	if elapsed < TIMES[1]:
		_handoff()
	else:
		_wide(smoothstep(TIMES[4], TIMES[5], elapsed))

func _handoff() -> void:
	var actor := _beacon.to_local(_traveler.global_position)
	var midpoint := actor * .36 + Vector3(0, 1.16, -.32)
	var outward := actor.slide(Vector3.UP).normalized()
	if outward.length_squared() < .25:
		outward = Vector3.BACK
	var shoulder := Vector3(outward.z, 0, -outward.x)
	var eye := _beacon.to_global(midpoint + outward * 4.65 + shoulder * 2.8 + Vector3.UP * 1.38)
	var target := _beacon.to_global(midpoint)
	if _still:
		_director.frame_ending(eye, target, 43.5)
		return
	var near_pose := Transform3D(Basis.IDENTITY, eye).looking_at(target)
	var blend := smoothstep(0.0, 1.05, elapsed)
	var pose := _opening_pose.interpolate_with(near_pose, blend)
	var focus := pose.origin - pose.basis.z
	_director.frame_ending(pose.origin, focus, lerpf(_opening_lens, 43.5, blend))

func _wide(travel: float) -> void:
	var t := 1.0 if _still else travel
	var eye := _beacon.to_global(Vector3(1.7, 2.68, -7.85).lerp(Vector3(1.95, 2.9, -8.8), t))
	var focus := _beacon.to_global(Vector3(.87, 1.67, 1.24))
	_director.frame_ending(eye, focus, lerpf(46.0, 47.0, t))

func _block_traveler() -> void:
	if _blocked:
		return
	_blocked = true
	var mark := _beacon.to_global(Vector3(3.05, .08, -2.05))
	var query := PhysicsRayQueryParameters3D.create(mark + Vector3.UP, mark - Vector3.UP * 1.5, 1)
	var hit := _beacon.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < .72 or absf(hit.position.y - mark.y) > .55:
		return
	_traveler.global_position = hit.position + Vector3.UP * .035
	_traveler.reset_physics_interpolation()
	if _traveler is CinderPlayer:
		var player := _traveler as CinderPlayer
		player.clear_swing()
		player.velocity = Vector3.ZERO
		player.recovery_point = player.global_position
		if player.visual:
			player.visual.look_at(player.visual.global_position + _beacon.global_basis.z, Vector3.UP)
