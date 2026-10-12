# Blockraft Main Menu — Acceptance Checklist

## Scope

The main menu is the game's first scene. It must present Blockraft as an original voxel sandbox and must not reuse Minecraft branding, textures, logos, or UI assets.

## Current implementation

- `scenes/main_menu.tscn` is configured as the project start scene.
- `scripts/main_menu.gd` draws an original voxel-inspired landscape and builds the menu controls.
- Play opens the existing `scenes/main.tscn` gameplay scene.
- Worlds opens a scrollable selection dialog. Only Meadowlands is offered as playable; other regions are explicitly locked rather than presented as finished.
- How to Play lists the current desktop controls and clearly notes that touch controls are not implemented.
- Settings reports honestly that actual audio/graphics controls are not wired yet.
- Dialogs use a scroll container to avoid clipping their content on short screens.

## Required verification before visual acceptance

- [ ] Import the project in Godot 4 and confirm there are no parser or resource errors.
- [ ] Run the project and capture a native screenshot at 1280×720.
- [ ] Open Worlds, test every option, close the dialog, and verify the background menu remains usable.
- [ ] Open How to Play and Settings, verify text is readable and scrollable on narrow/short viewports.
- [ ] Select Play World and confirm the existing gameplay scene loads.
- [ ] Test keyboard navigation and focus visibility.
- [ ] Test 16:9 landscape and a narrow Android viewport; ensure title, buttons, and dialogs are not clipped.
- [ ] Compare the screenshot directly against the approved reference image at `assets/reference/blockraft_visual_north_star.png`.

## Reference gate

The original approved reference image is currently **not present at the required repository path**. Do not substitute a newly generated image or a different project image. Preserve and commit the exact original unchanged before declaring visual matching complete.

## Honest status

The code and scene files have been committed, but this environment did not have the Godot executable available for runtime verification. Therefore the menu is implemented, not yet engine-validated or visually accepted. A successful GitHub commit is not a substitute for these checks.
