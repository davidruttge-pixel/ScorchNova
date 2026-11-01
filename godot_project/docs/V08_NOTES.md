# Scorch Nova 0.8

## Added
- Four terrain generation profiles, selectable using LANDSCHAFT (starts a new match).
- Persistent JSON save/load via `user://scorchnova_save.json`, available at stable turn boundaries.
- Local tournament scoreboard: first participant to three match wins gets tournament victory message.
- Menu action to load a saved match.

## Caveats
- Tournament scoreboard stays in memory between matches and is included in saves, but has no dedicated reset button.
- Save/load uses JSON and is not backward compatible with earlier prototypes.
- Local hotseat only, no network multiplayer.
- No Godot runtime or Android device testing was performed in this environment.
- Save file validation is basic; malformed save data may still cause runtime errors.

## Suggested tests
- Start all four landscapes; verify tanks are on terrain.
- Fire all 16 weapons, including delayed effects, before saving.
- Save on human turn, restart, load and compare inventory, cash, HP and terrain.
- Save during AI waiting turn and verify AI resumes.
- Play several matches and verify three-win tournament announcement.
- Test on an Android device in landscape orientation with small and large displays.
