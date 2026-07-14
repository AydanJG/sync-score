# sync-score

A 2-player teamwork compatibility challenge game for Roblox. Two friends are
paired into a private server and work through a shared challenge together;
their performance (mistakes made, time taken) is combined into a single
**Sync Score** that reflects how well they played as a team.

Synced with Roblox Studio using [Rojo](https://rojo.space).

## Running the project

1. Install the pinned toolchain (Rojo) with [Rokit](https://github.com/rojo-rbx/rokit):
   ```bash
   rokit install
   ```
2. Start the Rojo server:
   ```bash
   rojo serve
   ```
3. In Roblox Studio, install the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-studio-plugin), open `score_sync.rbxl`, and click **Connect** in the Rojo plugin panel to sync `src/` into the place.

## File structure

```
sync-score/
├── default.project.json   # Rojo project file — maps src/ folders to Roblox services
├── src/
│   ├── server/
│   │   ├── main.server.luau      # Entry point, runs on server start
│   │   ├── PairingService.luau   # Pairs two friends into a private server via TeleportService
│   │   └── ScoreService.luau     # Computes the Sync Score from mistakes + time elapsed
│   ├── client/
│   │   ├── main.client.luau      # Entry point, runs when the local player joins
│   │   └── UI/
│   │       └── ResultsScreen.luau  # Displays the Sync Score and its breakdown
│   └── shared/
│       └── Config.luau           # Shared constants (par time, penalties, max players)
```

- `src/server` → `ServerScriptService`
- `src/client` → `StarterPlayer.StarterPlayerScripts`
- `src/shared` → `ReplicatedStorage.Shared`
