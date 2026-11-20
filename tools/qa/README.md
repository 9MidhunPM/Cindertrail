# Runtime verification

Run these commands from the Cindertrail project root after importing the assets with `godot --headless --editor --import`.

For automated capture and gameplay checks, set `OPENAI_API_KEY=''` and `CINDERTRAIL_GUIDE_ONLINE=0` in the shell. The showcase launcher applies both settings itself.

## Captures and profile

```bash
godot --script tools/qa/runtime.gd -- --case=grove --out="$PWD/evidence/grove"
```

The capture runner loads the main game into a fixed 1920×1080 viewport. It walks the explorer along the causeway using the movement actions, deploys the core, holds the pack action and walks out again. It profiles quiet exploration before taking the first capture. The renderer, graphics device, resolution, draw calls and enemy count are written to the JSON report. Frame time measures elapsed wall time between rendered frames, including vsync where enabled.

Use `--case=render-tour` to capture the three original sites and sunrise, and profile a late Relay wave. Use `--case=outer-profile` for a sample while walking along the trail to Pilgrims' Cross. The render tour preloads restoration and threat at Relay and full restoration at the beacon. The complete-route checks below earn restoration through actual waves.

To record the camera transition, use a fresh output directory, add `--fixed-fps 60` before Godot's `--` separator and append `--record-transition` after it. Encode the recorded frames at 30 fps.

```bash
ffmpeg -framerate 30 -i evidence/clip/transition_frames/%04d.jpg -c:v libx264 -pix_fmt yuv420p evidence/clip/deploy-and-retreat.mp4
python tools/qa/compare.py evidence/grove-baseline evidence/runtime evidence/grove-comparison.png
```

## Gameplay checks

```bash
for test_case in relocation terrain defeat campaign-combinations campaign-west campaign-south; do
    godot --headless --fixed-fps 60 --script tools/qa/runtime.gd -- \
        --case="$test_case" --out="$PWD/evidence/checks"
done
```

Headless checks exercise the production state machine, combat and physics. The runner sends movement and packing actions through Input. It calls the same gameplay APIs the controls use to activate interactions, purchases and waves. Both routes traverse the full distances at the same speeds as normal play. The reported journey length measures game time during automated input. Use the windowed `--case=input` to repeat the camera orbit, Escape, deploy, tower placement and pack checks through the viewport's input path.

```bash
godot --headless --fixed-fps 60 --script tests/outer_valley_walk.gd
godot --headless --fixed-fps 60 --script tests/traveler_motion.gd
godot --headless --fixed-fps 60 --script tests/combat_smoke.gd
XDG_DATA_HOME="$(mktemp -d)" CINDERTRAIL_TEST_SAVE=1 godot --headless --fixed-fps 60 \
    --script tests/journey_front_smoke.gd
```

The roaming seed sweep tests placement and live encounters. The headless showcase aligns the Sunwatch mirrors, follows the route on foot, earns 100 restoration at four camps, and delivers the original sun after defeating Vesper.

```bash
godot --headless --fixed-fps 60 --script tests/roaming_shrines.gd
tools/showcase.sh --smoke --once --out="$PWD/evidence/roaming-shrines"
```

## Beacon ending

The finale smoke check runs a full 26-second presentation on the real summit, then exercises reduced motion, keyboard skip and immediate skip from a carried sun. The guardian check writes its late-game fixture into an isolated save and verifies Continue after interrupting the film.

```bash
godot --headless --fixed-fps 60 --script tests/beacon_finale_smoke.gd
XDG_DATA_HOME="$(mktemp -d)" CINDERTRAIL_TEST_SAVE=1 godot --headless --fixed-fps 60 \
    --script tests/guardian_smoke.gd
```

To capture the ending with its stereo score, start Godot on a graphical display. The runner stages a guardian-cleared summit, records delivery through the live game and saves one screenshot per shot. Its `FILM_BEGIN_FRAME` output marks the first frame of the 26-second sequence in the recording.

```bash
mkdir -p evidence/beacon-finale
godot --resolution 1280x720 --fixed-fps 24 --write-movie "$PWD/evidence/beacon-finale/sunrise.avi" \
    --script tests/beacon_finale_smoke.gd -- --film="$PWD/evidence/beacon-finale"
```

## Record the adaptive score

Godot Movie Maker captures the game mix directly. This runner records a seeded v3 opening, deployment, pressure during retreat, the guardian fight and the complete sunrise presentation. The filming setup positions the traveler at the Grove shrine and later at the summit with a fully restored core. The showcase earns that restoration on foot.

```sh
python3 tools/qa/record_score.py /tmp/score-verification
ffmpeg -i /tmp/score-verification/score-journey.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k /tmp/score-journey.mp4
ffmpeg -i /tmp/score-verification/score-journey.avi -vn -c:a pcm_s16le /tmp/score-mix.wav
```

The JSON report records movie-frame numbers when gameplay and music change chapters. Use `--rehearse` with headless fixed-FPS to check the staging. To measure both v2 and v3 with the same real-time cameras and viewport, use `godot --script tools/qa/score_journey.gd -- --compare --out=/tmp/score-profile`.

Record the three wayside footpaths and cache pickups with `python3 tools/qa/record_score.py /tmp/wayside-verification --wayside-tour`. The traveler walks each path, with a cut between road junctions. The tour records the regular exploration score and in-game effects.
