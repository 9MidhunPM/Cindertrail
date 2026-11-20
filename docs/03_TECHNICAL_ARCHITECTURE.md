# Technical architecture

## Engine and targets

Use a supported stable Godot 4 release with GDScript. Record the actual installed engine version in the project README and use matching export templates. Native Linux is the first delivery target for the user's Ultra 7 255H / integrated Arc laptop.

Begin native look development with Godot's **Mobile rendering method** and a restrained scene. Its name does not imply a mobile-platform product. If compatibility or web delivery is needed, maintain a separately checked **Compatibility** rendering profile. Art direction must survive through geometry, materials, ambient light, restrained direct lighting and supported depth cues.

Check the [official renderer feature table](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) against the actual installed release. The current stable table checked for this pack lists glow in all three renderers, SSAO in Forward+ and Compatibility but not Mobile, and volumetric fog/screen-space reflections in Forward+ only. Do not copy older blanket claims that Compatibility can never use glow. Availability does not guarantee identical appearance, cost or browser behavior; verify in the target build. Use simple color/lighting and supported haze alternatives before depending on a costly effect.

No specific FPS is guaranteed. Measure actual CPU/GPU time, resolution, renderer and scene content on target hardware. The integrated GPU makes draw calls, shadows, transparency and full-resolution effects important budgets.

## Suggested project layout

```text
project.godot
scenes/
  main.tscn
  world/valley.tscn
  player/traveler.tscn
  core/sun_shrine.tscn
  sites/{quarry,grove,relay,beacon}.tscn
  defenses/{bolt_turret,slowing_field,mortar}.tscn
  enemies/{crawler,brute}.tscn
  ui/hud.tscn
scripts/
  game_flow.gd
  player_controller.gd
  camera_director.gd
  core_controller.gd
  site_controller.gd
  wave_director.gd
  module_inventory.gd
  tower_socket.gd
  enemy_controller.gd
  hud_controller.gd
data/
  sites/*.tres
  defenses/*.tres
  enemies/*.tres
  waves/*.tres
art/{models,materials,textures,source}/
audio/
```

This layout is a proposal for the game repository. The starter pack's existing `art/concept/` remains reference material rather than runtime geometry. Use a few focused scripts; introduce a shared base class only when two actual implementations need it.

## State machine

| State | Camera/input | Core and world behavior |
| --- | --- | --- |
| Explore | Free third-person view; camera-relative movement. | Shrine carried; no organized camp waves; discovery/interactions available. |
| Deploy | Smooth camera rise/tilt; short committed interaction. | Same core moves from harness to site's pad; legs/rings unfold. |
| Prepare | Fixed angled view; free pointer for sockets. | Core anchored; modules can be arranged; no unlimited free restoration. |
| Defend | Fixed tactical view; movement and combat remain real time. | Energy extraction and waves active; current site threat increases. |
| Pack | Camera held during short channel. | Damage continues; on completion extraction stops and modules recall. |
| Transit | Camera returns behind traveler. | Shrine carried; existing enemies may pursue; no new organized waves. |
| Win | Controlled ending camera/input. | Same sun transferred to beacon; dawn plays; no backpack duplicate. |
| Lose | Defeat presentation/restart. | Core destroyed; extraction and spawning stop. |

The state machine should own transitions. A camera animation finishing should not silently create a second core or reset site data. Explore and Transit may share movement code; keep separate game-flow meaning without duplicating controllers.

## Single-core implementation

Keep one authoritative `CoreController` with health, restoration and a stable identity. Move or reparent its visual rig between a player carry anchor, a site deployment anchor and the final beacon anchor, preserving the intended transform. Carried/deployed meshes can be child variants with only one visible/interactable form active.

All damage resolves to that core's persistent health. All extraction updates its restoration and the site's remaining energy in the same operation. Packing changes form and location, not gameplay identity. Guard duplicate interactions while a transition is running.

## Data ownership

- `GameFlow`: current run state, active site, win/loss and restart.
- `CoreController`: persistent core health/restoration and visual form.
- `ModuleInventory`: owned modules, upgrades and scrap; no inventory grid needed.
- `SiteController`: persistent remaining energy, local threat, deployment pad, sockets, routes and water/terrain modifiers.
- `WaveDirector`: next-wave forecast, authored spawn composition and active-enemy budget.
- `CameraDirector`: exploration orbit, tactical pose, collision handling and eased transitions.
- `HUDController`: observes values/signals; never owns gameplay truth.

Use signals such as `health_changed`, `restoration_changed`, `site_energy_changed`, `threat_changed`, `mode_changed` and `core_destroyed` as local contracts. Avoid adding a generalized message bus before it solves an actual problem.

## Navigation and placement

Defense waves initially follow authored route points toward the core. Sockets are off those routes, and terrain is static. One pre-baked static walkable navigation surface can support existing enemies that retarget a carried core during transit. Do not rebuild navigation every time a tower is placed.

The first proof may use a simple connecting trail, but the finished slice must not let pursuers walk through canyon walls or water cliffs. Keep the active pursuer count bounded. Distant enemies can disengage by a visible, documented leash rule rather than follow forever or teleport into a new camp.

Placement validates socket occupancy, module ownership, cost and current mode. A failed placement does not deduct resources. Packing returns module ownership with upgrades intact; deployment does not duplicate a module. Keep tower firing disabled in carried/packed states.

## Camera and controls

Exploration uses a collision-aware third-person orbit and camera-relative walking. Tactical view uses a fixed angled pose framed around the active site; all approaches and the retreat exit remain visible. Smooth between transforms without loading another arena or changing terrain scale.

Initial input proposal, adjustable during usability testing:

| Input | Exploration | Defense/preparation |
| --- | --- | --- |
| WASD | Camera-relative movement. | Movement relative to tactical camera's ground-plane axes. |
| Mouse | Rotate camera while captured. | Free pointer for selection/aiming. |
| Shift | Sprint. | Sprint where useful. |
| E | Interact, search supply cache or deploy at a pad. | Interact/repair selected nearby object. |
| Hold R | No effect when already carried. | Pack shrine after short channel. |
| 1 / 2 / 3 | No required action. | Select available defense module. |
| Left click | Basic attack along aiming direction. | Place selected module in valid socket; clear selection afterward. |
| Right click | Optional aim modifier. | Basic attack toward pointed ground/target when supported. |
| Escape | Pause/release pointer as appropriate. | Cancel placement, then pause if nothing selected. |

Do not make one click both place a tower and fire a weapon. Show current controls in a small mode-sensitive hint. Jumping, dashing and a player pulse are not required for routes made from traversable paths and stairs.

## Rendering and asset strategy

- Modular cream ruins, broad faceted rocks and clustered foliage provide shape and scale.
- Small palette/material families provide consistency; use UV gradients, roughness variation and subtle masks where valuable.
- Preserve the traveler/core silhouettes early; a custom shrine is a high-value hero asset.
- Use warm sun emission with a restrained nearby light; do not make every emitter a shadow-casting dynamic light.
- Use supported ambient depth cues and controlled distant haze. Test water transparencies and reflections from both camera modes.
- Keep colliders simpler than render meshes, and render detail separate from navigation geometry.

## Persistence and restart

First keep run persistence in memory across mode/site transitions. A restart must explicitly rebuild run state and clear enemies/modules without duplicating scene objects. File-based save/load is optional until a complete short run works. If added, serialize stable site/module IDs rather than scene-tree object references.

## Export

Native Linux first, using matching templates. If web is required, use GDScript and the Compatibility profile and test pointer capture, audio startup, memory/loading, water and frame time early. Do not advertise native/web visual parity without comparing the actual builds.
