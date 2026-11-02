import http from "node:http";
import { randomBytes, randomUUID } from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";

const PORT = Number(process.env.PORT || 8080);
const rooms = new Map();
const clients = new Map();
const MAX_PLAYERS = 10;
const MAX_ROOMS = 200;
const MAX_MESSAGE = 8192;
const code = () => randomBytes(4).toString("hex").toUpperCase();
const send = (ws, msg) => { if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg)); };
const safeName = (name) => String(name || "Zebra").trim().slice(0, 24).replace(/[<>]/g, "") || "Zebra";
function summary(room) {
  return { code: room.code, name: room.name, public: room.public, players: room.players.length, maxPlayers: MAX_PLAYERS, started: room.started };
}
function broadcast(room, message) { for (const p of room.players) send(p.ws, message); }
function leave(ws) {
  const member = clients.get(ws);
  if (!member) return;
  clients.delete(ws);
  const room = rooms.get(member.room);
  if (!room) return;
  room.players = room.players.filter(p => p.id !== member.id);
  if (!room.players.length) { rooms.delete(room.code); return; }
  if (room.host === member.id) room.host = room.players[0].id;
  if (room.started) room.started = false;
  broadcast(room, { type: "room_update", room: summary(room), players: room.players.map(p => ({ id: p.id, name: p.name })), host: room.host });
}
const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Content-Type", "application/json");
  if (req.url === "/health") { res.end(JSON.stringify({ ok: true, rooms: rooms.size })); return; }
  if (req.url === "/rooms") { res.end(JSON.stringify([...rooms.values()].filter(r => r.public && !r.started).map(summary))); return; }
  res.writeHead(404); res.end(JSON.stringify({ error: "not_found" }));
});
const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE });
wss.on("connection", (ws) => {
  const id = randomUUID();
  send(ws, { type: "welcome", id });
  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { send(ws, { type: "error", message: "Invalid JSON" }); return; }
    if (!msg || typeof msg.type !== "string") return;
    if (msg.type === "list_rooms") {
      send(ws, { type: "rooms", rooms: [...rooms.values()].filter(r => r.public && !r.started).map(summary) });
      return;
    }
    if (msg.type === "create_room") {
      if (clients.has(ws)) return send(ws, { type: "error", message: "Leave your room first" });
      if (rooms.size >= MAX_ROOMS) return send(ws, { type: "error", message: "Server full" });
      let roomCode = code();
      while (rooms.has(roomCode)) roomCode = code();
      const room = { code: roomCode, name: safeName(msg.name || "Zebra Arena"), public: msg.public === true, host: id, players: [{ id, name: safeName(msg.playerName), ws }], started: false };
      rooms.set(roomCode, room); clients.set(ws, { id, room: roomCode });
      broadcast(room, { type: "room_update", room: summary(room), players: [{ id, name: room.players[0].name }], host: id });
      return;
    }
    if (msg.type === "join_room") {
      if (clients.has(ws)) return send(ws, { type: "error", message: "Leave your room first" });
      const room = rooms.get(String(msg.code || "").toUpperCase());
      if (!room || room.started || room.players.length >= MAX_PLAYERS) return send(ws, { type: "error", message: "Room unavailable" });
      room.players.push({ id, name: safeName(msg.playerName), ws }); clients.set(ws, { id, room: room.code });
      broadcast(room, { type: "room_update", room: summary(room), players: room.players.map(p => ({ id: p.id, name: p.name })), host: room.host });
      return;
    }
    if (msg.type === "leave_room") { leave(ws); send(ws, { type: "left_room" }); return; }
    const member = clients.get(ws);
    const room = member && rooms.get(member.room);
    if (!room) return send(ws, { type: "error", message: "Not in a room" });
    if (msg.type === "start_game") {
      if (room.host !== id || room.started || room.players.length < 2) return send(ws, { type: "error", message: "Cannot start" });
      room.started = true;
      room.turn = 0;
      broadcast(room, { type: "game_started", players: room.players.map(p => ({ id: p.id, name: p.name })), turn: room.players[0].id });
      return;
    }
    if (msg.type === "turn_action") {
      if (!room.started || room.players[room.turn]?.id !== id) return send(ws, { type: "error", message: "Not your turn" });
      if (!["fire", "shop", "move", "end_turn"].includes(msg.action)) return;
      const payload = msg.payload && typeof msg.payload === "object" && !Array.isArray(msg.payload) ? msg.payload : {};
      broadcast(room, { type: "turn_action", player: id, action: msg.action, payload });
      if (msg.action === "fire" || msg.action === "end_turn") {
        room.turn = (room.turn + 1) % room.players.length;
        broadcast(room, { type: "next_turn", turn: room.players[room.turn].id });
      }
      return;
    }
  });
  ws.on("close", () => leave(ws));
  ws.on("error", () => leave(ws));
});
server.listen(PORT, "0.0.0.0", () => console.log("ScorchNova online lobby listening on", PORT));
