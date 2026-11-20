# Asset sources, licenses and useful downloads

Verified from primary creator documentation on 20 November 2026. These are optional sources for the project; links do not imply that a whole library has been downloaded or bundled.

## Match the reference, not the asset store

Cindertrail's look comes from cream faceted architecture, teal foliage, orange accents, brass silhouettes, warm local light, cool atmospheric depth and composed cameras. Start with the included palette/material kit and custom shrine. Stock photorealistic textures are secondary surface detail, not a substitute for these decisions. Do not project an entire concept illustration onto terrain or use it as a playable backdrop.

## Recommended sources

| Source | Specific pack or catalog | What to use | License / packaging |
|---|---|---|---|
| Kenney | [Nature Kit](https://kenney.nl/assets/nature-kit) | Simple rocks, trees, ground pieces; recolor to the Cindertrail palette | Pack page lists CC0; preserve the downloaded license file. |
| Quaternius | [Ultimate Stylized Nature](https://quaternius.com/packs/ultimatestylizednature.html) | Stylized foliage and terrain accents; supports glTF as well as Blender/FBX/OBJ | Pack page lists CC0; use its own included textures only after palette adjustment. |
| KayKit / Kay Lousberg | [Dungeon Remastered](https://kaylousberg.com/game-assets/dungeon-remastered) | Modular ruins, stairs, arches, crates and supplies | Creator page lists CC0 and a shared gradient atlas. Free pack is sufficient; paid extras are optional. |
| ambientCG | [Material catalog](https://ambientcg.com/list?type=Material) | Subtle roughness, weave and ground variation | [CC0 license](https://docs.ambientcg.com/license/) permits reuse and redistribution. |
| Poly Haven | [Textures](https://polyhaven.com/textures) | Optional restrained surface maps and lighting studies | [CC0 license](https://polyhaven.com/license). Asset API access may have separate service requirements; manual downloads remain an alternative. |

Avoid mixing several packs without recoloring and checking scale. For the traveler, shrine, towers and recognizable relay, bespoke meshes based on the model sheets are the strongest route to visual consistency.

## Exact optional texture selections

These are real provider IDs, verified through the ambientCG catalog/API. They are surface-detail sources, **not exact textures extracted from the generated concept art**.

| ID | Official asset page | Intended use | Art-direction adjustment |
|---|---|---|---|
| `PavingStones036` | https://ambientcg.com/view?id=PavingStones036 | Path wear, moss and stone roughness | Keep cream stone geometry; introduce only a little of this map's detail. Its photographed dark paving color is not the target palette. |
| `Metal032` | https://ambientcg.com/view?id=Metal032 | Metal roughness for shrine and bronze machinery | Set brass/bronze color explicitly; keep reflections broad and restrained. |
| `Fabric030` | https://ambientcg.com/view?id=Fabric030 | Fine cloak weave | Tint with the teal material; use weak normal/roughness detail so the cloak silhouette stays readable. |
| `WoodFloor050` | https://ambientcg.com/view?id=WoodFloor050 | Secondary wood detail for crates and quarry walkways | Reduce contrast; avoid turning every plank into an indoor parquet pattern. |

The included downloader queries [ambientCG's documented metadata endpoint](https://docs.ambientcg.com/api/v2/full_json/) and uses the returned download URLs. It selects the 1K-JPG archive and keeps Color, Roughness, OpenGL Normal and Metalness maps where provided. No API key is required for this workflow.

```bash
# Preview official URLs and archive sizes; no files saved.
python scripts/fetch_optional_textures.py

# Fetch four selected materials, retain only useful maps and write a source manifest.
python scripts/fetch_optional_textures.py --download

# Fetch only one named asset.
python scripts/fetch_optional_textures.py --asset Metal032 --download
```

Default output is `art/textures/third_party/ambientCG/`. Check `SOURCE_MANIFEST.json`: `complete` and its per-asset `maps` entries report what actually downloaded. Each map has a SHA-256 checksum. A network error must be reported, not mistaken for a successful texture installation. Source ZIPs, DirectX normal maps and high-resolution displacement files are not retained.

For manual download, open the official asset page, choose **1K-JPG**, extract locally and retain the license/source information. A provider preview image is not a full material.

## Applying these maps

1. Use the included cream, teal, bronze and amber materials as the base colors.
2. Keep large stylized color regions. Introduce surface texture only after geometry, camera and lighting match a reference.
3. Import normal maps as normal data; prefer `NormalGL`. Color is sRGB; roughness and metalness are data.
4. In Godot, start with StandardMaterial3D: assign Color to Albedo if wanted, Roughness to Roughness, and NormalGL to Normal Map. Enable each map explicitly and reduce normal strength.
5. For a subtle detail-only workflow, keep the palette albedo and use only normal/roughness. Bake a simplified stylized albedo from Blender if a unique surface needs more variation.
6. Judge both the third-person exploration camera and the fixed defense camera at the intended resolution.

## Licensing records

Keep creator/source URL, pack name, download date, license and any original LICENSE file in the project. CC0 attribution is optional for the listed CC0 assets, but credits are useful provenance. The downloader writes `CREDITS.md` and `SOURCE_MANIFEST.json` for its actual files.

Do not label the concept images or uploaded trailer as third-party CC0 assets: they are project visual references with their own generation/provenance. The pack does not grant rights to third-party brands or game characters. Do not bundle paid assets or BlenderKit items under an assumed CC0 license; check the exact asset's terms.

## Renderer check before committing to a look

Read the [current Godot renderer comparison](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) for the **installed engine version**. The stable page checked for this pack lists glow in all three renderers and SSAO in Compatibility and Forward+, while volumetric fog and screen-space reflections are Forward+ features. Older Godot versions differ. Browser WebGL constraints also need an actual export test.

For this laptop, compare a restrained native Mobile look-development scene with a Compatibility/browser profile. Use depth/height fog and simple stylized water first. Do not make the art depend on volumetric fog, SSR or expensive full-screen effects. Feature availability is not proof that an effect is affordable or looks identical across renderers. Record the chosen engine version and renderer in each screenshot review.
