# Blockraft Original Source Models

## First architectural/nature set
- `voxel_oak_tree.obj` — layered oak canopy with bark and leaf color variation.
- `meadow_cottage.obj` — timber/plaster starter cottage with stepped roof and windows.
- `crafting_bench.obj` — starter crafting station with framed work surface and focal detail.

## Terrain/resource set
- `voxel_block_set.obj` — eight separated review blocks: grass, dirt, stone, sand, copper ore, crystal ore, log end-grain, and water-color reference.
- `grass_block.obj` — standalone terrain block showing grass top and dirt sides.
- `ore_outcrop.obj` — rocky resource outcrop with copper and cyan crystal deposits.
- `blockraft_palette.mtl` — shared original material palette for the OBJ source meshes.

Each OBJ references `blockraft_palette.mtl` in this directory. Open `scenes/asset_gallery.tscn` to preview the tree, cottage, crafting bench, grass block, and ore outcrop. Use Blender 4.x with `tools/blender/build_blockraft_asset_pack.py` to create review exports; those outputs are not generated until the script has actually run.

## Acceptance status
These are editable source meshes for the first asset review pass, not approved final art. The approved visual north-star image must be committed to `assets/reference/blockcraft_visual_north_star.png` before final art acceptance. Review silhouette, palette, scale, lighting, materials, collisions, and Android readability before production integration.
