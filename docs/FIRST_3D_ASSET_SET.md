# First 3D Asset Set — Blockraft

## Status
The first authored source meshes are committed. The approved visual north-star image is available in the Roblox ChatGPT Project's attached `source` files and is the mandatory art target; it is not committed as a binary in this GitHub repository. Models are not yet accepted production art because a Godot/Android visual review has not been completed.

## Source models

| Asset | Source | Intended use | Review focus |
|---|---|---|---|
| Voxel oak tree | `assets/models/voxel_oak_tree.obj` | Meadowlands vegetation | Layered canopy silhouette, trunk readability, leaf color variation |
| Meadow cottage | `assets/models/meadow_cottage.obj` | Starter village landmark | Roof silhouette, timber/plaster contrast, window scale, entrance readability |
| Crafting bench | `assets/models/crafting_bench.obj` | Crafting landmark | Clear tabletop, readable wood/metal detail, usable gameplay scale |
| Terrain/resource block set | `assets/models/voxel_block_set.obj` | Material/shape reference sheet | Grass, dirt, stone, sand, copper ore, crystal ore, log end grain, water color |
| Shared material palette | `assets/models/blockraft_palette.mtl` | All source meshes | Consistent original bark, foliage, stone, plaster, roof, glass, metals, terrain and resource colors |

## Preview and export
- Godot starter preview: open `scenes/asset_gallery.tscn` and run it (F6). It currently displays the original three hero assets.
- Blender 4.x pipeline: from the repository root run `blender --background --python tools/blender/build_blockraft_asset_pack.py`. The script imports all four OBJ sources and writes GLB review exports plus a `.blend` review scene locally. These generated binary outputs are not committed or runtime-verified yet.
- The terrain/resource sheet is intentionally spaced as a review model, not a gameplay chunk or optimized runtime mesh.

## Mandatory visual review
Use the approved source-folder image as a quality benchmark for rich but readable silhouettes, warm/cool lighting contrast, material separation, environmental richness and mobile UI clarity. Keep all Blockraft designs original; do not copy Minecraft branding or proprietary art.

## Next gates
1. Run the Blender builder and inspect all generated GLBs plus its review render.
2. Open the asset gallery in Godot and check material import, camera framing, lighting, scale, and shadow artifacts.
3. Refine the tree/cottage/bench silhouettes and block palette based on actual previews.
4. Add collisions and integrate accepted assets into a small Meadowlands test area.
5. Run on Android and inspect readability, frame pacing, memory, and touch interaction.

A successful file commit or engine build alone does not pass visual acceptance.
