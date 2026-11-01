# v0.9 verification report

## Scope
Source-level hardening and package checks only. No Godot editor, Android SDK, emulator or device runtime was available. No APK was built.

## Changes
1. Snapshot tank coordinates before crater deformation for consistent damage.
2. Projectile maximum lifetime 18 s to prevent a turn from hanging indefinitely.
3. Validate loaded player/ammo arrays and normalize saved tournament scores.

## Manual acceptance tests required before v1.0
- Import project into Godot 4.2+; confirm zero script parse errors.
- Play a complete 2-player match; verify AI turn and damage.
- Test every one of the 16 weapons, especially MIRV, Roller, Dirt, Laser and Bouncer.
- Test 2–6 player Hotseat with 0–5 CPUs, no deadlock on elimination.
- Save and load during player and AI turns, restart the app, check persistence.
- Android landscape layout on narrow and wide phones, multi-touch and safe areas.
- Run 30-minute match with FPS and memory profiling, check resume after backgrounding.
- Export signed APK with matching Godot Android templates and Android SDK.
