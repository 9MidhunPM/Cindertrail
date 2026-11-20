# Cindertrail game design

## Product statement

**CINDERTRAIL — Carry the Last Sunrise** is a single-player open-world exploration and nomadic tower-defense game. A traveler protects a damaged miniature sun, moves between ancient energy sites, and restores it while hostile creatures converge on its light.

The defining decision is **progress versus pressure**: extracting more energy helps complete the journey, but remaining in one position makes the next attack harder and the eventual escape riskier.

## Player promise

- Walk through the environment shown in the exploration concepts, discover supplies and inspect possible defensive positions.
- Choose where to anchor the protected item and arrange a compact set of defensive modules.
- Use terrain to change the encounter, actively support the defenses and decide when to leave.
- Carry the same precious item away, keeping progress and upgrades, then adapt to another position.
- Complete a journey with a visible ending: release the restored sun at the hilltop beacon.

## World and presentation

One small continuous valley connects three distinct camps, optional supply alcoves, branching paths and a final beacon. The player can choose destinations and order. Main landmarks remain recognizable from paths and overlooks. Authored landscape topology is important; randomization should initially affect supply locations, energy/tuning variants or wave composition, not destroy the designed geography.

The camera sits behind the traveler during exploration. Deployment raises and tilts it into a fixed angled tactical view of that same area. This gives the requested 2.5D defense presentation while retaining fully 3D geometry. Packing reverses the transition. All fighting remains real time.

## The protected item

The sun shrine is an open bronze cage on three folding tripod legs, with three damaged orbital rings around a warm golden miniature sun. In carry mode the legs and rings fold close into a backpack lantern. When deployed, the traveler has an empty harness. When delivered to the beacon, the sun is in the beacon and absent from the backpack.

There is exactly one gameplay core, one health value and one restoration value. Visual forms must not produce extra interactable or damageable copies.

| Persistent value | Purpose |
| --- | --- |
| Shrine health | Survival; damage remains after relocation; zero means defeat. |
| Sun restoration | Objective progress from 0–100%; preserved after damage or relocation. |
| Scrap | One currency for modules, upgrades and repairs. |
| Built module inventory | Owned defenses and their upgrades travel with the shrine. |
| Site energy | Finite restoration supply at each camp; extracted amounts remain depleted. |
| Local threat | Site-specific attack pressure; leaving and returning does not reset it. |

## Main loop

1. Explore with the folded shrine. Read the terrain, find supplies and choose a destination.
2. Approach an empty deployment pad and inspect site information.
3. Deploy the single core. Camera rises; defense/build controls become available.
4. Place modules in the site's sockets, then deliberately start the encounter. Restoration does not advance during unlimited preparation.
5. Defend while the shrine absorbs energy. Support weak approaches with the player's basic weapon; collect scrap during safe gaps.
6. Read the next attack's direction, approximate threat and remaining site energy.
7. Stay for another wave or hold the pack action to recall defenses and fold the core.
8. Move away. New organized waves pause, but already-spawned nearby enemies can pursue.
9. Redeploy at a different site with progress and upgrades intact.
10. At 100% restoration, carry the core to the final beacon and trigger the sunrise ending.

## Three prototype sites

These are initial tuning values, not validated final balance.

| Site | Identity and advantage | Meaningful weakness | Energy reserve | Initial charge rate |
| --- | --- | --- | --- | --- |
| Broken Quarry | Cream rock walls, old cranes, one main choke point; bolt and mortar combinations work well. | Few useful socket angles and a small reserve; eventually little reason to remain. | 30% | 0.15 percentage points/second |
| Flooded Grove | Dry ruins in shallow water; crossing enemies visibly slow. | Two separated approaches require divided coverage. | 45% | 0.18 percentage points/second |
| Fallen Relay | Exposed stone plateau and ancient generator; fastest restoration. | Three approaches and more threatening wave escalation. | 60% | 0.24 percentage points/second |

The richer two sites contain enough energy for a direct but difficult route. A player can instead take some energy from all three. Restoration is capped at 100%, and the drawn amount is deducted from the current site's reserve.

Water affects actual enemy movement, not just decoration. Quarry walls physically shape routes. The relay exposes distinct directions of attack. Keep these advantages visible before introducing additional percentage-based buffs.

## Defenses

Four predefined dry construction sockets per camp; begin with three module types. Sockets sit outside travel lanes so a build cannot block all enemy navigation.

| Module | Function | Visual identity |
| --- | --- | --- |
| Bolt turret | Consistent single-target ranged damage. | Brass tripod/prongs, amber crystal and narrow amber rounds. |
| Slowing field | Reduces enemy speed within a readable radius. | Squat cyan mushroom-shaped emitter and gentle ground ripple. |
| Mortar | Slow area damage against groups. | Cream stone cup, bronze base and arcing amber projectile. |

For the first slice, owned modules fold into the shrine automatically when packing and keep upgrades. Avoid tower-by-tower collection or an inventory grid. Destructible towers and partial salvage are optional later systems; core damage is enough to create retreat pressure in the initial version.

## Enemies and player activity

- **Crawler:** low, fast, ink-black body with turquoise fissures. Groups test coverage and choke control.
- **Armored brute:** larger charcoal slabs with violet fissures. Slow and durable; tests sustained damage and target priority.

The initial player action is a weak repeatable ranged attack that helps a struggling lane without replacing the towers. Walking, sprinting, collecting scrap, placing modules and choosing a retreat provide additional activity. A knockback pulse or dash is a stretch feature after the core loop is satisfying.

## Pressure, forecast and retreat

Local threat rises as a site survives waves; it is stored per site. Overall wave strength may increase with restoration milestones, keeping the journey from becoming trivial after the first camp. Avoid an invisible global timer that punishes exploration.

Show remaining energy, upcoming approach directions and a simple next-wave threat estimate. Retreat should be a decision, not a surprise mandatory cutscene. A brief pack channel creates commitment; enemies and damage remain active during it. Once packing completes, towers stop firing, restoration stops and travel control resumes.

Provide accessible repairs for scrap so one early mistake does not create an unavoidable loss spiral. A later sanctuary can offer recovery at the cost of a detour; it is not required for the three-site MVP.

## Exploration content

Each connection should contain at least one choice: a short exposed path, a safer detour, a supply alcove or a useful overlook. Travel should take tens of seconds, not several empty minutes. Use distant landmarks and lighting to guide players; avoid filling the map with unrelated activities.

## Win, loss and ending

At full restoration, the beacon becomes the destination. Interacting there transfers the same core into its cradle, removes the backpack form and plays a short dawn sequence across the valley. A final defense is a stretch feature. Core destruction ends the run and offers a clear restart. Keep both outcomes fully playable before adding more content.

## Scope boundary

Single player, one continuous authored valley, three camps, three module types, two enemies, one economy, two camera modes and one ending. Multiplayer, procedural terrain, freely placed path-blocking towers, a travelling vehicle simulation, an infinite enemy army and a complete crafting tree remain outside the initial project.
