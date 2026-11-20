# MVP and production roadmap

## Delivery approach

Prioritize a recognizable, playable visual slice before producing a large greybox world. The concept art is the appearance target; a twelve-hour jam limits content and system breadth, not the need for intentional materials, lighting, silhouettes and camera composition.

The milestones below are ordered gates, not promises that every stage will fit in twelve hours. The complete three-site version is ambitious for a first game. Time estimates should be updated after testing the first slice.

## Milestone A — visual proof

Build a small approach to the grove plus one dry clearing. Include the actual exploration camera, a recognizable teal traveler, a compact bronze sun shrine, cream ruins, a few modular trees, shallow stylized water and the intended night/amber lighting.

**Complete when:** a clean screenshot is recognizably close to `14_grove_crossing.png` in camera, focal hierarchy, silhouette, palette and depth. The player can walk the visible route without clipping or falling through it. Record the renderer and resolution used.

Internal blockouts are useful, but do not label this gate complete with a capsule and colored cubes. Improve the visible assets before expanding terrain.

## Milestone B — camera and core continuity

Implement Explore → Deploy → Prepare → Defend → Pack → Transit. The same 3D clearing appears in both camera modes. The core transitions between carried and deployed forms without duplicate suns. Controls and pointer capture change with the camera, then restore correctly on retreat.

**Complete when:** a short recording shows a reversible exploration/deployment/retreat transition and there is exactly one core damage target throughout.

## Milestone C — smallest playable relocation loop

Add a second camp connected by a short trail. Implement one turret, one crawler, core health, restoration, site depletion, one currency, packing, retained upgrades and existing-enemy pursuit. Use one authored approach at each camp first.

**Complete when:** a player can defend, decide to leave, recall the turret, travel with a pursuer and redeploy without resetting health, restoration, supplies or site energy.

## Milestone D — three-site game

Add quarry, grove and relay topology; four sockets per camp; all three modules; the brute; clear attack forecasts; repair economy; and the beacon ending. Different site advantages must change a sensible defense layout.

**Complete when:** a full run can win and lose; at least two viable route strategies exist; a player can leave any camp without getting stuck; and the single-core constraint holds through the ending.

## Milestone E — polish and packaging

Improve footsteps, turret feedback, core hum, packing animation, camera easing, hit readability, wave pacing, interaction cues, settings and startup instructions. Measure native performance on the target laptop. If a browser build is required, test its separately supported effects and input behavior.

**Complete when:** the delivered build runs from a fresh extraction, has no unresolved core-loop blocker, and includes an honest feature checklist and representative screenshots.

## Illustrative twelve-hour allocation

| Time budget | Focus | Result to protect |
| --- | --- | --- |
| First 2 hours | Versions, import/material workflow, small look-development clearing. | A convincing exploration screenshot and working movement. |
| Next 2 hours | Camera transitions, single-core state, one socket and turret. | Deploy/pack is reversible and visually coherent. |
| Next 3 hours | One enemy, defense pressure, second camp, persistence and travel. | The complete relocation loop. |
| Next 2 hours | Additional topology/modules/enemy, economy and ending. | A coherent short run, even if some planned content must shrink. |
| Final 3 hours | Visual fixes, sound, playtesting, performance, export and demo. | A stable, presentable build. |

If milestone A or C takes longer, reduce the number of finished sites or enemy variations before sacrificing the visual identity or the relocation loop. A two-site polished demo is a valid fallback; document the reduction honestly.

## Optional features after the MVP

- Sanctuary detour and richer repair decisions.
- Additional authored camp variants or randomized starting conditions.
- More modular upgrade choices and destructible defenses.
- One player emergency ability.
- More exploration discoveries and environmental storytelling.
- Final beacon defense, weather variants and expanded accessibility settings.

## Features to defer

Procedural terrain, path-blocking free placement, multiplayer, a crafting tree, fully simulated carts/vehicles, seamless portals, extensive dialogue and a huge streaming world. These do not improve the first proof of this particular game enough to justify their integration cost.

## Milestone report template

For each milestone, record: what now works; screenshot/build location; checks performed; renderer/resolution; measured performance if available; remaining placeholders; and the next highest-value visual or gameplay correction. Distinguish a feature that is implemented but unverified from one tested in the actual running game.
