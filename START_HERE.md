# CINDERTRAIL — Carry the Last Sunrise

This is the design, visual-reference and asset-workflow starter pack for **Cindertrail**, an open-world exploration and nomadic tower-defense game. It is a production brief for building the game, not a claim that the illustrated game has already been implemented.

You carry one damaged miniature sun through a cold, ruined valley. Explore in third person, choose a defensive site, unfold the portable sun shrine, and defend while it absorbs restoration energy. When the position becomes unsafe or depleted, recall your defenses and leave. Keep your core, upgrades and progress. Restore the sun, reach the hilltop beacon, and bring back dawn.

## Start in this order

1. Open [AGENTS.md](AGENTS.md), then the [game design](docs/01_GAME_DESIGN.md).
2. Look at [the exploration view](art/concept/11_valley_exploration.png), [the grove crossing](art/concept/14_grove_crossing.png) and [the camera-mode board](art/concept/16_camera_transition.png).
3. Compare [the traveler and shrine](art/concept/03_traveler_shrine_sheet.png), [the defense modules](art/concept/07_defense_modules.png) and [the enemies](art/concept/08_enemies.png).
4. Read [the visual acceptance criteria](docs/04_VISUAL_ACCEPTANCE.md), [the architecture](docs/03_TECHNICAL_ARCHITECTURE.md) and [the roadmap](docs/02_MVP_AND_ROADMAP.md).
5. Give your coding agent [the starting prompt](prompts/START_CODEX.md). Read the material, asset and tool guidance elsewhere in `docs/` and inspect the supplied `art/models/`, `art/materials/` and asset-building tools before choosing additional dependencies. Read their actual validation status; a supplied starter asset is not automatically a finished production asset.

## The important design decision

**One fully 3D world, two camera/control modes.** Exploration uses a freely rotatable third-person camera. Deploying the shrine raises the camera into a fixed angled tactical view that gives the requested “2.5D” defense feel. Packing the shrine returns the camera behind the traveler. The world geometry, core and enemies remain continuous through the change.

## Recommended production target

- Godot 4 stable, GDScript, Linux desktop first.
- Native visual profile: begin with the **Mobile rendering method** for a restrained 3D scene. “Mobile” is the renderer name here, not a requirement to make a phone game.
- Optional web/fallback profile: **Compatibility** rendering, tested separately. Do not promise identical rendering or effects across profiles.
- First visual milestone: one small grove approach and defense clearing, using the actual camera, palette, modular shapes and core silhouette.
- First gameplay milestone: deploy → build → defend → pack → travel → redeploy at a second site.
- Complete jam target: one compact connected valley, three sites, three defenses, two enemy types and a sunrise ending.

## Reference priority

The numbered files in `art/concept/` are the intended visual references. If earlier alternatives are included in an archive folder, they are historical variants. For the relay and sunrise, use the corrected canonical references: a deployed/delivered sun is **not simultaneously present on the traveler's back**.

The corrected still concept art is the appearance authority. The included generated trailer is useful for pacing and the core-loop sequence; it is brighter/flatter than the stills and must not downgrade the game to a grey toy-like look. Concept images and video are not themselves 3D meshes, tileable material maps, animations or proof of measured game performance. The accompanying asset/material kit supplies a reproducible starting point; inspect its README and validation report before using it.

## What success looks like

The opening screen is recognizably Cindertrail: a teal-cloaked traveler with a warm bronze sun lantern, cream ruins and branching paths through a blue-green night valley. You can walk into that scene, make a route choice, deploy the same core, and see the camera transition into a readable defense encounter. A compact, polished slice of that experience is the first deliverable.
