# Blockraft

An original voxel sandbox game prototype, planned for Android first using Godot 4.

## Mandatory visual reference

The owner has locked the exact existing image `/Roblox/blockraft_visual_north_star.png` from the ChatGPT Roblox project file library as the visual north star. Do not ask for another upload or replace it with generated art. Read [source/REFERENCE_IMAGE.md](source/REFERENCE_IMAGE.md) and [docs/VISUAL_ART_DIRECTION.md](docs/VISUAL_ART_DIRECTION.md) before creating or integrating art.

The original PNG binary is not yet committed in this repository because raw-byte transfer from the ChatGPT project library is currently unavailable. The canonical destination is `source/reference/blockcraft_visual_north_star.png`; do not claim that file exists until the exact original PNG is committed.

## Main menu

The project starts at `scenes/main_menu.tscn`. The menu is drawn in `scripts/main_menu.gd`; Play World opens the prototype scene, while Worlds, How to Play, and Settings open informational dialogs. Only the Meadowlands is playable in this prototype. See [docs/MAIN_MENU_ACCEPTANCE.md](docs/MAIN_MENU_ACCEPTANCE.md) for required checks.

## First 3D assets

The first original OBJ models are in `assets/models/`: voxel oak tree, meadow cottage, crafting bench, grass block, and ore outcrop, with a shared MTL palette. Open [scenes/asset_gallery.tscn](scenes/asset_gallery.tscn) in Godot 4 to inspect the first five models. See [docs/FIRST_3D_ASSET_SET.md](docs/FIRST_3D_ASSET_SET.md). These are early source meshes, not visually accepted production assets; in-engine and mobile reviews remain required.

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
7. Compare actual in-engine screenshots against the exact approved image and commit that original PNG to the canonical path when binary transfer is available.
