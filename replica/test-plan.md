# Replica Test Plan — Blockraft

## CI checks
- Import the Godot project and parse all scripts/resources.
- Launch the main menu and gameplay scene headlessly.
- Exercise menu action wiring and responsive layout at the tested viewport sizes.
- Capture a rendered 1280×720 menu image and inspect it rather than treating file creation as visual acceptance.
- Export the Android debug APK; verify the output exists and passes ZIP integrity checks.

## Gameplay regression checks to add
- [ ] Generated terrain contains expected block kinds and the player spawns above ground.
- [ ] Mining removes only the raycast-targeted block.
- [ ] Placement adds a block adjacent to the hit face and rejects occupied/player-overlap positions.
- [ ] Save then reload preserves placed blocks and preserves mined-block deletions.
- [ ] Invalid or truncated save files fail safely without crashing.
- [ ] Desktop WASD, jump, mouse look, mining and placement remain functional.
- [ ] Android directional controls, jump hold/release, drag look, mine and place buttons work.
- [ ] Repeated touch presses do not leave movement or jump latched after release.

## Real Android smoke test
1. Install the artifact APK on a physical Android phone.
2. Launch into the main menu and tap Play World.
3. Walk forward/back/left/right; verify collision and jumping.
4. Drag in the look area; verify camera movement without accidental rotation when pressing action buttons.
5. Mine a block and place it on a neighboring face.
6. Exit and relaunch; verify edits and deletions persist.
7. Watch for crashes, overheating, low frame rate, clipped controls and unreadable text.

## Evidence to retain
- GitHub Actions run URL and APK artifact name.
- Captured menu screenshot.
- Device model / Android version and a short pass/fail checklist.
- Any runtime logs for failures.
