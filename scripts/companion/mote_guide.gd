class_name CinderMoteGuide
extends Node
## Immediate gameplay cues are local. Opt-in dialogue uses the Responses API.

signal answered(text: String)
signal automatic_answered(text: String)

const RESPONSES := preload("res://scripts/companion/mote_responses.gd")
const VOICE := preload("res://scripts/companion/mote_voice.gd")
const MIN_GAP := 5.0
const BOSS_GAP := 2.0
const REMINDER_GAP := 18.0
const ONLINE_GAP := 16.0
const ONLINE_RETRY_DELAY := 44.0

var _request: HTTPRequest
var _voice: VOICE
var _configuration: Dictionary
var _fallback := ""
var _request_topic := ""
var _last_chatter := ""
var _since_online := ONLINE_GAP
var _elapsed := MIN_GAP
var _last_topic := ""
var _last_reminder := ""
var _last_line := ""
var _introduced := false


func _ready() -> void:
	_configuration = RESPONSES.configuration()


func observe(context: Dictionary, delta: float) -> String:
	_elapsed += maxf(delta, 0.0)
	_since_online += maxf(delta, 0.0)
	var mode := _mode(context)
	var topic := _topic(context)
	if not _request_topic.is_empty() and (topic != _request_topic or mode in ["win", "lose", "deploy", "pack"]):
		cancel()
	if mode in ["win", "lose", "deploy", "pack"] or _request != null:
		return ""
	var gap := BOSS_GAP if topic.begins_with("boss:") or topic == "danger" else MIN_GAP
	if _elapsed < gap:
		return ""
	if topic != _last_topic:
		_last_topic = topic
		_last_reminder = ""
		var line := advice(context)
		if not _introduced and mode == "explore" and topic.begins_with("explore:trail:"):
			_introduced = true
			line = "I'm Mote. " + line if not line.begins_with("I'm Mote.") else line
			# Say hello immediately and let Luna join in after the first reading window.
			return _spoken(line)
		return _suggest(context, topic, line, "We just reached a different stage of the journey.")
	if _elapsed < REMINDER_GAP:
		return ""
	var reminder := _reminder(context)
	var playing := bool(context.get("moving", false)) or (mode == "defend" and bool(context.get("wave_active", false)))
	if reminder == _last_reminder and not (playing and _can_generate(topic)):
		return ""
	_last_reminder = reminder
	return _suggest(context, topic, reminder, "Check in while we're making our way through the current objective.") if playing else _spoken(reminder)


func _suggest(context: Dictionary, topic: String, local_line: String, change: String) -> String:
	if _can_generate(topic):
		_since_online = 0.0
		_start_request(RESPONSES.body("", context, local_line, change, _last_chatter), local_line, topic)
		return ""
	return _spoken(local_line)


func _can_generate(topic: String) -> bool:
	return (_since_online >= ONLINE_GAP and online_available() and _configuration.get("automatic", false)
		and topic != "danger" and topic != "pursuit" and not topic.begins_with("boss:"))


func advice(context: Dictionary, question := "") -> String:
	var query := question.to_lower()
	var mode := _mode(context)
	var deployed := mode in ["prepare", "defend"]
	if "repair" in query or "heal" in query:
		if deployed:
			return "Get close to the deployed shrine and interact to spend scrap on repairs. The sun has %d%% health." % _percent(context, "health", 100.0)
		return "We can repair at a shrine. Deploy the sun, then interact beside it to spend scrap on repairs."
	if "ability" in query or "cooldown" in query or "shrine art" in query:
		var art := _label(context, "ability_name")
		if art.is_empty():
			return "Empty a camp of its energy to earn its shrine art. Each art has its own cooldown."
		var seconds := ceili(float(context.get("ability_cooldown", 0.0)))
		if seconds > 0:
			return "%s needs %d more seconds. You can switch to another unlocked art if it's ready." % [art, seconds]
		var description := _label(context, "ability_description")
		if not description.is_empty():
			return "%s is ready. %s" % [art, description]
		return "%s is ready. Aim where you want it to land and use your shrine art." % art
	if "tower" in query or "module" in query or "socket" in query:
		return "Build on the marked sockets. Slow enemies where paths meet, then put a bolt turret or mortar in range. Packed modules travel with us."
	if "restoration" in query or "what's left" in query or "what is left" in query or "progress" in query or "how much" in query:
		return _reminder(context)
	if "guardian" in query or "vesper" in query:
		if deployed and bool(context.get("at_summit", false)):
			return _situation(context)
		return "At the beacon, dodge Vesper's charges and watch for the gold shoulder. Strike it to stop the pulse and expose the chest."
	return _situation(context)


func ask(question: String, context: Dictionary, online := false) -> void:
	if is_busy():
		return
	if _request != null:
		cancel()
	var local_answer := advice(context, question)
	if not online or not online_available() or question.strip_edges().is_empty():
		answered.emit(_spoken(local_answer, true))
		return
	_start_request(RESPONSES.body(question, context, local_answer), local_answer)


func _start_request(body: String, local_answer: String, topic := "") -> void:
	_request = HTTPRequest.new()
	_request.name = "MoteResponses"
	_request.use_threads = true
	_request.timeout = 8.0
	_request.max_redirects = 0
	_request.body_size_limit = 65536
	add_child(_request)
	_request.request_completed.connect(_request_completed, CONNECT_ONE_SHOT)
	_fallback = local_answer
	_request_topic = topic
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + str(_configuration.key)])
	if _request.request(RESPONSES.URL, headers, HTTPClient.METHOD_POST, body) != OK:
		_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func is_busy() -> bool:
	return _request != null and _request_topic.is_empty()


func online_available() -> bool:
	return is_inside_tree() and not str(_configuration.get("key", "")).is_empty()


func cancel() -> void:
	_fallback = ""
	_request_topic = ""
	if _request != null:
		if _request.request_completed.is_connected(_request_completed):
			_request.request_completed.disconnect(_request_completed)
		_request.cancel_request()
		_request.queue_free()
		_request = null


func speak(line: String) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless" or not _configuration.get("voice", false):
		return
	if _voice == null:
		_voice = VOICE.new()
		_voice.enabled = true
		add_child(_voice)
	_voice.say(line)


func stop_voice() -> void:
	if _voice != null:
		_voice.stop()


func _request_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _request == null:
		return
	var automatic := not _request_topic.is_empty()
	var reply := RESPONSES.answer(body) if result == HTTPRequest.RESULT_SUCCESS and status == 200 else ""
	if reply.is_empty():
		_since_online = minf(_since_online, ONLINE_GAP - ONLINE_RETRY_DELAY)
	if reply.is_empty() or (automatic and reply == _last_chatter):
		reply = _fallback
	cancel()
	if automatic:
		var line := _spoken(reply)
		if not line.is_empty():
			_last_chatter = line
			automatic_answered.emit(line)
	else:
		answered.emit(_spoken(reply, true))


func _spoken(line: String, requested := false) -> String:
	if line.is_empty() or (not requested and line == _last_line):
		return ""
	_elapsed = 0.0
	_last_line = line
	return line


func _topic(context: Dictionary) -> String:
	var mode := _mode(context)
	if bool(context.get("at_summit", false)) and mode == "defend":
		var guardian: Variant = context.get("guardian_state", {})
		var phase := str(guardian.get("phase", "")) if guardian is Dictionary else str(guardian)
		return "boss:%s:%s" % [phase, _label(context, "guardian_action")]
	if mode in ["prepare", "defend"] and _percent(context, "health", 100.0) <= 30:
		return "danger"
	if mode in ["explore", "transit"]:
		if int(context.get("pursuers", 0)) > 0:
			return "pursuit"
		var distance := float(context.get("objective_distance", -1.0))
		var proximity := "near" if distance >= 0.0 and distance <= 5.5 else "trail"
		var landmark: Variant = context.get("landmark", {})
		if proximity == "trail" and landmark is Dictionary and not str(landmark.get("title", "")).is_empty():
			return "landmark:" + str(landmark.title)
		return "%s:%s:%s" % [mode, proximity, _label(context, "objective")]
	if mode == "prepare" and context.has("energy") and float(context.energy) <= 0.001 and not bool(context.get("at_summit", false)):
		return "spent:" + _label(context, "site")
	return "%s:%s:%s:%s" % [mode, _label(context, "site"), int(context.get("wave", context.get("threat", 0))), bool(context.get("wave_active", false))]


func _situation(context: Dictionary) -> String:
	var mode := _mode(context)
	var topic := _topic(context)
	var site := _label(context, "site")
	var objective := _label(context, "objective")
	if topic.begins_with("boss:"):
		var action := _label(context, "guardian_action")
		return action if not action.is_empty() else "Watch the gold shoulder. Break the pulse there, then hit the open chest."
	if topic == "danger":
		return "The sun can barely hold! Get close and repair it with scrap. If this camp is turning on us, pack and take the trail."
	if topic == "pursuit":
		return "Something followed us out. Keep moving and dash clear if it closes in. The next shrine can wait until we've made space."
	var landmark: Variant = context.get("landmark")
	var at_wave := mode == "defend" and bool(context.get("wave_active", false))
	if landmark is Dictionary and (topic.begins_with("landmark:") or at_wave):
		var detail := _label(landmark, "detail")
		if not detail.is_empty():
			return "%s. %s" % [_label(landmark, "title").trim_suffix("."), detail]
	if topic.begins_with("spent:"):
		return "This camp has given us all its light. Hold pack to fold the sun and take our modules with us."
	match mode:
		"prepare":
			if bool(context.get("at_summit", false)):
				if bool(context.get("guardian_cleared", false)):
					return "Vesper is down. Bring the sun to the beacon's cradle and interact. It's time to bring back the morning."
				return "This is Vesper's perch. Set your defenses, then challenge the guardian. We can light the beacon once it's down."
			if float(context.get("restoration", 0.0)) >= 99.999:
				return "The sun is full! We can finish drawing this camp for its art, or pack now and head to the beacon."
			return "Let's cover the approaches. Place modules on the sockets, then start the wave to draw light into the sun."
		"defend":
			if bool(context.get("wave_active", false)):
				return "They're coming! Watch the approach the towers can't reach. Keeping the shrine standing gives it time to draw energy."
			return "A breath between waves. Check the shrine, shore up the weakest approach, and watch for the next group."
		"deploy":
			return "The shrine's opening. Once it's down, we'll have sockets to place our defenses."
		"pack":
			return "Keep holding pack. We'll carry the sun's light and our modules to the next camp."
		"win":
			return "Look up, traveler. We brought the morning back."
		"lose":
			return "The sun went out. We can return to the last safe checkpoint if we made one."
	if objective.is_empty():
		return "I'm Mote. Follow the trail to a shrine so we can give the sun its light back."
	if objective == "Every camp is spent":
		return "We've drawn all the light the camps had. The beacon needs a fully restored sun."
	if float(context.get("restoration", 0.0)) >= 99.999:
		if bool(context.get("guardian_cleared", false)):
			return "The beacon is clear. Follow the compass to the cradle and deliver the sun."
		return "The sun is whole. Carry it to the Hilltop Beacon and unfold it there. Follow the compass to stay on the trail."
	if ":near:" in topic:
		return "We're close. %s. Step up to the stone marker and interact to unfold the sun." % objective.trim_suffix(".")
	if not site.is_empty() and mode == "transit":
		return "We've kept the light we earned. %s. I'll stay close." % objective.trim_suffix(".")
	return "%s. The compass will lead us along the trail." % objective.trim_suffix(".")


func _reminder(context: Dictionary) -> String:
	var restoration := _percent(context, "restoration")
	var mode := _mode(context)
	if mode == "defend" and bool(context.get("at_summit", false)):
		return _situation(context)
	if mode == "defend" and int(context.get("wave_left", 0)) > 0:
		return "This wave still has %d to get through. We're at %d%% restoration. Keep the shrine covered." % [int(context.wave_left), restoration]
	if restoration >= 100:
		return "Restoration is complete. %s" % _situation(context)
	return "The sun holds %d%% of its light. We need %d%% more. %s" % [restoration, 100 - restoration, _situation(context)]


func _mode(context: Dictionary) -> String:
	return str(context.get("mode", "explore")).to_lower()


func _label(context: Dictionary, key: String) -> String:
	return str(context.get(key, "")).strip_edges()


func _percent(context: Dictionary, key: String, fallback := 0.0) -> int:
	return floori(clampf(float(context.get(key, fallback)), 0.0, 100.0) + 0.0001)
