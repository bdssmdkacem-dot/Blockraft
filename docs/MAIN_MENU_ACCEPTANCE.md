# Blockraft Main Menu — Acceptance Checklist

## Visual target

The exact owner-approved image at [`assets/reference/blockraft_visual_north_star.png`](../assets/reference/blockraft_visual_north_star.png) is the mandatory visual north star. It defines the intended composition: cinematic voxel valley at golden hour; oversized BLOCKRAFT identity; compact left-side actions; visible river, waterfall, village/castle and floating islands; six illustrated feature panels; and a restrained bottom feature bar. Do not replace it with generated artwork.

## Implemented in source

- `scenes/main_menu.tscn` is configured as the project start scene.
- `scripts/menu_world_3d.gd` renders the voxel panorama in a dedicated SubViewport; the camera is oriented after entering the SceneTree so the world geometry is visible.
- `scripts/main_menu.gd` layers the title/actions over the world and positions six feature cards above a separate footer band.
- Main actions: Play World, Worlds, How to Play, Settings.
- A six-card feature strip covers exploration, resources, crafting, survival, building, and planned multiplayer. The multiplayer card explicitly says it is planned, not available.
- Play opens `scenes/main.tscn`.
- Worlds only offers Meadowlands as playable; the other regions are clearly marked locked.
- Gameplay has platform-aware instructions and on-screen movement/look/action controls for mobile builds.
- Settings explains which graphics/audio controls are not yet wired.
- Dialog content uses a scroll container to reduce clipping on short screens.

## Automated verification

- [x] Godot 4 project import and script/resource parsing passed in GitHub Actions.
- [x] Main menu and gameplay scenes launched headlessly in GitHub Actions.
- [x] Structural acceptance test passed: six feature cards, four primary actions, and Worlds/Help/Settings dialogs detected.
- [x] Each feature card has a button hit area connected to an action signal.
- [x] Automated acceptance test exercised the Play World scene transition and verified feature-card action signal wiring.
- [x] CI captures the rendered main menu at 1280×720 and uploads `blockraft-main-menu-capture`.
- [x] Android debug APK export, archive integrity, signing, manifest presence, and ARM64/ARMv7 library checks passed in GitHub Actions.

## Required visual/device verification before acceptance

- [ ] Compare the newest CI screenshot directly with the committed reference image.
- [ ] Break up the current continuous stepped mountain ridge so the valley, river/waterfalls, village/castle, and floating islands read clearly above the feature cards.
- [ ] Test 16:9 and narrow Android landscape sizes; check title, left menu, feature cards and footer for overlap/clipping.
- [ ] Verify icon glyph coverage and text readability on the target Android device.
- [ ] Test touch input and startup/frame pacing on Android.
- [ ] Confirm visual hierarchy and quality against the reference; automated build success alone is insufficient.

## Honest status

The current rendered capture has stronger contrast and improved camera framing than the first pass, and the 3D world is visible. However, the mountain row still reads as a broad continuous wall and the river, village, waterfalls, and castle are not prominent enough to meet the reference quality bar. The next visual iteration should reshape the ridge into separated stepped peaks and expose the valley landmarks without obscuring the menu. Real-device review remains outstanding.
