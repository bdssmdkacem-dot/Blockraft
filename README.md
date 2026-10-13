# Blockraft

An original voxel sandbox game prototype, planned for Android first using Godot 4.

## Mandatory visual reference

The exact owner-approved visual north star is committed at [assets/reference/blockraft_visual_north_star.png](assets/reference/blockraft_visual_north_star.png). This is the source of truth for the main-menu composition and art direction; do not replace it with generated or approximate artwork. Read [source/REFERENCE_IMAGE.md](source/REFERENCE_IMAGE.md) and [docs/VISUAL_ART_DIRECTION.md](docs/VISUAL_ART_DIRECTION.md) before creating or integrating art.

## Main menu

The project starts at `scenes/main_menu.tscn`. `scripts/menu_world_3d.gd` builds the 3D voxel panorama in a dedicated SubViewport; `scripts/main_menu.gd` layers the Blockraft identity, primary actions, six feature cards, and bottom information band over it. The menu is being rebuilt against the owner-approved cinematic reference, not treated as a small cosmetic tweak. Play World opens the prototype scene, while Worlds, How to Play, and Settings open informational dialogs. Only the Meadowlands is playable in this prototype. See [docs/MAIN_MENU_ACCEPTANCE.md](docs/MAIN_MENU_ACCEPTANCE.md) for required checks.

## First 3D assets

The first original OBJ models are in `assets/models/`: voxel oak tree, meadow cottage, crafting bench, grass block, and ore outcrop, with a shared MTL palette. Open [scenes/asset_gallery.tscn](scenes/asset_gallery.tscn) in Godot 4 to inspect the first five models. See [docs/FIRST_3D_ASSET_SET.md](docs/FIRST_3D_ASSET_SET.md). These are early source meshes, not visually accepted production assets; in-engine and mobile reviews remain required.

## Replica-inspired development records

The implementation is tracked through a project-specific recon, feature acceptance matrix, architecture notes, and test plan in [`replica/`](replica/recon.md). These are adapted workflow artifacts; the Claude-specific Replica Skill itself is not installed in the Godot project.

## Android prototype

GitHub Actions exports an installable Android debug APK for sideload testing and verifies the APK archive, signature, manifest, and ARM64/ARMv7 native libraries before uploading the artifact. The workflow runs on relevant source, scene, asset, test, documentation, and workflow changes pushed to `main`. The APK is a development build, not a Play Store release. A successful export does not replace real-device installation, touch-input, or performance testing.

## Open in Godot

1. Install Godot 4.x.
2. Clone/download this repository.
3. Import the folder containing `project.godot`.
4. Run the main scene.

## Honest status

This is an early prototype, not a finished game. Godot CI verifies project import, scene startup, menu interactions, gameplay interactions/persistence checks, and a rendered 1280×720 menu capture. The latest visual iteration improves contrast and framing, but the landscape composition is not yet accepted against the exact reference. Android debug APK export is automated; real-device verification and production chunk meshing remain required.

## Acceptance gates

1. Confirm the project imports and runs without parse/runtime errors in Godot 4.
2. Test movement, collisions, mining, and placement on desktop and Android.
3. Implement reliable save/load including deleted blocks.
4. Replace one-node-per-block rendering with chunk meshes and face culling.
5. Validate mobile joystick/look zones and touch action buttons on a real device.
6. Install and test the exported APK on a real Android device.
7. Compare actual in-engine screenshots against [the committed visual reference](assets/reference/blockraft_visual_north_star.png) before accepting the main-menu art.
