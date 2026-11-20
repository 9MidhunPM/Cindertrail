class_name CinderJourneyLayout
extends RefCounted
## A save stores its placements explicitly so changes to seed generation cannot move a journey.

const VERSION := 2
const LEGACY_SEED := 34519
const CAMPS := [&"flooded_grove", &"broken_quarry", &"fallen_relay", &"lanternwood",
	&"sunken_aqueduct", &"sunwatch_observatory", &"last_lantern_frontier"]
const FORKS := [&"pilgrims_cross", &"orchard_pass", &"mineral_spring"]
const TOWNS := [&"western_arcade", &"bellmakers_steps", &"mineral_ward"]

var journey_seed: int
var version := 0
var layout_id := 0
var clearings: Dictionary = {}
var fork_variants: Dictionary = {}
var town_variants: Dictionary = {}

static func generate(seed_value: int, requested_version: int = VERSION) -> CinderJourneyLayout:
	var layout := CinderJourneyLayout.new()
	layout.journey_seed = seed_value
	layout.version = requested_version
	if requested_version == 0:
		return layout
	layout.layout_id = CinderDistricts.layout_for_seed(seed_value)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ 0x76d31a
	for camp in CAMPS:
		layout.clearings[camp] = random.randi_range(0, 1)
	if requested_version >= 2:
		for fork in FORKS:
			layout.fork_variants[fork] = random.randi_range(0, 1)
		for town in TOWNS:
			layout.town_variants[town] = random.randi_range(0, 1)
	return layout

static func restore(record: Dictionary) -> CinderJourneyLayout:
	var layout := CinderJourneyLayout.new()
	layout.journey_seed = int(record.get("journey_seed", LEGACY_SEED))
	layout.version = int(record.get("world_layout_version", 0))
	if layout.version == 0:
		return layout
	if layout.version < 1 or layout.version > VERSION:
		return null
	layout.layout_id = int(record.get("world_layout_id", -1))
	if layout.layout_id < 1 or layout.layout_id > 3:
		return null
	if not _restore_choices(record.get("clearing_variants"), CAMPS, layout.clearings):
		return null
	if layout.version >= 2:
		if not _restore_choices(record.get("fork_variants"), FORKS, layout.fork_variants):
			return null
		if not _restore_choices(record.get("town_variants"), TOWNS, layout.town_variants):
			return null
	return layout

static func _restore_choices(source: Variant, ids: Array, target: Dictionary) -> bool:
	if not source is Dictionary:
		return false
	for id in ids:
		var choice: Variant = source.get(id)
		if not choice is int or choice < 0 or choice > 1:
			return false
		target[id] = choice
	return true

func clearing(camp: StringName) -> int:
	return int(clearings.get(camp, 0))

func matches_selection(previous_record: Dictionary) -> bool:
	var previous := restore(previous_record)
	return previous != null and version == previous.version and layout_id == previous.layout_id \
		and clearings == previous.clearings and fork_variants == previous.fork_variants \
		and town_variants == previous.town_variants

func checkpoint_fields() -> Dictionary:
	var record := {"journey_seed": journey_seed, "world_layout_version": version,
		"world_layout_id": layout_id, "clearing_variants": clearings.duplicate()}
	if version >= 2:
		record["fork_variants"] = fork_variants.duplicate()
		record["town_variants"] = town_variants.duplicate()
	return record
