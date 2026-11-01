# Scorch Nova – Entwicklungsstand v0.2

Neue Waffen: MIRV (sechs ballistische Teilgeschosse), Roller (Kettenexplosion entlang des Geländes), Dirt-Bombe (Geländeaufbau), Death Head (Flächenbombardement).

Neues Verteidigungssystem: Fallschirme im Shop; bei starkem Geländeabfall wird ein Fallschirm verbraucht, andernfalls entsteht Fallschaden. Bereits vorhandene Schilde absorbieren Explosionsschaden.

Hinweise: Das ist weiterhin ein Prototyp. Roller und Death Head sind vereinfachte Neuinterpretationen, keine verifizierten 1:1-Reproduktionen der Originalmechaniken. Android-Export und tatsächliche Laufzeit sind noch nicht auf Hardware getestet. Weitere Arbeit: zuverlässige Physik-Tests, Shop-UI für kleine Displays, Hotseat, persistente Kampagne, umfassende Waffen-/Schadensregeln.

## v0.3
Hotseat mit 2–6 Spielern, konfigurierbare KI-Anzahl, separate Spielerinventare und verbesserte Zugrotation. KI unterstützt Schussrichtungen nach links und rechts. UI-Breiten reduziert.

## v0.4 – Waffen, KI und Touch
- Vier weitere Waffen: Bouncer, Erdbeben, Laser und Super-MIRV (13 Waffen insgesamt).
- KI-Schwierigkeitsgrade leicht, normal, schwer.
- Richtungstaste für menschliche Spieler; KI zielt auf beiden Seiten.
- Horizontal scrollbar angeordnete Touch-Bedienleiste.
- Schutz vor sofortiger Eigenkollision beim Abschuss und Trefferprüfung nur für lebende Panzer.
- Hinweis: Noch nicht mit Godot-Editor oder Android-Gerät getestet.

## 0.5
- Added full-screen start/pause menu with restart and resume.
- Added dark UI theme and touch-sized menu actions.
- Added animated explosion sparks and tank wheel details.
- Paused simulation while menu is visible.

## v0.6
- Three new weapon modes (16 total): shrapnel rain, drilling projectile, large dirt mound.
- Bounded terrain slope relaxation after crater deformation.
- Runtime and Android device tests still pending.

## v0.7
- Configurable match economy/wind presets.
- Armor, firepower and experimental engine upgrades in shop.
- CPU automatic shopping and improved weapon selection.

## v1.0
- Three generated sound effects and sound toggle.
- Automatic save after resolved turns.
- Defensive player-record validation on load.
- Explicit release readiness checklist.
