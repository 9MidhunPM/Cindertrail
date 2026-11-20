# Skills and MCP setup for the Cindertrail build

Checked 20 November 2026. These tools are recommendations, not preinstalled services in this ZIP. Start with one Godot integration and one Blender integration. The project's `AGENTS.md`, reference images and visual acceptance checks remain the production brief.

## Recommended pair

| Tool | Primary source | Useful job |
|---|---|---|
| Coding-Solo Godot MCP | https://github.com/Coding-Solo/godot-mcp | Launch/run/stop Godot, inspect project structure, edit scenes and capture debug output. |
| MCP for Blender by ahujasid | https://github.com/ahujasid/mcp-for-blender | Create/edit Blender geometry and materials; inspect a scene and refine bespoke shrine, towers, arches and foliage. |

These are community integrations. MCP supplies actions, while skills supply reusable working instructions. Neither replaces an actual render-and-compare loop.

## Godot MCP: simple setup

The upstream package is `@coding-solo/godot-mcp`; its README specifies Node.js 18 or newer and an installed Godot engine.

On your Arch laptop, first find the executable you actually use:

```bash
command -v godot
godot --version
```

If you use a downloaded portable executable, use its absolute path instead. Register the server with that exact path, for example replacing the placeholder below:

```bash
codex mcp add godot --env GODOT_PATH=/ABSOLUTE/PATH/TO/YOUR/godot -- npx -y @coding-solo/godot-mcp
```

The command structure and `--env` option were checked against the installed Codex CLI's `codex mcp add --help`. Restart the client, inspect the available tools and ask it to report the Godot version and run a tiny scene. After the connection succeeds, pin the tested server version for repeatable builds.

A TOML example is in `configs/mcp_servers.example.toml`. Merge selected sections with your existing configuration; retain unrelated settings. Keep real personal paths in local configuration.

## Blender MCP: model and material work

The original `ahujasid/blender-mcp` project is now **MCP for Blender**, with new-install package name `mcp-for-blender`. Use its current upstream setup rather than a similarly named fork.

With `uv` installed:

```bash
uvx mcp-for-blender install-addon
codex mcp add blender -- uvx mcp-for-blender
```

Open Blender, enable **Interface: MCP for Blender** in Preferences → Add-ons, and check its sidebar connection. Restart the MCP client after configuration. The upstream also offers `uvx mcp-for-blender setup`; that interactive option configures selected clients and the addon. Use either the documented manual route or the setup route.

First useful request:

> Inspect the Cindertrail traveler/shrine and defense-module reference sheets. Build one deployed sun shrine from separate low-poly bronze cage, ring, leg and sun meshes. Use the project's palette materials. Preserve a single core object, sensible pivots and game scale. Export GLB and render three views for comparison before adding ornament.

Prefer small mesh-generation steps followed by inspection. Use the included `scripts/build_blender_assets.py` if available in this pack as a reproducible starting point; it is separate from MCP installation. No paid image-to-3D service is required by this workflow.

## Verified public skills to consider

1. **Godot GDScript Patterns** — [exact SKILL.md](https://github.com/wshobson/agents/blob/main/plugins/game-development/skills/godot-gdscript-patterns/SKILL.md), from [wshobson/agents](https://github.com/wshobson/agents). Focused Godot 4 guidance for signals, scenes, state and optimization. Read its companion `references/details.md` when needed. Some examples use 2D nodes; Cindertrail needs their 3D equivalents.
2. **Godot 3D Materials** — [exact SKILL.md](https://github.com/bgrenat/godot-game-dev-studio/blob/main/skills/godot-3d-materials/SKILL.md). Useful for StandardMaterial3D, normal maps, roughness/metalness and texture organization.
3. **Godot Camera Systems** — [exact SKILL.md](https://github.com/bgrenat/godot-game-dev-studio/blob/main/skills/godot-camera-systems/SKILL.md). Useful for third-person following, SpringArm3D and camera transitions.

The latter two belong to [Godot Game Dev Studio](https://github.com/bgrenat/godot-game-dev-studio), which currently targets Godot 4.7+. Read its [compatibility notes](https://github.com/bgrenat/godot-game-dev-studio/blob/main/COMPATIBILITY.md) and choose only guidance supported by your installed engine. Check repository licenses and installation instructions before copying skill directories. The ZIP links these skills instead of silently installing or redistributing them.

The assistant can read the relevant skill from a user-approved checkout and apply it to one task. Avoid loading an entire skill collection or adding plugins during the jam without a concrete need. Documentation examples are inputs to engineering judgment; the installed Godot APIs and this project's art direction are authoritative.

## The feedback loop that actually improves visual fidelity

For each reference view:

1. Load the matching concept PNG and the current game screenshot side by side.
2. Compare camera height/FOV, traveler size, shrine silhouette, palette, light direction, fog depth and landmark proportions.
3. Fix the largest visual difference first.
4. Run the scene and save a new screenshot from the same camera.
5. Record the exact engine version, renderer and resolution.

The basic Coding-Solo README does not promise a screenshot/input tool set. Verify the tools your installed server exposes rather than assuming it can play or see the game. If screenshots are unavailable, add an opt-in screenshot action to the game using Godot's viewport capture API, or capture the running window with your desktop tools. A rendered window or suitable rendering display is required; a successful headless import is not a visual test.

For more extensive live inspection, [zeegzoog/godot-mcp](https://github.com/zeegzoog/godot-mcp) documents an editor bridge and [running-game checks](https://github.com/zeegzoog/godot-mcp/blob/master/docs/running-game.md). Treat it as an alternative to evaluate, not a second mandatory Godot server. Follow its release/engine-version installation instructions and verify the available capture tools on the actual setup.

Use browser automation only for a browser build. Native Godot scene inspection and viewport screenshots are more direct for the main Linux visual target.

## Work without MCP if setup takes too long

Codex can edit `.gd`, `.tscn`, `.tres` and shader files directly, call the installed Godot CLI for import/script checks and run the project. Blender can run a reproducible Python builder in background mode. MCP makes tool access more convenient; the important requirement is inspecting actual results.

## Official technical references

- Godot [3D import formats and Blender workflow](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- Godot [renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- Godot [web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- Godot [ViewportTexture](https://docs.godotengine.org/en/stable/classes/class_viewporttexture.html)
- Blender [glTF exporter](https://docs.blender.org/manual/en/latest/addons/import_export/scene_gltf2.html)

Installation commands are supplied for the user's machine. This documentation does not claim the recommended third-party MCP servers have been installed or runtime-tested here.
