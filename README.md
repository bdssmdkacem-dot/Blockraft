# Blockraft

An original voxel sandbox game prototype, planned for Android first using Godot 4.

## Mandatory visual reference
The project owner approved the original 1536×1024 Blockraft concept image attached in the Roblox ChatGPT Project's `source` files as the mandatory visual north star. Read [source/REFERENCE_IMAGE.md](source/REFERENCE_IMAGE.md) and [docs/VISUAL_ART_DIRECTION.md](docs/VISUAL_ART_DIRECTION.md) before creating or integrating art. The PNG is available in the ChatGPT project context but is not stored as a binary in this GitHub repository; do not claim it is committed here or that visual matching has passed without actual Godot screenshots.

## Main menu
The project starts at `scenes/main_menu.tscn`. The menu is drawn in `scripts/main_menu.gd`; Play World opens the prototype scene, while Worlds, How to Play, and Settings open informational dialogs. Only the Meadowlands is playable in this prototype. See [docs/MAIN_MENU_ACCEPTANCE.md](docs/MAIN_MENU_ACCEPTANCE.md) for required checks.

## First 3D assets
The first original OBJ models are in `assets/models/`: voxel oak tree, meadow cottage, and crafting bench, with a shared MTL palette. Open [scenes/asset_gallery.tscn](scenes/asset_gallery.tscn) in Godot 4 to inspect them. See [docs/FIRST_3D_ASSET_SET.md](docs/FIRST_3D_ASSET_SET.md). These are early source meshes, not visually accepted production assets; the north-star image and runtime/mobile reviews are still required.

## Open in Godot
1. Install Godot 4.x.
2. Clone/download this repository.
3. Import the folder containing `project.godot`.
4. Run the main scene.

## Honest status
This is an early prototype, not a finished game or Android APK. It has not yet been validated in the Godot runtime. Mobile touch controls and production chunk meshing are still required.

## Acceptance gates
1. Confirm the project imports and runs without parse/runtime errors in Godot 4.
2. Test movement, collisions, mining, and placement.
3. Implement reliable save/load including deleted blocks.
4. Replace one-node-per-block rendering with chunk meshes and face culling.
5. Add mobile joystick/look zones and touch action buttons.
6. Export and test on a real Android device.
7. Verify the original reference PNG is committed at the canonical path and visually compare actual in-engine screenshots against it.