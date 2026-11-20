class_name CinderSoundscape
extends Node

var _effects: Dictionary = {}
var _ambient: AudioStreamPlayer
var _foot := false
var _draw: AudioStreamPlayer
var _draw_time := 0.0
var _last_call: Dictionary[String, int] = {}
var _ending: AudioStreamPlayer
var _ending_fade: Tween
var _ending_mark := -1.0

const SUNRISE_SCORE := "res://art/audio/valley/last_sunrise.ogg"
const ENDING_MARKS := {&"handoff": 0.0, &"arch": 4.0, &"ford": 9.0,
		&"relay": 15.0, &"return": 21.0, &"settled": 26.0}

const CREATURE_CALLS := {
	"skimmer_wake": preload("res://art/audio/valley/skimmer_wake.wav"),
	"ram_stamp": preload("res://art/audio/valley/ram_stamp.wav"),
	"splinter_rattle": preload("res://art/audio/valley/splinter_rattle.wav"),
	"warden_chime": preload("res://art/audio/valley/warden_chime.wav"),
	"vesper_call": preload("res://art/audio/valley/vesper_call.wav"),
	"vesper_charge": preload("res://art/audio/valley/vesper_charge.wav"),
	"vesper_pulse": preload("res://art/audio/valley/vesper_pulse.wav"),
	"vesper_exposed": preload("res://art/audio/valley/vesper_exposed.wav"),
}

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_effects = {
		"footstep": _stream(0.15, [96.0, 171.0], 0.24, 700),
		"footstep_alt": _stream(0.12, [111.0, 245.0], 0.23, 1900),
		"deploy": _stream(0.68, [196.0, 293.7, 392.0], 0.04, 31),
		"pack": _stream(0.34, [174.6, 261.6], 0.05, 51),
		"build": _stream(0.25, [330.0, 494.0, 660.0], 0.16, 53),
		"attack": _stream(0.12, [135.0, 215.0], 0.42, 61),
		"hurt": _stream(0.19, [82.0, 149.0], 0.21, 71),
		"repair": _stream(0.26, [277.2, 415.3], 0.03, 71),
		"mortar": _stream(0.31, [87.3, 110.0], 0.43, 92),
		"wave": _stream(0.58, [98.0, 147.0], 0.06, 101),
		"collect": _stream(0.28, [440.0, 659.3, 880.0], 0.01, 121),
		"win": _stream(1.9, [196.0, 246.9, 293.7, 392.0], 0.012, 12),
		"blade_ready": _sweep(0.32, 750.0, 3200.0, 0.04, 217),
		"spin": _sweep(0.38, 2300.0, 420.0, 0.56, 219),
		"slash": _sweep(0.17, 1900.0, 520.0, 0.55, 211),
		"slam": _sweep(0.42, 420.0, 70.0, 0.75, 223),
		"impact": _stream(0.11, [118.0, 176.0], 0.62, 227),
	}
	_effects.merge(CREATURE_CALLS)
	_effects["belfry_submerged"] = _bell_tone(true)
	_effects["belfry_lifted"] = _bell_tone(false)
	var hum := preload("res://art/audio/valley/extraction.wav").duplicate() as AudioStreamWAV
	hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
	hum.loop_end = roundi(hum.get_length() * hum.mix_rate)
	_draw = AudioStreamPlayer.new()
	_draw.stream = hum
	_draw.volume_db = -60.0
	add_child(_draw)
	set_process(false)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _ambience()
	_ambient.volume_db = -20
	add_child(_ambient)
	_ambient.play()

func _exit_tree() -> void:
	if _ambient != null:
		_ambient.stop()
		_ambient.stream = null
	if _ending != null:
		_ending.stop()
		_ending.stream = null

func ending_cue(section: StringName) -> void:
	if _ambient == null or not ENDING_MARKS.has(section):
		return
	var mark: float = ENDING_MARKS[section]
	if is_equal_approx(mark, _ending_mark):
		return
	if section == &"settled":
		_ending_mark = mark
		if _ending == null:
			return
		if _ending_fade:
			_ending_fade.kill()
		_ending_fade = create_tween().set_parallel()
		_ending_fade.tween_property(_ending, "volume_db", -56.0, .24)
		_ending_fade.tween_callback(_ending.stop).set_delay(.24)
		_ending_fade.tween_property(_ambient, "volume_db", -20.0, .72)
		return
	if mark < _ending_mark and section != &"handoff":
		return
	if _ending == null:
		var score := load(SUNRISE_SCORE) as AudioStreamOggVorbis
		if score == null:
			return
		_ending = AudioStreamPlayer.new()
		_ending.name = "LastSunriseScore"
		_ending.stream = score
		add_child(_ending)
	if section == &"handoff" or not _ending.playing:
		if _ending_fade:
			_ending_fade.kill()
		_ending_fade = create_tween()
		_ending_fade.tween_property(_ambient, "volume_db", -33.0, .48)
		_draw.stop()
		_draw_time = 0.0
		set_process(false)
		_ending.volume_db = -5.0
		_ending.play(mark)
	elif absf(_ending.get_playback_position() - mark) > .65:
		# The following shot can jump ahead when the cinematic is fast-forwarded.
		_ending.seek(mark)
	_ending_mark = mark

func toll_bell(world_position: Vector3, submerged: bool) -> void:
	if _effects.is_empty():
		return
	var voice := AudioStreamPlayer3D.new()
	voice.name = "BelfryToll"
	voice.stream = _effects["belfry_submerged" if submerged else "belfry_lifted"]
	voice.volume_db = -10.0 if submerged else -7.0
	voice.unit_size = 12.0
	voice.max_distance = 50.0 if submerged else 65.0
	add_child(voice)
	voice.global_position = world_position
	voice.finished.connect(voice.queue_free)
	voice.play()

func _bell_tone(submerged: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	var count := int(stream.mix_rate * (2.5 if submerged else 3.6))
	var mix := PackedFloat32Array()
	mix.resize(count)
	# Hum, prime, slightly beating tierce, quint and nominal. Water damps
	# the upper partials and softens the clapper strike on the same bell.
	for partial: Vector3 in [Vector3(110, .27, 1.30), Vector3(221, .34, .98),
			Vector3(264, .17, .82), Vector3(266.1, .075, .69),
			Vector3(335, .15, .63), Vector3(446.5, .19, .44), Vector3(942, .12, .095)]:
		var decay := partial.z
		var gain := partial.y
		if submerged:
			decay *= .66
			gain *= lerpf(1.0, .075, smoothstep(150.0, 465.0, partial.x))
		var angle := TAU * partial.x * (.94 if submerged else 1.0) / stream.mix_rate
		var damping := exp(-1.0 / (stream.mix_rate * decay))
		var advance := 2.0 * damping * cos(angle)
		var feedback := damping * damping
		var previous := -gain * sin(angle) / damping
		var current := 0.0
		for i in count:
			mix[i] += current
			var next_value := advance * current - feedback * previous
			previous = current
			current = next_value
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var attack := stream.mix_rate * (.044 if submerged else .0045)
	for i in count:
		var envelope := smoothstep(0.0, attack, i) * smoothstep(0.0, 480.0, count - 1 - i)
		samples.encode_s16(i * 2, roundi(clampf(mix[i] * envelope, -1.0, 1.0) * 28500.0))
	stream.data = samples
	return stream

func cue(cue_name: String) -> void:
	if _effects.is_empty():
		return
	if CREATURE_CALLS.has(cue_name):
		var now := Time.get_ticks_msec()
		if now - _last_call.get(cue_name, -1000) < 160:
			return
		_last_call[cue_name] = now
	var sound: AudioStreamWAV = _effects.get(cue_name, _effects["build"])
	var effect := AudioStreamPlayer.new()
	effect.stream = sound
	effect.volume_db = -18.0 if cue_name.begins_with("footstep") else -11.0
	add_child(effect)
	effect.finished.connect(effect.queue_free)
	effect.play()

func hear_extraction() -> void:
	if _draw == null:
		return
	_draw_time = 0.12
	if not _draw.playing:
		_draw.volume_db = -48.0
		_draw.play()
	set_process(true)

func _process(delta: float) -> void:
	_draw_time = maxf(0.0, _draw_time - delta)
	var target_db := -16.0 if _draw_time > 0.0 else -60.0
	_draw.volume_db = move_toward(_draw.volume_db, target_db, delta * 120.0)
	if _draw.volume_db <= -59.0:
		_draw.stop()
		set_process(false)

func footfall(_running: bool) -> void:
	_foot = not _foot
	cue("footstep" if _foot else "footstep_alt")

func _stream(duration: float, tones: Array[float], grit: float, seed_value: int) -> AudioStreamWAV:
	var output := AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(int(duration * output.mix_rate) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in samples.size() / 2:
		var time := float(i) / output.mix_rate
		var signal_value := random.randf_range(-grit, grit)
		for j in tones.size():
			var fade := exp(-time * (2.6 + j) / duration)
			signal_value += sin(TAU * tones[j] * time) * 0.32 * fade / (1 + j)
		var envelope := smoothstep(0.0, 0.014, time) * (1.0 - smoothstep(0.01, duration, time))
		samples.encode_s16(i * 2, roundi(signal_value * envelope * 20030.0))
	output.data = samples
	return output

## Filtered noise whose pitch falls from start to end: a blade whoosh or a slam.
func _sweep(duration: float, start: float, end: float, grit: float, seed_value: int) -> AudioStreamWAV:
	var output := AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(int(duration * output.mix_rate) * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var low := 0.0
	var phase := 0.0
	for i in samples.size() / 2:
		var t := float(i) / output.mix_rate / duration
		var cutoff := lerpf(start, end, t)
		var alpha := clampf(TAU * cutoff / output.mix_rate, 0.0, 1.0)
		low += (random.randf_range(-1.0, 1.0) - low) * alpha
		phase += TAU * cutoff * 0.25 / output.mix_rate
		var value := low * grit * 3.0 + sin(phase) * 0.18 * (1.0 - t)
		var envelope := smoothstep(0.0, 0.08, t) * pow(1.0 - t, 1.6)
		samples.encode_s16(i * 2, roundi(clampf(value * envelope, -1.0, 1.0) * 22000.0))
	output.data = samples
	return output

func _ambience() -> AudioStreamWAV:
	var output := AudioStreamWAV.new()
	output.format = AudioStreamWAV.FORMAT_16_BITS
	output.mix_rate = 22050
	var length := output.mix_rate * 8
	var samples := PackedByteArray()
	samples.resize(length * 2)
	for i in length:
		var t := float(i) / output.mix_rate
		var breath := 0.5 + 0.5 * sin(TAU * t / 8.0)
		var drone := sin(TAU * 73.5 * t) * 0.08 + sin(TAU * 110.0 * t) * 0.033
		var wind := (sin(TAU * 9.25 * t) * sin(TAU * 13.875 * t)) * 0.024
		samples.encode_s16(i * 2, roundi((drone * breath + wind) * 25000.0))
	output.data = samples
	output.loop_mode = AudioStreamWAV.LOOP_FORWARD
	output.loop_end = length
	return output
