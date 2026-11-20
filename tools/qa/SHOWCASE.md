# Cindertrail showcase

Run `tools/showcase.sh` from the checkout. One Godot window plays the illustrated prologue, walks a seeded valley, defends four roaming shrines, fights Vesper, and delivers the same sun for the full sunrise finale. A new journey starts after the ending. Press **Escape** to exit or pass `--once` to stop after one run.

The showcase uses the normal player movement actions and the gameplay APIs behind deploying, building, striking, casting earned shrine arts, and packing. Narration appears in animated chapter cards. If `espeak-ng` or `espeak` is installed, the launcher prepares spoken versions locally. Use `--silent-voice` for captions and game audio.

The launcher uses temporary Godot data and configuration folders so the showcase stays separate from your normal game. Results land in `evidence/showcase/showcase.json`. Pass `--out=DIR` to change the report folder.

```bash
tools/showcase.sh --once
tools/showcase.sh --smoke --cycles=2 --out=/tmp/cindertrail-showcase-report
```

The headless smoke run quickly advances the prologue, then simulates the entire route and finale. The report records the visited shrines, successful shrine art casts, and whether the full finale completed. In a fresh checkout, import Godot assets once before running the script.
