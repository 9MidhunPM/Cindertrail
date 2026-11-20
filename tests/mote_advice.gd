extends SceneTree

const GUIDE := preload("res://scripts/companion/mote_guide.gd")
const RESPONSES := preload("res://scripts/companion/mote_responses.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var guide := GUIDE.new()
	root.add_child(guide)
	var state := {"mode": "Explore", "objective": "Unfold the shrine at Flooded Grove",
		"objective_distance": 82.0, "restoration": 32.5, "health": 75.0}
	_check("I'm Mote" in guide.observe(state, 0.0), "Mote introduces itself on the trail")
	_check(guide.observe(state, 1.0).is_empty(), "Mote does not chatter every update")
	_check("68% more" in guide.observe(state, 18.0), "Travel reminder states what is left")
	_check(guide.observe(state, 18.0).is_empty(), "Unchanged progress does not repeat")
	state.objective_distance = 4.0
	_check("stone marker" in guide.observe(state, 0.25), "Approaching a shrine gives an interaction cue")
	state.merge({"mode": "Prepare", "site": "Flooded Grove", "energy": 14.0}, true)
	_check("sockets" in guide.observe(state, 5.0), "Deployed shrine advice explains setup")
	state.merge({"mode": "Defend", "health": 24.0, "wave_active": true}, true)
	_check("repair" in guide.observe(state, 2.0), "Critical core health cuts in with repair advice")
	state.merge({"mode": "Prepare", "energy": 0.0, "health": 58.0}, true)
	_check("fold" in guide.observe(state, 5.0), "A spent camp sends the traveler back to the trail")
	state.merge({"mode": "Transit", "pursuers": 2}, true)
	_check("followed us out" in guide.observe(state, 5.0), "Pursuit receives its own cue")
	state.merge({"mode": "Defend", "at_summit": true, "guardian_state": {"phase": "BRACE"},
		"guardian_action": "Move to the gold shoulder"}, true)
	_check(guide.observe(state, 2.0) == state.guardian_action, "Vesper advice uses the current cue")
	state.guardian_action = "Land one more spark"
	_check(guide.observe(state, 2.0) == state.guardian_action, "Advice changes within a counter window")
	state.merge({"mode": "Prepare", "guardian_cleared": true}, true)
	_check("cradle" in guide.observe(state, 5.0), "The delivery cue follows Vesper's defeat")

	var replies := PackedStringArray()
	guide.answered.connect(func(line: String) -> void: replies.append(line))
	guide.ask("How do I heal?", state)
	_check(replies.size() == 1 and "58% health" in replies[0] and not guide.is_busy(), "An offline ask returns immediately")
	if not guide.online_available():
		guide.ask("What is left?", state, true)
		_check(replies.size() == 2 and not guide.is_busy(), "A missing key falls back to offline advice")

	state["objective_point"] = Vector3(1.0, 2.0, 3.0)
	state["internal"] = "not part of the dialogue contract"
	var body: Dictionary = JSON.parse_string(RESPONSES.body("Where now?", state, "Follow the compass."))
	var input: Dictionary = JSON.parse_string(body.input)
	_check(body.model == "gpt-6-luna" and not body.store and not body.has("tools"), "Online mode uses Luna without enabled tools or stored response")
	_check(not input.game_state.has("objective_point") and not input.game_state.has("internal"), "Only allowlisted context crosses the network")
	var ambient_body: Dictionary = JSON.parse_string(RESPONSES.body("", state, "Watch the beacon.",
		"The guardian just fell.", "We are nearly there."))
	var ambient_input: Dictionary = JSON.parse_string(ambient_body.input)
	_check(ambient_input.has("trail_chatter") and ambient_input.has("last_chatter") and not ambient_input.has("question"),
		"Automatic dialogue sends the journey change and previous chatter")
	var response := {"status": "completed", "output": [
		{"type": "reasoning", "summary": [{"type": "summary_text", "text": "Hidden reasoning"}]},
		{"type": "message", "role": "assistant", "content": [
			{"type": "output_text", "text": "Follow\n the compass."},
		]},
	]}
	_check(RESPONSES.answer(JSON.stringify(response).to_utf8_buffer()) == "Follow the compass.", "Only the assistant's visible text is displayed")
	response.status = "incomplete"
	_check(RESPONSES.answer(JSON.stringify(response).to_utf8_buffer()).is_empty(), "Incomplete responses fall back to local advice")
	guide.free()
	print("Mote guide: %d/%d passed" % [_checks - _failures, _checks])
	quit(int(_failures > 0))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
