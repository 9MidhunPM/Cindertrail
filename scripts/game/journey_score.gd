extends Node
## Two decks keep independently composed cues on their natural tempo.

const ROOT := "res://art/audio/score/"
const CUES := {
	&"exploration": ["exploration", "exploration_alt"],
	&"defense": ["defense", "defense_alt"],
	&"pursuit": ["pursuit"],
	&"vesper": ["vesper"],
}
const QUIET_DELAY := 4.0
const TRANSITION_TIME := 1.25
const SILENT_DB := -60.0

var current_cue: StringName = &""
var _library: Dictionary = {}
var _next_track: Dictionary = {}
var _decks: Array[AudioStreamPlayer] = []
var _active := 0
var _desired: StringName = &"exploration"
var _queued: StringName = &""
var _quiet_for := 0.0
var _beat_wait := 0.0
var _pressure := 0
var _preparing := false
var _stopped := false
var _transition: Tween

func _ready() -> void:
	for cue: StringName in CUES:
		var tracks: Array[AudioStreamOggVorbis] = []
		for base_name: String in CUES[cue]:
			var path := ROOT + base_name + ".ogg"
			if not ResourceLoader.exists(path):
				continue
			var track := load(path) as AudioStreamOggVorbis
			if track != null:
				track.loop = true
				tracks.append(track)
		if not tracks.is_empty():
			_library[cue] = tracks
			_next_track[cue] = 0
	for index in 2:
		var deck := AudioStreamPlayer.new()
		deck.name = "MusicDeck%d" % (index + 1)
		deck.bus = &"Music"
		add_child(deck)
		_decks.append(deck)
	if _library.is_empty():
		set_process(false)

func _exit_tree() -> void:
	if _transition != null:
		_transition.kill()
	for deck in _decks:
		if is_instance_valid(deck):
			deck.stop()
			deck.stream = null

static func choose_cue(defending: bool, pursued: bool, guardian_alive: bool) -> StringName:
	if guardian_alive:
		return &"vesper"
	if defending:
		return &"defense"
	if pursued:
		return &"pursuit"
	return &"exploration"

func update_context(preparing: bool, defending: bool, pursued: bool, guardian_alive: bool, pressure: int) -> void:
	var chosen := choose_cue(defending, pursued, guardian_alive)
	if chosen != _desired:
		_desired = chosen
		_quiet_for = 0.0
	_pressure = pressure
	_preparing = preparing

func stop_score() -> void:
	if _stopped:
		return
	_stopped = true
	set_process(false)
	if _transition != null:
		_transition.kill()
	_transition = create_tween().set_parallel().set_ignore_time_scale()
	for deck in _decks:
		_transition.tween_property(deck, "volume_db", SILENT_DB, .45)
		_transition.tween_callback(deck.stop).set_delay(.45)
	current_cue = &""

func _process(delta: float) -> void:
	var elapsed := delta / maxf(Engine.time_scale, .001)
	if _desired == &"exploration":
		_quiet_for += elapsed
	var requested := _desired if _library.has(_desired) else &"exploration"
	if _transition != null and _transition.is_running():
		return
	if current_cue.is_empty():
		_crossfade(requested, 0.0)
		return
	var playing := _decks[_active]
	var target_db := _chapter_gain(current_cue)
	playing.volume_db = move_toward(playing.volume_db, target_db, elapsed * 6.0)
	if requested != current_cue:
		if requested == &"exploration" and _quiet_for < QUIET_DELAY:
			return
		if _queued != requested:
			_queued = requested
			_beat_wait = _seconds_to_next_beat(playing)
		_beat_wait -= elapsed
		if _beat_wait <= 0.0:
			_crossfade(requested, TRANSITION_TIME)
		return
	_queued = &""
	# Change to an alternate arrangement once a complete cue has played.
	var alternatives: Array = _library[current_cue]
	if alternatives.size() > 1 and playing.stream.get_length() > TRANSITION_TIME * 3.0:
		var remaining := playing.stream.get_length() - playing.get_playback_position()
		if remaining <= TRANSITION_TIME + .1:
			_crossfade(current_cue, TRANSITION_TIME)

func _seconds_to_next_beat(deck: AudioStreamPlayer) -> float:
	var audio := deck.stream as AudioStreamOggVorbis
	if audio == null or audio.bpm <= 0.0:
		return 0.0
	var beat := 60.0 / audio.bpm
	var offset := fposmod(deck.get_playback_position(), beat)
	return beat - offset if offset > .035 else 0.0

func _chapter_gain(cue: StringName) -> float:
	if cue == &"defense" or cue == &"pursuit":
		return lerpf(-5.0, -3.0, clampf(float(_pressure) / 12.0, 0.0, 1.0))
	if cue == &"vesper":
		return -4.0
	return -7.0 if _preparing else -6.0

func _crossfade(cue: StringName, seconds: float) -> void:
	if not _library.has(cue):
		return
	var tracks: Array = _library[cue]
	var index: int = _next_track[cue]
	var prior := _decks[_active]
	_active = 1 - _active
	var incoming := _decks[_active]
	incoming.stop()
	incoming.stream = tracks[index]
	_next_track[cue] = (index + 1) % tracks.size()
	current_cue = cue
	_queued = &""
	var target_db := _chapter_gain(cue)
	if seconds <= 0.0:
		incoming.volume_db = target_db
		incoming.play()
		return
	var outgoing_gain := db_to_linear(prior.volume_db)
	var incoming_gain := db_to_linear(target_db)
	incoming.volume_db = SILENT_DB
	incoming.play()
	_transition = create_tween().set_ignore_time_scale()
	_transition.tween_method(_mix_fade.bind(prior, incoming, outgoing_gain, incoming_gain), 0.0, 1.0, seconds)
	_transition.tween_callback(prior.stop)

func _mix_fade(t: float, prior: AudioStreamPlayer, incoming: AudioStreamPlayer,
		outgoing_gain: float, incoming_gain: float) -> void:
	prior.volume_db = linear_to_db(maxf(.001, outgoing_gain * cos(t * PI * .5)))
	incoming.volume_db = linear_to_db(maxf(.001, incoming_gain * sin(t * PI * .5)))
