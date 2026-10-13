# Replica Architecture — Blockraft

## Current runtime flow

```text
MainMenu
  ├─ 3D SubViewport → VoxelMenuWorld
  ├─ Play World → Main
  └─ Worlds / Help / Settings → informational dialogs

Main
  ├─ GeneratedWorld (block dictionary + per-block physics/render nodes)
  ├─ Player (CharacterBody3D + Camera3D + raycast interactions)
  ├─ HUD
  └─ user://world_blocks.json (world snapshot)
```

## Design constraints
- Keep Godot 4 and GDScript; avoid introducing a second engine.
- Preserve desktop controls while adding touch-specific controls.
- Keep the initial Android export a debug/sideload artifact; do not add release keystore credentials to the repository.
- Use original Blockraft assets and the exact approved reference when available.
- Avoid breaking the existing world-save format without a migration path.

## Next architecture step: chunked world
1. Store blocks by integer grid coordinate and block type as the source of truth.
2. Partition the grid into fixed-size chunks (initial target: 16×16×height).
3. Generate mesh faces only where the neighboring cell is empty or transparent.
4. Maintain simplified chunk collision geometry rather than a collision node for every block.
5. Mark affected chunks dirty when mining/placing, then rebuild only those chunks.
6. Persist world seed plus edits/deletions; write saves atomically and version the schema.

Do not start chunk conversion until gameplay acceptance tests exist, so the renderer change can be measured against a stable behavior baseline.
