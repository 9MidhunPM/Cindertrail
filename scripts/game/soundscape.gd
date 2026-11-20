class_name CinderSoundscape
extends Node

var _effects: Dictionary = {}
var _ambient: AudioStreamPlayer
var _foot := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
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
		"slash": _sweep(0.17, 1900.0, 520.0, 0.55, 211),
		"slam": _sweep(0.42, 420.0, 70.0, 0.75, 223),
		"impact": _stream(0.11, [118.0, 176.0], 0.62, 227),
	}
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _ambience()
	_ambient.volume_db = -20
	add_child(_ambient)
	_ambient.play()

func _exit_tree() -> void:
	if _ambient != null:
		_ambient.stop()
		_ambient.stream = null

func cue(cue_name: String) -> void:
	if _effects.is_empty():
		return
	var sound: AudioStreamWAV = _effects.get(cue_name, _effects["build"])
	var effect := AudioStreamPlayer.new()
	effect.stream = sound
	effect.volume_db = -18.0 if cue_name.begins_with("footstep") else -11.0
	add_child(effect)
	effect.finished.connect(effect.queue_free)
	effect.play()

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
