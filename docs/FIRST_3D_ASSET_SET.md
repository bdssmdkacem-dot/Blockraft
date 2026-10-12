# Blockraft — First 3D Asset Set and Review Gate

## Approved art target
Use the image attached in the Roblox ChatGPT Project's `source` folder as the mandatory visual north star. It is the project's approved reference. Its image bytes are not stored in this GitHub repository, so the reference is available in project context but not independently embedded in this repo.

## Current source asset inventory

| Asset | Source | Intended use | Review focus |
|---|---|---|---|
| Oak tree | `assets/models/voxel_oak_tree.obj` | Meadowlands foliage | Layered canopy, trunk readability, leaf variation |
| Meadow cottage | `assets/models/meadow_cottage.obj` | Starter village landmark | Roof silhouette, timber/plaster contrast, window scale |
| Crafting bench | `assets/models/crafting_bench.obj` | Crafting station | Readable work surface, proportions, detail |
| Terrain/resource block sheet | `assets/models/voxel_block_set.obj` | Palette and shape review | Grass, dirt, stone, sand, copper, crystal, log end, water |
| Grass block | `assets/models/grass_block.obj` | Core terrain tile | Clear soil/grass layers and grid dimensions |
| Ore outcrop | `assets/models/ore_outcrop.obj` | Mining landmark | Rock silhouette and ore readability |
| Shared material palette | `assets/models/blockraft_palette.mtl` | All OBJ models | Consistent original material colors |

## Preview
- Run `scenes/asset_gallery.tscn` in Godot 4 for the three hero assets.
- Run `scenes/block_material_gallery.tscn` for the terrain/resource review sheet.
- Run the Blender review pipeline from the repository root: `blender --background --python tools/blender/build_blockraft_asset_pack.py`. It exports GLB review files for the six OBJ sources and saves a review BLEND scene locally. These outputs are generated locally and are not claimed to exist until the script runs successfully.

## Acceptance gates
1. Run the Blender script; verify all six GLBs are emitted without import/export errors.
2. Inspect the actual review render; check scale, face winding, material assignment, silhouette, and camera framing.
3. Open both galleries in Godot 4 and verify imported meshes/materials and lighting.
4. Refine any artifact before using these models in the playable world.
5. Add collision shapes and mobile-friendly LOD/mesh budgets before integration.
6. Test on Android for readability, memory use, and frame pacing.

These are source/reference assets, not accepted final production art yet. File presence and a successful build do not substitute for visual review.
