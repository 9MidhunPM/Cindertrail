# Cindertrail polish verification

## Playable milestones

- The Flooded Grove look pass was captured and compared with the corrected crossing and defense illustrations. The final geometry adds branching canopies, a nearer vine-covered limestone arch and a two-tier cascade. Turquoise water reflects the opaque scene. Quarry and Relay sit in hand-dressed cliff terrain, with a view down into the ravine from Relay.
- The traveler blends walk, jog, sprint and directional movement. Measured gait tests cover planted contact on level ground and six gestures. Deployment, retreat and delivery retained one core identity within each run. Native video shows the gait changes. Combat smoke passed after the enemy and tower motion changes.
- The outer valley adds 1,708.37 meters of distinct trail centerline across 14 trails. The real traveler walked all 28 directions, including the three seams to the original world. Both enemy types reached all seven new lanes. Both winches restored correctly after reload.
- New Journey, the four illustrated panels, replay, skip, settings and Continue were exercised through the title menu. The checkpoint test verified health, reserve, threat, claimed supplies and a level-two packed tower after defeat. The safe checkpoint survived a run that left it and began another defense.
- Two simulated full campaigns used ordinary movement, deploy, construction, combat and packing APIs. Grove → Lanternwood → Aqueduct → Observatory → Beacon took **34:18**. Grove → Quarry → Lanternwood → Observatory → Beacon took **34:57**. Both carried the same sun to delivery. A separate run tested retreat with four pursuers still alive. All 15 combinations of four sites reached the restoration threshold.

## Native frame times

Godot 4.7.2 Mobile, Vulkan, Wayland, Intel Core Ultra 7 255H with integrated Intel Arc (ARL). The 1920×1080 values measure wall time between rendered frames.

| Scene | Sample | Mean | p95 | Worst |
| --- | ---: | ---: | ---: | ---: |
| Grove exploration | 180 frames | 8.70 ms | 10.56 ms | 12.22 ms |
| Relay defense, up to 9 enemies | 240 frames | 10.21 ms | 13.62 ms | 17.55 ms |
| Pilgrims' Cross trail in motion | 210 frames | 8.33 ms | 8.77 ms | 8.90 ms |

The render tour, Grove reference comparison, menu and prologue captures, locomotion recording and six outer-valley camera views are available in the workspace’s generated `evidence/` folder. Use the [QA commands](../tools/qa/README.md) to regenerate the runtime reports.

## Remaining visual and playtest gaps

The canopy and outer-valley terrain still have a more angular silhouette and fewer layers than the concept paintings. Water reflections fade as their source leaves the camera. Clip audio and natural first-run difficulty still need human playtesting. The headless route timings include known navigation and scripted combat. The native samples cover the named scenes and their stated enemy counts.
