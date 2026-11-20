# Verification and playtest plan

Use meaningful integration checks and brief actual playtests. The goal is to catch failures of the game's central promises, not accumulate tests that duplicate the implementation.

## Required checks

| Scenario | Expected behavior |
| --- | --- |
| Explore to deploy to pack | One core changes form and position; camera/control modes reverse correctly; no duplicate sun remains on backpack. |
| Place a module | Only a valid empty socket accepts it; owned inventory/cost updates once; invalid attempts cost nothing. |
| Pack under attack | Damage and existing enemies remain active during the short channel; once packed, module firing and extraction stop. |
| Redeploy elsewhere | Core health, restoration, scrap and module upgrades are preserved. |
| Return to a used camp | Remaining energy and local threat match departure state; packing/redeployment cannot reset them. |
| Extract last site energy | Restoration gain is bounded by remaining reserve and the 100% objective cap; no negative energy. |
| Carry with pursuers | Existing enemies retarget the carried core without walking through walls; new organized waves remain paused. |
| Build every socket | A route to the core and a walkable retreat remain; placed towers do not require navigation rebuilding. |
| Enter shallow water | Enemy speed visibly changes and returns correctly on exit; effect does not stack permanently. |
| Core reaches zero health | Extraction/spawning stop, loss UI appears and the run can restart cleanly. |
| Core reaches 100% | Objective changes to beacon; delivery transfers the same sun to its cradle and produces a win state. |
| Restart after win/loss | No orphaned enemies, duplicate core, retained stale site state or unintended free modules. |

Automate persistence/cost/cap and state-transition checks where practical. Verify camera behavior, pathing, material imports and feel in the running game.

## First playable-loop playtest

1. Begin at the grove approach in third person; rotate the camera near walls/trees and follow the visible path.
2. Deploy, arrange one turret and start a wave.
3. Take some core damage, gain some restoration and collect scrap.
4. Pack before the attack is fully cleared.
5. Travel to a second camp while at least one enemy pursues.
6. Redeploy and check all persistent values against the departure values.
7. Return to the first camp and verify its reserve and threat did not reset.

## Complete-run playtest

Test a safer route using all three sites and a harder route using the grove/relay energy reserves. Both should be possible with sensible play after tuning. Check that the player can understand the next attack, identify why the site is becoming dangerous and choose a retreat before damage becomes unavoidable.

Observe whether the player spends too long waiting, packing, searching for interaction prompts or walking through empty connections. Those are pacing failures even if no code crashes.

## Visual regression captures

Keep a small set of fixed captures:

- Third-person grove crossing matching concept 14.
- Grove tactical defense matching concept 05.
- Quarry choke with a group of crawlers.
- Relay's three simultaneous approaches.
- Carried core during retreat.
- Empty harness and delivered sun at the beacon.

Compare camera, silhouette, palette, material imports and visibility after major asset or renderer changes. A renderer change warrants new reference captures.

## Performance checks

Record actual device, OS/driver when known, Godot version, renderer, resolution, frame-time average/spikes, active-enemy count and major effects. Measure a quiet exploration scene and the busiest intended defense scene separately. Use a realistic target selected from measurements; do not publish an invented FPS guarantee.

If performance is inadequate, first inspect shadow-casting lights, transparent water/foliage, draw-call count, unnecessary per-frame work and active enemies. Maintain visual composition while reducing cost. Provide a tested resolution/effect setting if needed.

## Export smoke test

Run the native build from a fresh extraction with no editor assets or absolute source paths available. Check start, input, audio, one transition, one defense, retreat and restart.

If shipping web, separately test loading, click-to-start audio, pointer capture, lost focus, viewport resize, controls, renderer-supported materials and memory. A passing native build does not validate the browser build.

## Completion report

Record each feature as **implemented and tested**, **implemented but unverified**, **placeholder**, or **planned**. Include which scenarios actually ran, representative actual-game captures and unresolved blockers. Keep the concept trailer separate from implementation evidence.
