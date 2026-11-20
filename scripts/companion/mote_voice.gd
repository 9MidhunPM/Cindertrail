class_name CinderMoteVoice
extends Node
## Plays the exact caption from a recorded line or the same local voice model.

signal playback_started(text: String, duration: float)
signal playback_finished(text: String)
signal playback_failed(text: String)

const LINES := "res://art/audio/mote/lines.json"
const SYNTHESIZER := "tools/mote_voice/synthesize.sh"
const TIMEOUT_SECONDS := 12.0
const CACHE_SIZE := 16
const MAX_AUDIO_BYTES := 1024 * 1024

var _player: AudioStreamPlayer
var _lines: Dictionary = {}
var _clips: Dictionary[String, AudioStream] = {}
var _speaking := ""
var _pending := ""
var _job := ""
var _worker := -1
var _deadline := 0


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINES)) if FileAccess.file_exists(LINES) else {}
	if parsed is Dictionary:
		_lines = parsed
	_player = AudioStreamPlayer.new()
	_player.name = "MoteSpeechPlayer"
	_player.bus = &"Effects"
	_player.volume_db = 2.0
	_player.finished.connect(_on_playback_finished)
	add_child(_player)
	set_process(false)


func speak(text: String) -> bool:
	stop()
	if not is_node_ready() or text.is_empty():
		return false
	if _clips.has(text):
		_play(text, _clips[text])
		return true
	var asset := str(_lines.get(text, ""))
	if not asset.is_empty() and ResourceLoader.exists(asset):
		var clip := load(asset) as AudioStream
		if clip != null:
			_play(text, clip)
			return true

	if not OS.has_feature("linux"):
		return false
	var base := OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("res://")
	var launcher := base.path_join(SYNTHESIZER)
	if not FileAccess.file_exists(launcher):
		return false

	_job = ProjectSettings.globalize_path("user://mote-speech/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(_job) != OK:
		_job = ""
		return false
	var input := _job.path_join("line.txt")
	var file := FileAccess.open(input, FileAccess.WRITE)
	if file == null:
		_clear_job()
		return false
	file.store_string(text)
	file.close()
	_worker = OS.create_process("/bin/bash", [launcher, input, _job.path_join("line.wav")])
	if _worker <= 0:
		_clear_job()
		return false
	_pending = text
	_deadline = Time.get_ticks_msec() + roundi(TIMEOUT_SECONDS * 1000)
	set_process(true)
	return true


func _process(_delta: float) -> void:
	var output := _job.path_join("line.wav")
	if FileAccess.file_exists(output):
		var file := FileAccess.open(output, FileAccess.READ)
		var clip: AudioStreamWAV
		if file != null and file.get_length() <= MAX_AUDIO_BYTES:
			clip = AudioStreamWAV.load_from_buffer(file.get_buffer(file.get_length()))
			file.close()
		var text := _pending
		_worker = -1
		_clear_job()
		if clip == null or clip.get_length() <= 0.0:
			playback_failed.emit(text)
			return
		if _clips.size() >= CACHE_SIZE:
			_clips.erase(_clips.keys()[0])
		_clips[text] = clip
		_play(text, clip)
	elif not OS.is_process_running(_worker) or Time.get_ticks_msec() >= _deadline:
		var text := _pending
		_clear_job()
		playback_failed.emit(text)


func _clear_job() -> void:
	set_process(false)
	if _worker > 0 and OS.is_process_running(_worker):
		OS.kill(_worker)
	_worker = -1
	_pending = ""
	if not _job.is_empty():
		var dir := DirAccess.open(_job)
		if dir != null:
			for name in dir.get_files():
				dir.remove(name)
			DirAccess.remove_absolute(_job)
		_job = ""


func stop() -> void:
	_clear_job()
	_speaking = ""
	if _player != null:
		_player.stop()
		_player.stream = null


func is_synthesizing() -> bool:
	return _worker > 0


func _play(text: String, clip: AudioStream) -> void:
	_speaking = text
	_player.stream = clip
	_player.play()
	playback_started.emit(text, clip.get_length())


func _on_playback_finished() -> void:
	var text := _speaking
	_speaking = ""
	_player.stream = null
	if not text.is_empty():
		playback_finished.emit(text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		stop()


func _exit_tree() -> void:
	stop()
