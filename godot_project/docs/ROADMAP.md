# Roadmap toward original-mechanics coverage

## Milestone 1 — playable core (included)
- [x] Procedural landscape, craters, gravity/wind, shots, AI, HP/shields
- [x] Five weapon archetypes, shop and turn economy
- [x] Touch-sized controls, landscape 16:9, compatibility renderer
- [ ] Android device validation (requires device/build toolchain)

## Milestone 2 — combat fidelity
- [ ] Catalog and test each Scorched Earth 1.5 weapon and physics behavior
- [ ] Dirt/terrain-adding attacks, rollers, bouncing, guidance, interceptors
- [ ] Fire propagation, fluid-like napalm, falling tanks, terrain settling
- [ ] Explosions and damage benchmarked against documented reference cases

## Milestone 3 — full match systems
- [ ] 2–10 local players, configurable match rules, teams and AI personalities
- [ ] Full shields, parachutes, batteries, fuel, armor, accessories
- [ ] Buy/sell shop, inventories, interest and pricing options
- [ ] Round progression, scores, player profiles, save/load

## Milestone 4 — polish and release
- [ ] Touch aiming gestures, responsive layouts, audio, haptics, accessibility
- [ ] Performance profiling on low-end Android devices
- [ ] Deterministic tests for ballistic trajectories and crater edge cases
- [ ] Android APK/AAB signing, smoke tests and regression testing

## Known engineering notes
- All gameplay currently runs in one scene with a separate terrain model; split into subsystems when scaling up.
- Craters are heightmap-only and cannot produce tunnels or overhangs.
- CPU uses approximate forward trajectory search with random error.
- Touch input uses Godot's emulated mouse from touch and native Control nodes.
