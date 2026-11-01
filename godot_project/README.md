# Scorch Nova — Godot 4 Android Artillery Prototype

A self-contained, original Godot 4.x turn-based artillery prototype inspired by classic artillery games. No external assets, plugins or copyrighted Scorched Earth source code are included.

## Run
1. Install Godot 4.2 or newer (4.3/4.4 recommended).
2. Import `project.godot` in the Godot Project Manager.
3. Press F6/F5 to start the main scene/project.
4. Adjust angle and power using the sliders; select a weapon; press **FEUER!**.
5. Buy extra ammunition or shield with **SHOP**. **NEU** restarts.

## Current playable features
- Two tanks, human vs CPU, alternating turns.
- Procedurally generated, destructible 2D heightmap with craters.
- Wind and gravity affecting ballistic trajectories.
- Five weapon modes: grenade, heavy, cluster, napalm-style scatter, atomic blast.
- HP, shield absorption, finite specialty ammo, cash rewards and a shop.
- Trajectory preview, animated explosions, mobile-friendly large touch controls.
- Dynamic viewport scaling to 1280x720, landscape mode, GL Compatibility renderer.

## Limitations (important)
This is a **first playable milestone**, not a finished feature-complete Scorched Earth remake. Features not yet implemented include original weapon-by-weapon fidelity, dirt mounds, bouncing projectiles, rollers, guidance, parachutes, liquid simulation, original economic balancing, 2–10 player lobby, multiplayer networking, persistent saves, sound and accessibility. The prototype has not been run on a physical Android device. Damage, AI and terrain are intentionally simplified.

## Android export
1. In Godot, install the matching Android export templates (`Editor > Manage Export Templates`).
2. Configure Android SDK / JDK paths under `Editor > Editor Settings > Export > Android` (consult the Godot documentation for your version).
3. Add an Android export preset (`Project > Export > Add... > Android`).
4. Set package ID e.g. `org.example.scorchnova`, version and signing keys as appropriate.
5. Export APK for sideloading; use AAB and release signing for Google Play.

The export preset is intentionally not checked in because Android signing, SDK configuration and device compatibility depend on the user's build environment.

## Files
- `project.godot`: project settings, GL compatibility and landscape viewport.
- `scenes/main.tscn`: game entry point.
- `scripts/game.gd`: gameplay loop, UI, projectiles, AI, weapons, economy, rendering.
- `scripts/terrain.gd`: heightmap generation, deformation and terrain rendering.
- `docs/ROADMAP.md`: feature completion roadmap and validation plan.

## Licensing
Original prototype code: MIT (see LICENSE). Names of weapons are descriptive; no original game sprites or proprietary content were copied. Review third-party repository licenses before importing any third-party source or art.

## Update v0.2

Neue Waffen: MIRV, Roller, Dirt-Bombe, Death Head. Fallschirme und Fallschaden bei Geländeabsenkung. Details unter `docs/CHANGELOG.md`.

## Update v0.3 – Hotseat und mehrere KI-Gegner
- 2 bis 6 Teilnehmer; Anzahl per **SPIELER**-Taste ändern (startet neue Partie).
- 0 bis (Spieleranzahl - 1) KI-Teilnehmer; Anzahl per **CPU**-Taste ändern (startet neue Partie).
- Abwechselnde lokale Touch-Steuerung, überspringt ausgeschiedene Teilnehmer.
- Jeder Spieler hat eigenes Geld, Munition, Schild, Winkel, Kraft und Fallschirme.
- KI zielt auf den nächsten überlebenden Gegner und schießt von links oder rechts.
- Verbesserte Statusanzeigen und kompaktere untere Bedienleiste.

**Wichtig:** Diese Version ist nicht auf einem echten Android-Gerät oder in einer Godot-Laufzeit getestet. Die Steuerung ist für 1280×720 Querformat ausgelegt; sehr kleine Displays können weitere Anpassungen erfordern. Kein Netzwerkmodus und keine vollständige Originalmechanik-Abdeckung.

## Update v0.4
13 Waffen, KI-Stufen, Richtungswechsel und horizontal scrollbare Touch-Leiste. Siehe `docs/V04_TESTPLAN.md`. **Nicht als fehlerfrei validiert:** In dieser Umgebung stand kein Godot-Editor und kein Android-Gerät zur Verfügung.

## v0.5 update
Full-screen start/pause menu, dark control theme, improved tank details, animated explosion sparks. Import `project.godot` with Godot 4.2+. This project has not been runtime-tested or exported to APK in this environment. See `docs/V05_NOTES.md`.

## v0.6 update
16 Waffen mit Splitterregen, Bohrer und Mega-Dirt; zusätzliche begrenzte Geländeglättung. Noch kein Android-Laufzeittest oder APK-Export. Siehe `docs/V06_NOTES.md`.

## v0.7 update
Economy and AI improvements: three rule presets, armor/firepower upgrades, experimental engine upgrade (not yet functional), CPU purchases and tactical cluster selection. See `docs/V07_NOTES.md`. Not runtime-tested in Godot or Android.

## v0.8 update
Four procedural landscape profiles, local tournament score (first to three wins), and JSON save/load for stable turn boundaries. A save can be loaded from the main menu. See `docs/V08_NOTES.md`. Not tested with the Godot engine or on Android; **not an APK**.

## v0.9 – Stabilization pass
- Fix explosion damage being calculated after terrain deformation.
- Add projectile lifetime timeout (18 seconds) to prevent stuck rounds.
- Reject malformed save arrays and normalize tournament score lengths.
- Add static regression checks and manual Android QA checklist.
- **Not runtime-certified:** Godot 4 and Android APK toolchains were unavailable in the authoring environment.

## v1.0 source milestone
Added generated sound effects, mute button, end-of-turn autosave and save-file validation. **Not a validated Android release or an APK.** See `docs/V10_RELEASE_NOTES.md`.
