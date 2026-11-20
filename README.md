# CINDERTRAIL — Carry the Last Sunrise

An open-world, portable-base tower-defense adventure. Explore a continuous 3D valley from a free third-person camera, deploy the one sun shrine at a chosen site, defend from a fixed angled camera, then pack and relocate before the position becomes untenable.

## Play

Extract the Linux x86_64 build and run `./Cindertrail.x86_64`. To run from source, open [project.godot](project.godot) in Godot 4.7.2 and press **F5**, or use the terminal commands below.

```sh
godot --headless --editor --path . --import
godot --path .
```

The title opens on the Flooded Grove. **New journey** starts the four-panel motion comic. **Continue journey** resumes at the last safe checkpoint. A checkpoint preserves your trail position, shrine health, restoration, scrap, modules, caches, unlocked shortcuts, remaining camp reserves and local threat. The game saves when you are carrying the shrine on safe ground after breaking pursuit.

The six camps share one continuous 3D world and all use the same protected sun. Each camp has 25 points of restoration. Defend four camps to exhaustion or combine partial reserves from several camps, then bring the restored sun to the hilltop beacon.

| Input | Action |
| --- | --- |
| **WASD**, mouse, **Shift**, **Ctrl** | Move, look, sprint and walk |
| **E** | Unfold at a pad, open a supply crate or shortcut, repair near the deployed shrine, or deliver the restored sun |
| **1 / 2 / 3**, left click | Select a module, then place it on an open socket |
| **Space** | Start the attack and begin extracting restoration |
| **U** | Upgrade the tower under the pointer |
| Left click while traveling, right click in defense | Fire the traveler's ranged attack |
| **Hold R** | Recall modules and fold the shrine near its pad |
| **Esc**, **Enter** | Pause or resume. Enter activates the focused menu action |
| **F10** | Toggle HUD visibility |

Use the in-world markers to choose your next camp. Reach 100% restoration, then carry the sun to the hilltop beacon. Repairs use scrap and restore shrine health.

See the [polish milestone report](docs/POLISH_VERIFICATION.md), [repeatable QA commands](tools/qa/README.md) and the original [visual fieldbook](OPEN_ME.html).

## Included

- `art/concept/`: all 16 canonical concept boards, given descriptive filenames.
- `art/archive/`: 2 earlier image variants retained for completeness; corrected canonical versions take precedence.
- `media/`: the user's original 30-second concept trailer and a quick six-frame contact sheet.
- `docs/`: design, MVP, architecture, art direction, acceptance checks, material pipeline, asset licensing, skills/MCP setup and trailer reference notes.
- `prompts/`: coding kickoff, art-production briefs and trailer prompt.
- `art/materials/`, `art/models/`, `scripts/`: actual starter assets and reproducible generation/import workflows. Read their status notes before assuming a resource is production-ready.
- `configs/`: example MCP configuration. Installing optional MCP servers is a separate action on your development machine.
- `PACKAGE_MANIFEST.json`: original starter-pack file sizes and SHA-256 hashes.

## Scope and visual standard

The corrected stills are the visual target. The included concept trailer is a pacing reference. The generated traveler, palette materials and refined starter meshes preserve the teal cloak, cream masonry, bronze shrine and blue-green night color family.

The [original starter guide](START_HERE.md) and the [numbered design documents](docs/) describe the intended game. The [starter validation](VALIDATION.md) records asset checks from packaging. Optional third-party maps retain their original provenance and licenses.
