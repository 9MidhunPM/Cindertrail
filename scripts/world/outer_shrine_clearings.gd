extends RefCounted
## Authored lane mouths stay on the baked road beds. Inside the court each layout
## has its own approach bends, empty shrine footing, socket positions and view.
const CLEARINGS := preload("res://data/outer_valley/shrine_clearings.json")

static func resolve(definition: Dictionary, variant: int, randomized: bool) -> Dictionary:
	if not randomized:
		return definition
	var layouts: Array = CLEARINGS.data[definition.resource]
	return definition.merged(layouts[clampi(variant, 0, layouts.size() - 1)], true)
