# Cindertrail implementation instructions

## Product intent

Build **CINDERTRAIL — Carry the Last Sunrise** from the accompanying references. The user prioritizes a product as close as practical to the concept art. Preserve the art direction while controlling scope. Do not silently replace the concept with a generic flat-colored arena or a conventional static tower-defense game.

## Read first

- `START_HERE.md`
- `docs/01_GAME_DESIGN.md`
- `docs/02_MVP_AND_ROADMAP.md`
- `docs/03_TECHNICAL_ARCHITECTURE.md`
- `docs/04_VISUAL_ACCEPTANCE.md`
- `docs/05_TEST_PLAN.md`
- Any supplied material/asset/tool documentation in `docs/`.
- The supplied model/material-kit instructions and validation status in `art/models/`, `art/materials/` and the asset-building tools.

Inspect the actual image files before implementing their appearance. Prioritize `art/concept/11_valley_exploration.png`, `14_grove_crossing.png`, `16_camera_transition.png`, `03_traveler_shrine_sheet.png`, `05_grove_defense.png` and the corrected `06_relay_defense.png`.

The corrected stills govern appearance. Use the included generated trailer for pacing and mechanic communication; its flatter/brighter rendering must not replace the stills' rich blue/teal-and-gold atmosphere.

## Binding design constraints

1. One continuous 3D world. Free third-person exploration changes smoothly into fixed-angle tactical defense at sites; packing restores exploration controls.
2. **Exactly one protected core.** Its carried, deployed and delivered forms are states of the same gameplay object. Deployed or delivered core means the backpack harness is empty.
3. Core health, restoration, supplies and module upgrades persist when relocating. Restoration is objective progress, not health.
4. Camps have finite energy. Extracted energy and local threat remain recorded after departure; redeploying does not reset them.
5. Three prototype sites: Broken Quarry, Flooded Grove and Fallen Relay. Their topology must create genuinely different defensive choices.
6. Towers occupy predefined sockets outside enemy routes. Use authored terrain and routes, without runtime terrain or navigation rebuilding.
7. Packed modules do not fire. New organized waves pause during travel; existing pursuers remain present within a controlled active-enemy budget.
8. Dawn at the hilltop beacon is the win condition. Core destruction is the loss condition.

## Visual requirements

- Preserve the teal hooded traveler, bronze folding shrine, three orbital rings and golden miniature sun.
- Use matte faceted geometry, cream stone, weathered bronze, orange foliage, cobalt/teal shadow and warm amber focal light.
- Use actual modular geometry for silhouettes, stone steps, arches, cranes and tree canopies. Texturing a box is not a substitute for the reference silhouettes.
- Show traversable foreground ground, depth layers and visible destinations during exploration. Defense must expose paths, sockets, core and retreat route together.
- Prefer controlled material gradients and subtle texture detail. Avoid introducing noisy photorealistic surfaces that fight the stylized art.
- Keep lighting and effects compatible with the selected renderer and installed engine version. Check the official renderer feature table rather than assuming that a feature is unsupported from older tutorials. Native and optional web appearance need separate validation.

## Work sequence and visual gates

**Gate A — look development:** create one grove approach and small clearing with the actual traveler/core silhouette, materials, lighting and exploration camera. Capture a clean screenshot and compare with the canonical reference. Correct palette, proportions and composition before expanding the world.

**Gate B — mode transition:** show that same clearing from exploration, deployment, defense and retreat cameras. Verify single-core continuity and reversible controls.

**Gate C — playable relocation:** defend one site, pack while under pressure, travel to a second site and redeploy while retaining progress. Verify terrain affects the encounter.

**Gate D — complete run:** add the third site, economy, difficulty, final beacon and defeat/restart flow. Profile the real build on the target hardware.

Proceed autonomously through these gates when the evidence supports it; do not turn each gate into a request for user permission. If a gate fails, fix it and report the actual limitation. Do not label a feature finished solely because source code exists.

## Implementation discipline

- Use GDScript with small focused scripts and typed exported parameters where useful. Avoid a generic framework, ECS, plugin collection or networking layer.
- Use `.tscn` scenes and `.tres` data for sites, waves, modules and materials. Keep tuning out of large hard-coded conditionals.
- Keep the native renderer choice explicit. Use a separate Compatibility/web profile only if web delivery is required; test it early.
- Preserve source references and asset licenses. Record downloaded/generated asset provenance. Never substitute a concept PNG for a real material map or 3D object.
- Keep imported source assets and Blender output reproducible. Do not ship absolute machine-specific paths or credentials.
- Test the main state transitions, economy, persistence, path reachability and victory/defeat. Use a few meaningful checks rather than tests that mirror implementation internals.
- Keep an honest implementation checklist: implemented/tested, implemented/unverified, planned, or placeholder. Record measured performance with the scene, resolution, renderer and device.

## Finish each milestone with

A runnable build or project, a representative screenshot, concise instructions, meaningful verification results and the remaining material limitations. Include the next visual/gameplay problem to solve. Preserve the user's emphasis on a beautiful finished small experience.
