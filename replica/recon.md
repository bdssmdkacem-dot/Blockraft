# Replica Recon — Blockraft

## Goal
Deliver an original voxel sandbox prototype for Android, inspired by the interaction model of block-building games without copying Minecraft branding, proprietary textures, characters, sounds, or UI.

## Repository snapshot
- Engine: Godot 4, GDScript.
- Entry scene: `res://scenes/main_menu.tscn`.
- Gameplay scene: `res://scenes/main.tscn`.
- World logic: `scripts/main.gd`.
- Player and raycast interactions: `scripts/player.gd`.
- Main menu 3D panorama: `scripts/menu_world_3d.gd`.
- Existing persistence: JSON snapshot at `user://world_blocks.json`.
- CI: Godot headless validation and rendered menu screenshot; Android export is being added separately.

## Current capabilities
- Procedurally generated, deterministic block terrain and simple trees.
- First-person CharacterBody3D movement, gravity and jump on desktop.
- Raycast-based block mining and placement.
- Local save/load of the block snapshot.
- Original OBJ assets and six SVG feature-card illustrations.
- Main menu actions and structural/responsive acceptance checks.

## Gaps and risks
1. Existing world uses one StaticBody3D, MeshInstance3D and CollisionShape3D per block; this is not production-scale.
2. Touch input and Android APK export must pass CI and then be tested on a real device.
3. Save/load has basic validation but no version migration, atomic write, or corrupted-save recovery.
4. Automated gameplay interaction tests are still needed.
5. The owner-approved visual reference is recorded in `source/REFERENCE_IMAGE.md`, but its exact PNG binary is not yet in this repository. Do not substitute generated artwork or claim visual parity without comparing the original.
6. No Play Store release signing is configured; generated APKs are debug sideload builds only.

## Priorities
P0: Godot parse/import, menu/gameplay startup, touch controls, Android debug APK artifact.
P1: gameplay regression tests for mine/place/save/load and real-device validation.
P2: chunk meshing with exposed-face culling and reduced collision complexity.
P3: visual comparison against the approved reference, followed by asset refinement.

## Acceptance rule
A green CI job proves only the checks that ran. It does not prove visual parity, real-device input, performance, or production readiness.
