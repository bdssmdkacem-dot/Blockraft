# Blockraft Original Source Models

## First architectural/nature set
- `voxel_oak_tree.obj` — layered oak canopy with bark and leaf color variation.
- `meadow_cottage.obj` — timber/plaster starter cottage with stepped roof and windows.
- `crafting_bench.obj` — starter crafting station with framed work surface and focal detail.

## Terrain/resource reference set
- `voxel_block_set.obj` — eight separated review blocks: grass, dirt, stone, sand, copper ore, crystal ore, log end-grain, and water-color reference.
- `blockraft_palette.mtl` — shared original material palette for all OBJ source meshes.

Each OBJ references `blockraft_palette.mtl` in this directory. Open `scenes/asset_gallery.tscn` to preview the first three models. Use Blender 4.x to create GLB review exports for the full set with `tools/blender/build_blockraft_asset_pack.py`.

## Acceptance status
These are source meshes for the first asset review pass, not approved final art. The approved visual north star is the PNG attached in the Roblox ChatGPT Project's `source` files; its binary is not part of this repository. Review silhouette, palette, scale, lighting, materials, collisions, and Android readability before production integration.
