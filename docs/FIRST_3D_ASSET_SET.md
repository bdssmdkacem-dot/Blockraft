# First 3D Asset Set — Blockraft

## Status
These are authored, importable voxel-style source meshes and a preview scene. They are **blockout assets, not accepted production art**: the approved north-star image must be present at `assets/reference/blockcraft_visual_north_star.png`, and models still require visual review in Godot and Android.

## Current model set
| Asset | Source | Intended use |
|---|---|---|
| Oak tree | `assets/models/voxel_oak_tree.obj` | Starter biome vegetation |
| Meadow cottage | `assets/models/meadow_cottage.obj` | First village landmark |
| Crafting bench | `assets/models/crafting_bench.obj` | Crafting interaction prop |
| Grass block | `assets/models/grass_block.obj` | Terrain surface transition sample |
| Ore outcrop | `assets/models/ore_outcrop.obj` | Resource visual prototype |
| Shared material palette | `assets/models/blockraft_palette.mtl` | Shared materials |

## Preview
Open `scenes/asset_gallery.tscn` in Godot 4 and run it directly (F6). The current gallery contains the tree, cottage, and bench; add grass and ore to the gallery after their first import/material check.

## Blender workflow
Run from the repository root with Blender 4.x installed:
```sh
blender --background --python tools/blender/build_blockraft_asset_pack.py
```
The script is intended to export GLB files and save a review `.blend`. These outputs are not claimed to exist until the script has run successfully.

## Acceptance gates
1. Import every OBJ in Godot 4; verify materials, face winding, scale, and silhouette.
2. Compare silhouette, palette, and detail density against the approved reference image.
3. Review/refine in Blender, then export GLB only after inspection.
4. Add collision and interaction behavior separately from visual geometry.
5. Test terrain seams, ore readability, collisions, draw calls, and Android frame pacing.

## Limitations
These are editable source blockouts. No claim is made that polished production art, GLB exports, or runtime/device validation are complete.
