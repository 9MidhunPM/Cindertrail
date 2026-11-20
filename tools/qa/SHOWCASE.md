# Cindertrail showcase

Run `tools/showcase.sh` from the checkout. One Godot window plays the illustrated prologue, walks a seeded valley, defends four roaming shrines, fights Vesper, and delivers the same sun for the full sunrise finale. A new journey starts after the ending. Press **Escape** to exit or pass `--once` to stop after one run.

The showcase uses the normal player movement actions and the gameplay APIs behind deploying, building, striking, casting earned shrine arts, and packing. Spoken narration and animated chapter cards introduce the start, shrines, guardian, and ending. Use `--silent-voice` for captions and game audio. Voice recordings are bundled and play offline.

The launcher uses temporary Godot data and configuration folders so the showcase stays separate from your normal game. Results land in `evidence/showcase/showcase.json`. Pass `--out=DIR` to change the report folder.

```bash
tools/showcase.sh --once
tools/showcase.sh --smoke --cycles=2 --out=/tmp/cindertrail-showcase-report
```

The headless smoke run quickly advances the prologue, then simulates the entire route and finale. The report records the visited shrines, successful shrine art casts, and whether the full finale completed. In a fresh checkout, import Godot assets once before running the script.
