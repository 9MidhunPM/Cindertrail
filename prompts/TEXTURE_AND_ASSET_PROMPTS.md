# Texture and Asset Production Briefs

These are reusable task briefs for the coding/art agent. They complement the supplied procedural starter kit. Models, palette, lighting and camera composition are the main style drivers; realistic noisy textures alone will not reproduce the paintings.

## 1. Match one real scene first

> Read AGENTS.md, docs/04_VISUAL_ACCEPTANCE.md and docs/06_MATERIAL_AND_MODEL_PIPELINE.md. Open art/concept/14_grove_crossing.png and 05_grove_defense.png. Build the same small dry island, reachable causeway, cream arches and teal tree silhouettes in Godot using editable 3D assets. Use the same world for shoulder-height third-person exploration and an elevated fixed defense camera. Apply the supplied palette/materials, one cool key light and localized amber shrine light. Render screenshots from both camera presets. Compare terrain silhouette, player size in frame, camera angle, value contrast, palette and shrine scale against the references. Fix the three largest differences before adding unrelated scenery. Show the real runtime screenshots and identify remaining mismatches honestly.

## 2. Create modular low-poly geometry in Blender

> Use the Blender asset builder as a starting point. Read art/concept/03_traveler_shrine_sheet.png and 07_defense_modules.png. Make cream-stone blocks, worn steps, arch segments, columns and low polygon tree crowns with consistent scale and named material slots. Bevel selected stone edges lightly, keep broad faceted surfaces, and use smooth shading selectively on metal rings rather than on all terrain. Preserve object origins, clean transforms and unit scale. Use broad hand-authored color/value variation instead of dense surface noise. Export GLB with material slots, UVs and normals intact. Open the exports in Godot and verify real scale, pivots, backface culling and collisions. A static GLB is not a rigged or animated character.

## 3. Produce the unique sun shrine

> Model the one shrine from art/concept/03_traveler_shrine_sheet.png: three folding bronze legs, a central golden sun and three broken orbital rings. Use a shared hierarchy with pivoted legs and rings so the same object can animate between deployed and compact carry configurations. Keep one gameplay-owned core node; reparent or animate its visual rather than leaving copies behind. The fold animation must not change the asset's identity. Make intact restored-ring geometry as a controlled visual state. Avoid adding a second light orb on the traveler while the sun is deployed.

## 4. Ask an image model for a useful painted stone tile

> A seamless, tileable base-color texture for pale cream limestone used on stylized faceted low-poly ruins. Warm ivory base, broad subtle ochre/gray mineral variation, sparse soft chips and restrained weathering. Flat evenly lit surface viewed exactly perpendicular. No directional shadows, no lighting gradients, no specular highlights, no ambient occlusion, no objects, no wall or brick perspective, no border, no text. Repeat cleanly across all four edges. This is an albedo map only, not a rendered stone wall illustration.

Generate one surface per image, then test the repeat on an actual 3D plane and stone block. An image model's claim of seamlessness must be checked. Do not use a montage, screenshot or reference painting directly as an albedo tile.

## 5. Ask for supporting fabric or wood albedo

> Seamless flat-lit stylized teal cloak-fabric base-color tile, broad low-contrast woven suggestion at a scale suitable for a small third-person character, muted blue-green palette, no wrinkles or baked directional lighting, no folds, no garment silhouette, no borders or text.

> Seamless flat-lit stylized warm brown old timber base-color tile, broad simplified grain, restrained wear, minimal fine noise, no shadows or perspective, no plank-end objects, no text. Preserve subdued values so golden shrine lighting remains readable.

For downloaded PBR sets use the provider's actual color, roughness and OpenGL normal maps. Do not relabel one AI color image as a physically correct normal/roughness map. Use the supplied low-detail materials first, then introduce supporting surface detail selectively.

## 6. Screenshot correction prompt

> Compare this actual Godot screenshot with the attached Cindertrail reference from the same camera. List the five largest visual differences, ordered by effect on similarity. Focus first on framing and scale, then geometry silhouettes, light/value structure, palette, and finally surface detail. Implement one short correction pass and capture the same camera again. Preserve the working core gameplay. Do not replace the real screenshot with generated concept art or declare an exact match without showing it.
