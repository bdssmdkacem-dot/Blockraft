# Blockraft Main Menu — Acceptance Checklist

## Visual target
The exact Blockraft concept image attached in the Roblox ChatGPT Project's `source` files is the mandatory visual north star. It defines the intended hierarchy: oversized Blockraft identity, clear Play action, rich voxel landscape with a river and landmark silhouettes, a six-panel feature strip, and a restrained information footer. Do not ask the owner to upload it again or substitute generated artwork.

## Implemented in source
- `scenes/main_menu.tscn` is configured as the project start scene.
- `scripts/main_menu.gd` draws the original voxel-inspired landscape, sunrise, mountains, floating island, village, river and foreground framing.
- Main actions: Play World, Worlds, How to Play, Settings.
- A six-card feature strip now covers exploration, resources, crafting, survival, building, and planned multiplayer. The multiplayer card explicitly says it is planned, not available.
- Play opens `scenes/main.tscn`.
- Worlds only offers Meadowlands as playable; the other regions are clearly marked locked.
- Help lists current desktop controls and honestly notes that touch controls are not implemented.
- Settings explains that real graphics/audio controls are not yet wired.
- Dialog content uses a scroll container to reduce clipping on short screens.

## Required verification before acceptance
- [ ] Import in Godot 4 and confirm no parser or resource errors.
- [ ] Capture the actual running main menu at 1280×720 and compare directly with the project-source reference image.
- [ ] Test at 16:9 and narrow Android landscape sizes; check title, left menu, feature cards and footer for overlap/clipping.
- [ ] Test all four main actions and all six feature cards.
- [ ] Test Worlds dialog, locked-region explanations, close/back actions and gameplay scene transition.
- [ ] Verify font glyph coverage for icons on the target Android device.
- [ ] Check visual hierarchy and text readability on phone.
- [ ] Measure startup and frame pacing on Android.

## Honest status
The feature-strip and layout changes are committed to source, but this environment has not run Godot or produced a runtime screenshot. This is a source-level implementation step, not visual acceptance. Do not claim a successful build or Android validation until those checks have actually run.
