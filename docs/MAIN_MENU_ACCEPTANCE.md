# Blockraft Main Menu — Acceptance Checklist

## Visual target
The exact Blockraft concept image attached in the Roblox ChatGPT Project's `source` files is the mandatory visual north star. It defines the intended hierarchy: oversized Blockraft identity, clear Play action, rich voxel landscape with a river and landmark silhouettes, a six-panel feature strip, and a restrained information footer. Do not ask the owner to upload it again or substitute generated artwork.

## Implemented in source
- `scenes/main_menu.tscn` is configured as the project start scene.
- `scripts/main_menu.gd` draws the voxel-inspired landscape, sunrise, mountains, floating island, village, river and foreground framing.
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
- [ ] Test the actual Play World scene transition and exercise each feature-card action end-to-end.
- [ ] Capture the running main menu and compare directly with the project-source reference image. The previous headless screenshot-readback step hung, so it was removed from CI rather than misreported as successful.

## Required visual/device verification before acceptance
- [ ] Review an actual screenshot at 1280×720 against the mandatory source reference.
- [ ] Test 16:9 and narrow Android landscape sizes; check title, left menu, feature cards and footer for overlap/clipping.
- [ ] Verify icon glyph coverage and text readability on the target Android device.
- [ ] Test touch input and startup/frame pacing on Android. Touch controls are not implemented yet.
- [ ] Check visual hierarchy and confirm the world and cards meet the reference quality bar.

## Honest status
GitHub Actions passed the current headless import, scene-launch, and structural acceptance checks on commit `e1f2cc1909e70e216c144ca8591cd11b45f7a234`. The acceptance test was then strengthened in a follow-up commit to check feature-card signal wiring and dialog opening; that newer commit must complete its own workflow before those extra checks are considered verified. No runtime screenshot or Android device test is available yet. A successful headless run is not visual acceptance.
