# Blockraft

An original voxel sandbox game prototype, planned for Android first using Godot 4.

## Current prototype scope
- Procedurally generated block terrain and simple trees.
- First-person movement and jumping (desktop keyboard/mouse for this first checkpoint).
- Raycast-based block mining and placement.
- Initial local world save prototype.

## Main menu
The project now starts at `scenes/main_menu.tscn`. The menu is drawn in `scripts/main_menu.gd`; Play World opens the existing prototype scene, while Worlds, How to Play, and Settings open informational dialogs. Only the Meadowlands is playable in this prototype. See [`docs/MAIN_MENU_ACCEPTANCE.md`](docs/MAIN_MENU_ACCEPTANCE.md) for the required visual and runtime checks. The approved visual reference is still required at `assets/reference/blockraft_visual_north_star.png`; do not claim reference matching until the original image is committed and compared against a real Godot screenshot.

## First 3D assets
The first original OBJ models are now in `assets/models/`: a voxel oak tree, meadow cottage, and crafting bench, with a shared MTL palette. Open [`scenes/asset_gallery.tscn`](scenes/asset_gallery.tscn) in Godot 4 and run it directly to inspect the models together. See [`docs/FIRST_3D_ASSET_SET.md`](docs/FIRST_3D_ASSET_SET.md) for scope and acceptance gates. These are early source meshes, not yet visually accepted production assets; the original north-star reference and runtime/mobile reviews are still required.

## Open in Godot
1. Install Godot 4.x.
2. Clone/download this repository.
3. Import the folder containing `project.godot`.
4. Run the main scene.

## Honest status
This is an early prototype, not a finished game or Android APK. It has not yet been validated in the Godot runtime. Persistence needs a proper world-diff format that records deletions, and mobile touch controls are not implemented.

## Acceptance gates
1. Confirm the project imports and runs without parse/runtime errors in Godot 4.
2. Test player movement, collisions, mining, and placement.
3. Implement reliable save/load including deleted blocks.
4. Replace one-node-per-block rendering with chunk meshes and face culling.
5. Add mobile joystick/look zones and touch action buttons.
6. Export and test on a real Android device.
