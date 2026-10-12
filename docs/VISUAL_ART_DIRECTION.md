# Blockraft — Visual Art Direction and Asset Gate

## Status
**Reference approved by the project owner. Production asset creation must not begin until the source image is committed and verified at `assets/reference/blockraft_visual_north_star.png`.**

## Visual pillars
1. **Readable voxel construction:** consistent grid, crisp block edges, deliberate silhouettes; avoid noisy micro-detail.
2. **Worlds with identity:** each biome has its own terrain forms, vegetation, palette, landmark architecture, and resource distribution.
3. **Premium lighting:** sun direction, ambient fill, contact shadows, distance haze, warm/cool contrast, and restrained emissive lights.
4. **Designed composition:** meaningful foreground, midground, and background; memorable landmarks visible from gameplay distance.
5. **Coherent materials:** grass, dirt, stone, wood, ores, water, leaves, and crafted objects must remain distinguishable at Android screen sizes.
6. **Original IP:** do not reuse Minecraft logos, textures, character designs, UI, sounds, or other proprietary assets. Create a distinct Blockraft identity.

## Required asset pipeline — before game integration
- Preserve the original reference image unchanged.
- Create a reference board and written asset briefs for: terrain blocks, trees/foliage, ores, water, player, tools, crafting station, starter house, village, mountain biome, desert biome, ocean biome, floating islands, menu UI, and icons.
- For every asset, record intended dimensions/voxel scale, palette/materials, LOD or mobile budget, collision needs, file format, and visual acceptance checks.
- Review renders against the north-star image at native mobile resolution.
- Only integrate assets after review; placeholders must be clearly labeled and never treated as accepted final art.

## Quality gates
- **Gate A — Reference:** source image exists at the required path and opens from GitHub.
- **Gate B — Asset previews:** each asset family has a preview and passes silhouette/material/readability review.
- **Gate C — In-engine:** assets are tested in Godot with actual game lighting, scale, collision, and camera.
- **Gate D — Android:** test on device for frame pacing, memory, touch readability, and thermal behavior.
- A successful build alone does not pass a visual gate.

## Current scope
This document establishes the art direction and review process. It does not claim that the source image has been committed, that production assets exist, or that Android visual acceptance has passed.
