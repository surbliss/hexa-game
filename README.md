# Hexa-game
A clone of the Hive boardgame by Gen42, for local multiplayer over LAN.
Not affiliated with or endorsed by Gen42. Rules can be found at https://hivegame.com/download/rules.pdf.

## Stack
- **Backend:** Haskell (websockets)
- **Frontend:** Gleam (Lustre)
- **Legacy frontend:** Vanilla JS/SVG (no longer compatible with current backend)

## Running
Start the backend:
```sh
cabal run
```
Build and serve the Gleam frontend:
```sh
cd gleam-frontend
gleam run -m lustre/dev start
```

Then open `http://localhost:8080` on the two devices you want to play against each other (or two browser-tabs on one device).
Requires ports 8080 and 9000 open on the host machine.

## Status
Gameplay is functional. Following is not implemented yet, but planned:
- Skip players turn if no legal moves (as described in the rules)
- Implement the expansion-pieces (Ladybug, Mosquito, Pillbug)
- Create a nix build-script to serve the project properly, rather than through dev-hosting
- Add assets with pictures
- Add a popup when game ends
