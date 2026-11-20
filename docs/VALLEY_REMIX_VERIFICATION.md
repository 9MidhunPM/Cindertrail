# Valley remix and Sunsteel verification

## New Journey

New Journey selects one of three baked valley layouts, one of two authored shrine clearings at each extraction camp, and the two seeded trails into Last Lantern. The six main camps keep their site identities, but the Quarry, Relay and three outer camps shift across the map. The Grove remains the opening district and Last Lantern uses the same frontier entrance. The beacon moves with Fallen Relay.

Continue and Retry use the saved terrain ID, clearing choices and seed. Older saves use the original landscape and their original frontier seed. Camp reserves, threat, opened shortcuts and claimed caches retain their existing checkpoint behavior.

Tap **F** or **left click** to chain three cuts. The traveler turns toward the closest unobstructed enemy within 4.2 m. Each cut checks its own reach at contact. Hold for 0.65 s until the blade flashes and chimes, then release to spin. The release aim supplies the direction when there is no nearby enemy. A selected tower takes priority on left click.

## Native captures

- [Two generated valley maps](images/seeded-valleys.jpg)
- [Grove concept and gameplay comparison](images/grove-remix-comparison.jpg)

Local capture `evidence/swordplay/grove-swordplay.mp4` shows the combo and spin in exploration and defense.

The native Grove keeps the arches, turquoise shallows, bronze core and cream causeways. The stills have stronger amber bloom and denser foliage, and mountains are more prominent in the exploration composition.

## Native performance

Godot 4.7.2 on Linux Wayland, Mobile Vulkan, Intel Core Ultra 7 255H with Intel Arc graphics, 1920 × 1080. The warmed comparison sampled 160 frames per scene with shadows on. The time between rendered frames includes vsync.

| Scene | Original valley mean / p95 | Seed 428 mean / p95 |
| --- | ---: | ---: |
| Grove approach | 38.71 / 73.90 ms | 17.27 / 21.61 ms |
| Fallen Relay, 14 staged enemies | 17.08 / 20.78 ms | 13.32 / 18.33 ms |

The original valley ran first. Host timing varied, especially during the first Grove sample, so these results describe the measured scenes. A separate live wave capture overlapped another GPU workload and recorded higher frame times.

## Repeatable checks

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 --script tests/melee_smoke.gd
godot --headless --fixed-fps 60 --script tests/generated_journey.gd
for layout in 1 2 3; do
    godot --headless --fixed-fps 60 --script tests/outer_valley_walk.gd -- --layout="$layout"
done
XDG_DATA_HOME="$(mktemp -d)" CINDERTRAIL_TEST_SAVE=1 godot --headless --fixed-fps 60 \
    --script tests/journey_front_smoke.gd
godot --headless --fixed-fps 60 --script tools/qa/runtime.gd -- \
    --case=campaign-south --seed=80 --out="$PWD/evidence/remix/campaign"
godot --script tools/qa/remix_capture.gd -- \
    --seed=428 --compare --out="$PWD/evidence/remix/428"
```

Gameplay input tests cover auto-facing behind the traveler, occlusion, charged release aim, one hit per spin target, and cancellation when the map opens. Generated journey checks verify 1,000 seeds and deploy, defend and pack at both variants of all seven shrines. Route checks walk the outer roads in both directions using the traveler controller and check the assemblies where they join the districts.

All 51 generated outer roads passed in both directions, covering 6.62 km of distinct road centerlines. The exported game's packed resources loaded all three layouts with seven extraction camps and 17 outer trails each.

The automated seed 80 campaign walked through Flooded Grove, Lanternwood, Sunken Aqueduct and Sunwatch Observatory in 12 minutes 12 seconds of game time. It defended and packed at each camp, defeated Vesper and delivered the original sun. The same automated tactics lost at Lanternwood on seed 0. Human balancing across seeds is still open.
