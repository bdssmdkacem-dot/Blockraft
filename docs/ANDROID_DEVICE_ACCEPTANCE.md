# Android Device Acceptance — PR #7

## Release gate status

**Status: NOT RUN — blocks Release Candidate sign-off.**

The automated Godot and Android CI checks are not a substitute for a real Android device session. This checklist must be completed on the target phone using the exact debug APK artifact built from the candidate commit. Do not mark a test as passed from a desktop/headless run.

## Candidate identity

- Repository: `bdssmdkacem-dot/Blockraft`
- PR: `#7`
- Branch: `fix/player-spawn-ground-safety`
- Candidate commit: record the exact 40-character SHA installed
- APK type: CI debug APK (not a production-signed release)
- Device model / Android version / screen resolution: record before testing

## Test procedure

| ID | Test | Pass criteria | Result / evidence |
|---|---|---|---|
| A01 | Clean install and launch | APK installs, app opens without crash, main menu is fully visible and controls are tappable | NOT RUN |
| A02 | Player spawn and floor collision | Player appears on the spawn pad, feet settle on the ground, walking does not fall through or clip through the floor | NOT RUN |
| A03 | Touch movement | Virtual movement control moves in all directions; releasing it stops movement without a stuck input | NOT RUN |
| A04 | Camera look | Dragging the look area changes yaw and pitch smoothly; releasing the touch stops camera input | NOT RUN |
| A05 | Jump / mine / place | Jump triggers once; mining removes the aimed block and awards exactly one item; placing consumes exactly one selected item | NOT RUN |
| A06 | Placement safety | Occupied and out-of-reach placements are rejected without consuming inventory | NOT RUN |
| A07 | Hotbar and backpack | Slot selection, counts, selected slot and backpack tier remain correct while switching items and reopening the bag UI | NOT RUN |
| A08 | Depot storage | Deposit and withdraw preserve exact item types and quantities; no duplication or loss | NOT RUN |
| A09 | Save and reopen | Make at least two world edits and inventory changes, wait for autosave, background/resume, force-stop the app, relaunch, and verify the same world and inventory return | NOT RUN |
| A10 | Chunk streaming | Walk across at least 5–10 chunk boundaries; terrain and collision load without holes, persistent missing chunks or severe stalls | NOT RUN |
| A11 | Stability / performance | Play for at least 10 minutes; no crash, stuck controls, unbounded slowdown or abnormal heating; record observed frame pacing and any stutter | NOT RUN |
| A12 | Small-screen UI | Health, hunger, backpack label, hotbar and touch controls remain readable and do not overlap or clip on the phone display | NOT RUN |

## Required evidence

Attach:
1. Device model, Android version and display resolution.
2. Exact installed commit SHA and APK SHA-256.
3. Screenshots or a short screen recording of menu, spawn, touch movement/look, mining/building and the reopened world.
4. Any crash log, Android logcat excerpt or reproducible failure steps.
5. A result for every row: PASS, FAIL or BLOCKED. A blocked row is not a pass.

## Sign-off rule

Any failure in spawn/collision, touch/camera, mining/building, inventory integrity, save/reopen or app stability is a release blocker. Keep PR #7 as draft and do not merge or publish until the device evidence is reviewed.