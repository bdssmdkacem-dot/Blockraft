# First 3D Asset Set — Blockraft

## Status

These are the first authored, importable voxel-style 3D blockout assets. They are **not yet accepted production art**: the approved north-star image is still missing from `assets/reference/blockcraft_visual_north_star.png`, and these models have not yet been checked in a running Godot viewport or on Android.

## Initial models

| Asset | Source | Intended use | Current dimensions / silhouette |
|---|---|---|---|
| Voxel oak tree | `assets/models/voxel_oak_tree.obj` | Starter biome vegetation | Layered canopy, visible trunk, chunky readable foliage |
| Meadow cottage | `assets/models/meadow_cottage.obj` | First village / starter landmark | Plaster walls, timber frame, blue windows, stepped roof, stone footing |
| Crafting bench | `assets/models/crafting_bench.obj` | First crafting station | Timber body, framed top, metal details, gold focal detail |
| Shared material palette | `assets/models/blockraft_palette.mtl` | Consistent model materials | Original bark, leaf, stone, plaster, roof, glass, iron, and gold materials |

## Preview

Open `scenes/asset_gallery.tscn` in Godot 4 and run it directly (F6). This scene is an isolated asset preview and does not replace the game's main menu or gameplay scene.

## Next production steps

1. Import and visually inspect all three OBJ models in Godot 4; repair material/import issues.
2. Compare their scale, palette, silhouette, and detail density with the original approved reference once it is committed.
3. Refine bevels and face/material variation in Blender, then export optimized GLB assets if that workflow is available.
4. Add collision meshes and integrate the accepted tree and cottage into a small authored starter area; keep the crafting bench as a clear gameplay landmark.
5. Test draw calls, collision behavior, readability at phone resolution, and frame pacing on Android.

## Important limitation

OBJ models are editable source meshes, not a claim that a polished Blender project, optimized GLB exports, collision setup, or device validation already exists.
