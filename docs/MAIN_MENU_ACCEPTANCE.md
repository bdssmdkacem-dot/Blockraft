# Blockraft Main Menu — Acceptance Checklist

## Visual target
The exact image attached by the owner on 2026-10-12 is the mandatory visual north star. It defines the intended composition: cinematic voxel valley at golden hour; oversized BLOCKRAFT identity; compact left-side actions; visible river, waterfall, village/castle and floating islands; six tall illustrated feature panels; and a restrained bottom feature bar. Do not ask the owner to upload it again or substitute generated artwork.

## Implemented in source
- `scenes/main_menu.tscn` is configured as the project start scene.
- `scripts/menu_world_3d.gd` renders the voxel panorama in a dedicated SubViewport; the camera is oriented after entering the SceneTree so the world geometry is actually in view.\n- `scripts/main_menu.gd` layers the title/actions over the world and positions six feature cards above a separate footer band.
- Main actions: Play World, Worlds, How to Play, Settings.
- A six-card feature strip covers exploration, resources, crafting, survival, building, and planned multiplayer. The multiplayer card explicitly says it is planned, not available.
- Play opens `scenes/main.tscn`.
- Worlds only offers Meadowlands as playable; the other regions are clearly marked locked.
- Help lists current desktop controls and honestly notes that touch controls are not implemented.
- Settings explains that real graphics/audio controls are not yet wired.
- Dialog content uses a scroll container to reduce clipping on short screens.

## Automated verification
- [x] Godot 4 project import and script/resource parsing passed in GitHub Actions.
- [x] Main menu and gameplay scenes launched headlessly in GitHub Actions.
- [x] Structural acceptance test passed: six feature cards, four primary actions, and Worlds/Help/Settings dialogs detected.
- [x] Each feature card has a button hit area connected to an action signal.
- [x] Automated acceptance test exercised the Play World scene transition and verified feature-card action signal wiring.
- [x] CI captures the rendered main menu at 1280×720 and uploads `blockraft-main-menu-capture`; the capture waits for multiple rendered frames.

## Required visual/device verification before acceptance
- [ ] Review the newest CI screenshot at 1280×720 against the mandatory source reference; confirm the 3D landscape is visible and not only the sky.
- [ ] Test 16:9 and narrow Android landscape sizes; check title, left menu, feature cards and footer for overlap/clipping.
- [ ] Verify icon glyph coverage and text readability on the target Android device.
- [ ] Test touch input and startup/frame pacing on Android. Touch controls are not implemented yet.
- [ ] Check visual hierarchy and confirm the world and cards meet the reference quality bar.

## Honest status
The first rendered 1280×720 capture after the camera fix confirmed that 3D geometry was visible, but the composition still fell well short of the approved reference: the sky was flat, the landscape read as oversized pale blocks, and the footer lacked a dedicated dark band. The next iteration widens the camera view, aims farther into the valley, strengthens the sky palette, widens the river, adds a second floating island, enlarges the castle silhouette, and adds a separate footer band. Review the latest CI screenshot before accepting these changes. Android device review and touch controls remain outstanding.
