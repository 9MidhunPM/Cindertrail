# Roaming valley and adaptive score

## Play

Open the project in Godot 4.7.2 and press **F5**. **New Journey** uses the roaming layout. **Continue Journey** and **Retry** restore the saved map, site positions, reserves, and equipment. The compass leads to the current shrine positions and to the existing hilltop beacon.

The six score cues transition between travel, shrine fights, pursuit, and Vesper. The finale uses its existing synchronized score. **Settings** exposes **Master**, **Music**, **Effects**, and **Ambience**. [Track credits](../art/audio/score/README.md) · [Foley credits](../art/audio/foley/README.md)

## World and gameplay checks

| Check | Observed result |
| --- | --- |
| Random placement | 3,000 seeds exercised all seven shrine identities in all three geographic sectors of each base map. All seven picked a different parcel in the consecutive New Journey check. |
| Physical terrain | 54 entry and exit walks passed across 27 baked parcels. All 1,323 floor probes passed. |
| Combat and persistence | 21 live encounters checked working approach lanes, extraction, and packing. Title, Continue, and Retry passed 48 checks, including exact saved anchors and fixed geography for older journeys. |
| Exploration | Seven tested seeds contained at least 53 wayside features each. The traveler walked 24 side-cache approaches out and back. Continue preserved an already claimed cache. |
| Continuous run | The original seed 80 campaign took 42,518 physics frames to earn 100% restoration and deliver the original sun. After the raid changes, the showcase repeated the full route with both Sunwatch mirrors aligned and the recess cache recovered before the first defense. The older automated route lost that opening raid without those preparations. |
| Linux export | The built executable’s pack contains all six score cues and 50 foley and ambience assets. A version 3 scene started seven unique shrine sites, the exploration score, and both positional ambience beds. |

## Visual comparison

The materials keep the stylized cream stone and blue-green moonlight, with new limestone grain, damp surfaces, plaster, timber, and moss detail. Seeded roadside ruins, workshops, foliage, and caches break up the open shoulders. The roaming Grove defense uses shallow pools, pale ruins, and warm details around the dry ring. The canonical stills still have denser canopy silhouettes and brighter reflected amber light.

[Matched material and wayside views](images/wayside-material-comparison.webp) · [Grove terrain, pools and ruins](images/roaming-grove-comparison.webp)

## Native audio and frame time

The 104-second 1080p gameplay capture includes the actual stereo master mix. All five chapters have audible sound and the recording peaked at −5.31 dBFS. The capture reaches the 100% sunrise results before a late scene reload invalidates the recorder’s original final assertion. The corrected recorder passes in rehearsal, and the continuous test verifies delivery of the original core.

All six final score files measured within 0.1 LU of −18 LUFS. The decoded loop edges pass the sample-step check. The separate 13-second wayside tour records all three cache pickups through the production interaction.

Godot 4.7.2 Mobile Vulkan on Linux Wayland, Intel Arc, 1920 × 1080. Each shadowed comparison uses 160 frames.

| Scene | Version 2 p95 | Version 3 p95 |
| --- | ---: | ---: |
| Grove opening | 58.43 ms | 30.96 ms |
| Relay with 14 staged enemies | 20.15 ms | 9.50 ms |

The versions ran sequentially and host timing varied. The measured version 3 Grove opening exceeds the 16.67 ms frame budget for 60 fps.

## Repeat

```sh
export OPENAI_API_KEY='' CINDERTRAIL_GUIDE_ONLINE=0
godot --headless --fixed-fps 60 --script tests/roaming_shrines.gd
godot --headless --fixed-fps 60 --script tests/shrine_parcel_walk.gd
godot --headless --fixed-fps 60 --script tests/wayside_walk.gd
XDG_DATA_HOME="$(mktemp -d)" CINDERTRAIL_TEST_SAVE=1 \
    godot --headless --script tests/adaptive_audio.gd
tools/showcase.sh --smoke --once --out="$PWD/evidence/roaming-shrines"
```

The capture guide describes how to repeat the continuous campaign and record the score showcase. [QA guide](../tools/qa/README.md)
