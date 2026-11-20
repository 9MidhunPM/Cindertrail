class_name CinderJourneyLayout
extends RefCounted
## Persist the actual placements so a continued journey need never draw them again.

const VERSION := 1
const LEGACY_SEED := 34519
const CAMPS := [&"flooded_grove", &"broken_quarry", &"fallen_relay", &"lanternwood",
	&"sunken_aqueduct", &"sunwatch_observatory", &"last_lantern_frontier"]

var journey_seed: int
var version := 0
var layout_id := 0
var clearings: Dictionary = {}

static func generate(seed_value: int) -> CinderJourneyLayout:
	var layout := CinderJourneyLayout.new()
	layout.journey_seed = seed_value
	layout.version = VERSION
	layout.layout_id = CinderDistricts.layout_for_seed(seed_value)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ 0x76d31a
	for camp in CAMPS:
		layout.clearings[camp] = random.randi_range(0, 1)
	return layout

static func restore(record: Dictionary) -> CinderJourneyLayout:
	var layout := CinderJourneyLayout.new()
	layout.journey_seed = int(record.get("journey_seed", LEGACY_SEED))
	layout.version = int(record.get("world_layout_version", 0))
	if layout.version == 0:
		return layout
	if layout.version != VERSION:
		return null
	layout.layout_id = int(record.get("world_layout_id", -1))
	if layout.layout_id < 1 or layout.layout_id > 3 or not record.get("clearing_variants") is Dictionary:
		return null
	for camp in CAMPS:
		var variant: Variant = record.clearing_variants.get(camp)
		if not variant is int or variant < 0 or variant > 1:
			return null
		layout.clearings[camp] = variant
	return layout

func clearing(camp: StringName) -> int:
	return int(clearings.get(camp, 0))

func checkpoint_fields() -> Dictionary:
	return {"journey_seed": journey_seed, "world_layout_version": version,
		"world_layout_id": layout_id, "clearing_variants": clearings.duplicate()}
