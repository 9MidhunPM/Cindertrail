# Opening illustrations

The four panels were generated together as one painted contact sheet with the built-in OpenAI image tool. The sheet was cropped at its quadrant boundaries and exported as WebP.

The brief follows the valley, traveler and Grove crossing concept boards. It calls for a faceless traveler in a ragged teal hood and cloak, a tarnished bronze harness, and one miniature sun in a cage of three orbital rings. The color direction is indigo and cobalt shadow, cream stone, turquoise water, orange leaves and warm gold from the sun. The four scenes are a dark valley seen through a weathered arch, the discovery of the sun on a plinth, the traveler fitting its harness, and the first steps onto the Flooded Grove causeway. The panels contain no baked captions.

The twelve-page prologue opens with the eight historical plates in `reckoning/`. The four original illustrations close the story as the traveler vows to return the light, finds the sun, folds its harness, and reaches the Grove. The chapter order and accessible narration live in [prologue_pages.gd](../../scripts/ui/prologue_pages.gd).

Run the prologue smoke test with an isolated user-data directory. For native stills, omit `--headless` and append `-- --out="$PWD/evidence/reckoning-prologue"`.

```sh
XDG_DATA_HOME="$(mktemp -d)" CINDERTRAIL_TEST_SAVE=1 godot --headless --script tests/prologue_smoke.gd
```
