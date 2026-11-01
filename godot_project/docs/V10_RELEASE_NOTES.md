# Scorch Nova v1.0 — source milestone (not a certified release)

## Added
- Three synthesized original WAV sound effects (fire, impact, victory), optional mute button.
- Automatic save at the end of a resolved turn; manual save/load remains available.
- Additional defensive checks when loading corrupted JSON player records.
- Retains all 16 prototype weapons, local multiplayer, AI, four landscapes, tournament scores and touch HUD.

## Known limitations
- Godot engine/runtime was unavailable for automated import and gameplay tests.
- No Android APK has been compiled, signed, or tested.
- This is **not** a feature-complete, exact recreation of Scorched Earth 1.5; several weapons and systems are simplified.
- Local multiplayer only; no online networking, liquid simulation or exhaustive accessibility QA.
- Sound effects are intentionally minimal and may need mixing adjustments.

## Acceptance gates before publishing an APK
1. Open in Godot 4.2+ and verify no script parser errors.
2. Run full two-player match, each weapon, each landscape, all difficulty settings.
3. Verify auto-save and reload at turn boundaries, corrupt save recovery.
4. Build signed Android APK with matching export templates and SDK.
5. Test on at least two physical Android phones, including suspend/resume and touch targets.

## Source license
Original code and generated sound effects provided under the repository MIT license.
