extends RefCounted
## Each page pairs its own illustration with editable, accessible narration.

const PAGES_PER_CHAPTER := 4
const CHAPTERS := ["The Valley", "The Night", "The Vow"]
const PAGES := [
	{
		"title": "The age of roads",
		"image": "res://art/comic/reckoning/01_age_of_roads.webp",
		"caption": "When every morning still came, bells carried the hour from town to town. Quarry wagons took the high road. Millers followed the water. The crown above them caught the first light and sent it down bronze lines buried under the old paving.",
	},
	{
		"title": "The seven shrines",
		"image": "res://art/comic/reckoning/02_seven_shrines.webp",
		"caption": "Seven shrines held the light in reserve. Keepers opened their rings at dusk to warm gardens, guide the river locks and show travelers a safe road. Each reservoir bore a different seal. Only the beacon at the summit could gather all their light and give it back to the sky.",
	},
	{
		"title": "The morning that failed",
		"image": "res://art/comic/reckoning/03_failed_dawn.webp",
		"caption": "First the mornings paled. Then one never came. The keepers drew on all seven reserves together, hoping the Relay could bring the dawn back. Its stone housing split before the current reached the crown. The reservoirs fell silent. From that night on, only the moon lit the sky.",
	},
	{
		"title": "The last crane",
		"image": "res://art/comic/reckoning/04_quarry.webp",
		"caption": "The masons tried to raise a new Relay housing from the Quarry. They cut the stone by lantern light and worked the last crane until its counterweight jammed. The repair lay on the ledge where it fell. The keepers left the broken Relay’s bronze arms aimed at the summit.",
	},
	{
		"title": "The bell under water",
		"image": "res://art/comic/reckoning/05_flood.webp",
		"caption": "The lights that guided the sluice keepers went out. Water took the lower Aqueduct streets and flooded the Grove. The old toll bell sounded once as its roof slid beneath the pool. Herons made their nests among the arches. The high causeways still held.",
	},
	{
		"title": "The empty wards",
		"image": "res://art/comic/reckoning/06_empty_towns.webp",
		"caption": "The market at Western Arcade closed. The founders at Bellmakers’ Steps banked their last furnace. Mineral Ward left its cistern to the reeds. In the dark, fragments of stone began to move toward whatever light remained. Travelers hid supplies in the empty streets before leaving.",
	},
	{
		"title": "The keeper at the crown",
		"image": "res://art/comic/reckoning/07_vesper_oath.webp",
		"caption": "The crown’s keeper, Vesper, was built to guard the cradle. As the valley emptied, the keepers ordered it to bar the way until a restored light could survive its trial. Vesper kept that order after its makers were gone. On the summit it still waits for a light worth receiving.",
	},
	{
		"title": "The last keepers",
		"image": "res://art/comic/reckoning/08_last_keepers.webp",
		"caption": "Keepers at Sunwatch recorded how to read the mirrors. The last tenders of Lanternwood marked their paths with moth lamps. They met at Last Lantern and led the remaining people out. One wrapped a bronze cage in cloth and hid it under a fallen arch for a courier still to come.",
	},
	{
		"title": "The traveler’s vow",
		"image": "res://art/comic/01_valley.webp",
		"caption": "Years later, a traveler returned along those roads with the keepers’ account stitched into a cloak. Beneath a familiar arch they looked out on the valley and saw that the path to the crown still stood. They promised to carry whatever light remained all the way there.",
	},
	{
		"title": "The surviving sun",
		"image": "res://art/comic/02_discovery.webp",
		"caption": "The traveler lifted the cloth. Three tarnished rings held a single sun, small enough to cradle in two hands. Its light warmed the stone but barely reached the next arch. The old reservoirs could fill it again, if the traveler could keep its fragile flame alive.",
	},
	{
		"title": "A shrine you can carry",
		"image": "res://art/comic/03_harness.webp",
		"caption": "The frame folded onto the traveler’s harness. At a shrine it could unfold and draw from the reserve, while the old sockets powered portable defenses. Drawing light would call creatures out of the dark. If they overran the clearing, the traveler could fold the shrine and take the same sun onward.",
	},
	{
		"title": "The flooded road",
		"image": "res://art/comic/04_crossing.webp",
		"caption": "At the first causeway, the traveler heard water running over a stair that no longer led anywhere. A shrine waited beyond the arches. They tightened the harness and stepped onto the old road. Above the valley, the crown was dark. Soon there would be a light on that hill.",
	},
]
