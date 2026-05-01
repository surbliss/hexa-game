# Hexagame
A work-in-progress Hive clone for local multiplayer over LAN.

Inspired by the Hive board game by Gen42. Not affiliated with or endorsed by Gen42.

## Stack
- Frontend: Vanilla JS (SVG)
- Backend: Haskell (websockets)

## Running
Start the backend:
```sh
cabal run
```

Start the frontend dev server:
```sh
npx live-server static
```

Then open `http://YOUR_LAN_IP:8080` on your devices. Requires ports 8080 and 9000 open on the host machine.

## Status
Early development. Not playable yet.
