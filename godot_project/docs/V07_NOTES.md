# Version 0.7 – Economy, AI and rule presets

- Three game presets via REGELN: Classic (start $250, +$35 per turn, wind ±40), Rich ($500, +$55, wind ±20), Survival ($150, +$20, wind ±75). Changing presets restarts the match.
- New shop upgrades: armor (12% less explosion damage per level), firepower (15% more explosion damage per level), engine (reserved for future movement mechanics, currently no gameplay effect). Upgrade caps: 3. The engine upgrade is experimental and should not be purchased expecting movement yet.
- CPU now buys shields, firepower and cluster ammunition under certain difficulty and budget conditions.
- AI weapon choice uses available cluster ammo when the predicted shot is close.
- Economy rewards use the selected rules preset.

## Known limitations
No Godot executable or Android emulator/device was available for runtime verification. No APK has been produced. The AI remains a grid-search ballistic solver, not a full tactical opponent. Weapon behavior is not a one-to-one recreation of the original game. Upgrade firepower currently applies to all blast events owned by the current shooter.
