# Blockraft

An original voxel sandbox game prototype, planned for Android first using Godot 4.

## Mandatory visual reference

The owner has locked the exact existing image `/Roblox/blockraft_visual_north_star.png` from the ChatGPT Roblox project file library as the visual north star. Do not ask for another upload or replace it with generated art. Read [source/REFERENCE_IMAGE.md](source/REFERENCE_IMAGE.md) and [docs/VISUAL_ART_DIRECTION.md](docs/VISUAL_ART_DIRECTION.md) before creating or integrating art.

The original PNG binary is not yet committed in this repository because raw-byte transfer from the ChatGPT project library is currently unavailable. The canonical destination is `source/reference/blockcraft_visual_north_star.png`; do not claim that file exists until the exact original PNG is committed.

## Main menu

The project starts at `scenes/main_menu.tscn`. `scripts/menu_world_3d.gd` builds the 3D voxel panorama in a dedicated SubViewport; `scripts/main_menu.gd` layers the Blockraft identity, primary actions, six feature cards, and bottom information band over it. The menu layout is being rebuilt against the owner-approved cinematic reference, not treated as a small cosmetic tweak. Play World opens the prototype scene, while Worlds, How to Play, and Settings open informational dialogs. Only the Meadowlands is playable in this prototype. See [docs/MAIN_MENU_ACCEPTANCE.md](docs/MAIN_MENU_ACCEPTANCE.md) for required checks.

## First 3D assets

The first original OBJ models are in `assets/models/`: voxel oak tree, meadow cottage, crafting bench, grass block, and ore outcrop, with a shared MTL palette. Open [scenes/asset_gallery.tscn](scenes/asset_gallery.tscn) in Godot 4 to inspect the first five models. See [docs/FIRST_3D_ASSET_SET.md](docs/FIRST_3D_ASSET_SET.md). These are early source meshes, not visually accepted production assets; in-engine and mobile reviews remain required.

## Replica-inspired development records

The implementation is tracked through a project-specific recon, feature acceptance matrix, architecture notes, and test plan in [`replica/`](replica/recon.md). These are adapted workflow artifacts; the Claude-specific Replica Skill itself is not installed in the Godot project.

## Android prototype

The Android touch-control and debug APK-export changes are under review in [PR #4](https://github.com/bdssmdkacem-dot/Blockraft/pull/4). Do not treat an APK as available until the export workflow succeeds and uploads the artifact. The APK is for sideload testing only; it is not a Play Store release.

## Open in Godot

1. Install Godot 4.x.
2. Clone/download this repository.
3. Import the folder containing `project.godot`.
4. Run the main scene.

## Honest status

This is an early prototype, not a finished game. Godot headless validation has passed for the current menu work, but the latest menu screenshot still requires visual acceptance and Android touch controls/APK export are awaiting their own CI and device checks. Production chunk meshing is still required.

## Acceptance gates

1. Confirm the project imports and runs without parse/runtime errors in Godot 4.
2. Test movement, collisions, mining, and placement.
3. Implement reliable save/load including deleted blocks.
4. Replace one-node-per-block rendering with chunk meshes and face culling.
5. Add mobile joystick/look zones and touch action buttons.
6. Export and test on a real Android device.
7. Compare actual in-engine screenshots against the exact approved image and commit that original PNG to the canonical path when binary transfer is available.
