# ScorchNova Online Multiplayer (work in progress)

This folder contains an initial Node.js/WebSocket **lobby prototype** for private invite-code rooms and public room listings (up to ten connections per room). It is not yet connected to the Godot game, and no live server has been deployed.

## Local startup
Node.js 20+ required:

```sh
cd online-server
npm install
npm start
```

HTTP endpoints: `GET /health`, `GET /rooms`. WebSocket messages: `create_room`, `join_room`, `list_rooms`, `leave_room`, `start_game`, `turn_action`.

## Required before a public launch
- Deploy to a server with HTTPS/WSS, persistent WebSocket connections and configuration for allowed browser origins.
- Connect Godot Web client to lobby, public room browser and invite code UI.
- Build an authoritative turn/game state machine on the server, including validated weapon inventory, money, movement, damage, projectile simulation and win conditions. **The current turn_action relay is not cheat-resistant or game-state synchronized.**
- Add disconnect/reconnect support, AI seats, idle timeouts, rate limiting, abuse prevention and room cleanup.
- End-to-end test on mobile devices; preserve local/offline modes.

Do not advertise this prototype as playable online multiplayer yet.
