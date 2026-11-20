# Visual direction and acceptance

## Target

The deliverable should be recognizably close to the Cindertrail concept set in **composition, silhouette, color hierarchy, material treatment and atmosphere**. Generated illustrations contain artistic lighting and details that may not map exactly to a small real-time game. Reconstruct the visual language with actual playable geometry and measure the result, rather than promising pixel-identical rendering.

The corrected stills are authoritative for appearance. The attached generated concept trailer communicates sequence and pacing, but its flatter/brighter low-poly treatment should not override the richer still-art target.

## Canonical references

| Reference | Use it for |
| --- | --- |
| [01 Key art](../art/concept/01_key_art.png) | Global palette, landmark identity, warmth versus cold and journey mood. |
| [02 Valley](../art/concept/02_world_valley.png) | Connected geography and destinations, not an exact collision map. |
| [03 Traveler/shrine](../art/concept/03_traveler_shrine_sheet.png) | Character silhouette, folding core and restored rings. |
| [04 Quarry defense](../art/concept/04_quarry_defense.png) | Choke point, scale, tower readability and tactical composition. |
| [05 Grove defense](../art/concept/05_grove_defense.png) | Cool water, dry building islands and warm defended center. |
| [06 Relay defense](../art/concept/06_relay_defense.png) | Three approaches, generator identity and corrected empty player harness. |
| [07 Defenses](../art/concept/07_defense_modules.png) | Distinct module silhouettes and materials. |
| [08 Enemies](../art/concept/08_enemies.png) | Crawler/brute weight, scale and glowing-fissure vocabulary. |
| [09 Relocation](../art/concept/09_relocation_storyboard.png) | Pack, pursuit and redeployment narrative. |
| [10 Sunrise](../art/concept/10_sunrise_ending.png) | Corrected delivery state and dawn payoff. |
| [11 Valley exploration](../art/concept/11_valley_exploration.png) | Behind-the-traveler framing and reachable branching paths. |
| [12 Side path](../art/concept/12_side_path.png) | Optional discovery, foreground framing and architecture scale. |
| [13 Quarry approach](../art/concept/13_quarry_approach.png) | Traversable canyon, cranes and vertical depth. |
| [14 Grove crossing](../art/concept/14_grove_crossing.png) | First look-development target: character, water, ruins and empty camp. |
| [15 Relay ascent](../art/concept/15_relay_ascent.png) | Reachable stairs, exposed height and visible destination. |
| [16 Camera transition](../art/concept/16_camera_transition.png) | Same-world explore/deploy/defend/retreat continuity. |

## Non-negotiable visual identity

- A small faceless traveler in a short weathered teal hood/cloak, charcoal lower clothing and bronze harness.
- One portable sun: bronze cage, three folding legs, three orbital rings and an amber-gold center.
- Cream stone with broad broken forms; bronze mechanisms; orange foliage; deep blue/teal distance.
- Warm focal light around the carried/deployed core, with enemies readable against the ground.
- Intentional simple 3D forms with visible facets and restrained surface detail.

Initial approximate palette, to tune by side-by-side comparison rather than treat as sampled truth:

| Role | Starting color |
| --- | --- |
| Deep night/distance | `#102B49` |
| Teal foliage/cloak family | `#17656E` |
| Cream stone | `#D8CCAD` |
| Bronze/brass | `#A76D32` |
| Amber sun | `#FFB84D` |
| Orange leaves | `#C8752F` |
| Cyan slowing effect | `#48D6D1` |
| Brute fissures | `#A26BE0` |

## Material and geometry strategy

The look comes from the combination of geometry, materials and lighting. A texture pack alone cannot turn generic primitives into these scenes. Build modular arches, broken columns, steps, broad cliff faces and layered tree canopies. Use flat/controlled normals where facets should read and smoothing where it helps the character, brass rings and water.

Use a small family of palette/gradient materials and subtle stone, cloth and metal variation. Photorealistic scans can be useful as low-strength masks or references; raw high-frequency albedo/normal maps should not dominate the stylized scene. Keep color grading intentional and avoid baked black shadow painted into a surface that receives different real-time lighting.

Materials must be inspected in Godot after export. Blender node graphs, procedural textures and lighting do not automatically reproduce in exported game materials. Bake or recreate unsupported parts deliberately, then compare the actual engine render.

## Camera acceptance

**Explore:** full-body traveler in the lower portion of frame, ground immediately ahead, visible destination and depth layers. Free rotation must not routinely clip into walls or trees. A screenshot should communicate a place to walk into, not an isolated arena viewed from above.

**Defend:** fixed raised three-quarter view frames the shrine, sockets, all active approaches and a viable escape direction. Projectiles and effects support readability. Do not let foliage or ruin walls hide the core or enemies.

**Transition:** the geometry and landmarks remain the same. The camera eases between poses; the shrine unfolds/folds; the backpack harness empties/fills at the correct moment. Pointer capture and UI change only when the transition can safely accept input.

## Look-development acceptance checklist

Capture the running game at a documented resolution without debug overlays. Compare with the matching concept reference at similar framing.

1. Can the traveler/core be recognized from silhouette at gameplay size?
2. Does a clear warm focal area sit within a cool scene?
3. Are cream ruins, orange foliage and teal water/trees distinct without oversaturation?
4. Does the visible route physically exist and support traversal?
5. Do foreground framing, midground play space and distant landmarks give depth?
6. Are tower silhouettes and enemy types distinct at the defense camera distance?
7. Does the game remain readable when effects and multiple enemies are active?
8. Is there exactly one sun, in the correct carried/deployed/delivered state?
9. Does the chosen renderer reproduce the intended materials without missing textures or unsupported effects?
10. Is measured frame time acceptable on the target laptop in this scene?

Address camera and silhouette differences first, then palette/material values, lighting hierarchy, geometry density and effects. More particles are not a general solution to an incorrect composition.

## Honest presentation

Keep concept images and actual game captures clearly identified. A concept trailer is a reference for the planned experience, not gameplay footage. Demonstrate actual implemented visuals with fresh captures and retain a list of placeholders still awaiting replacement.
