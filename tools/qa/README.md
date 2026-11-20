# Runtime verification

Run these commands from the Cindertrail project root after importing the assets with `godot --headless --editor --import`.

## Captures and profile

```bash
godot --script tools/qa/runtime.gd -- --case=grove --out="$PWD/evidence/grove"
```

The capture runner loads the main game into a fixed 1920×1080 viewport. It walks the explorer along the causeway using the movement actions, deploys the core, holds the pack action and walks out again. It profiles quiet exploration before taking the first capture. The renderer, graphics device, resolution, draw calls and enemy count are written to the JSON report. Frame time measures elapsed wall time between rendered frames, including vsync where enabled.

Use `--case=render-tour` to capture all four locations and profile a late Relay wave. The render tour preloads restoration and threat at Relay and full restoration at the beacon. The complete-route checks below earn all restoration through actual waves.

To record the camera transition, use a fresh output directory, add `--fixed-fps 60` before Godot's `--` separator and append `--record-transition` after it. Encode the recorded frames at 30 fps.

```bash
ffmpeg -framerate 30 -i evidence/clip/transition_frames/%04d.jpg -c:v libx264 -pix_fmt yuv420p evidence/clip/deploy-and-retreat.mp4
python tools/qa/compare.py evidence/grove-baseline evidence/runtime evidence/grove-comparison.png
```

## Gameplay checks

```bash
for test_case in relocation terrain defeat three-sites grove-relay; do
    godot --headless --fixed-fps 60 --script tools/qa/runtime.gd -- \
        --case="$test_case" --out="$PWD/evidence/checks"
done
```

Headless checks exercise the production state machine, combat and physics. The runner sends movement and packing actions through Input. It calls the same gameplay APIs the controls use to activate interactions, purchases and waves. Both routes traverse the full distances at the same speeds as normal play. Use the windowed `--case=input` to repeat the camera orbit, Escape, deploy, tower placement and pack checks through the viewport's input path.
