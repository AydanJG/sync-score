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
4. Build the Trust round level by hand in Studio, then tag the parts with
   the Tag Editor: a `SpawnLocation` for the lobby, obstacle/wall parts →
   `TrustObstacle`, the end part → `TrustGoal`, two spawn parts →
   `TrustSpawn` (see `state/backlog.md`).
5. For local iteration without real friend-pairing: Studio → **Test → Clients and Servers** (2 clients) — a dev-only bypass auto-starts a Trust round once 2 players are present (Studio only, never runs in a published place).
6. If you've built the Boulder Cannon hazard (`Workspace.BoulderRamp` with
   `Cannon1`/`Cannon2`/`Cannon3` + a `Rock` template), tag one part at the
   bottom of the ramp `BoulderDespawn` so rocks get cleaned up once they
   reach it.

## File structure

```
sync-score/
├── default.project.json   # Rojo project file — maps src/ folders to Roblox services, declares RemoteEvents
├── src/
│   ├── server/
│   │   ├── main.server.luau         # Entry point, bootstraps PairingService + RoundService + BoulderHazardService
│   │   ├── PairingService.luau      # Reserves a private server + friend-invite pairing via TeleportService/SocialService
│   │   ├── RoundService.luau        # Trust round orchestration: roles, timer, obstacle/goal detection, scoring
│   │   ├── ScoreService.luau        # Computes the Sync Score from mistakes + time elapsed
│   │   └── BoulderHazardService.luau # Boulder Cannon hazard: fires rocks down BoulderRamp, kills on touch
│   ├── client/
│   │   ├── main.client.luau      # Entry point, wires up round start/end UI
│   │   └── UI/
│   │       ├── LobbyScreen.luau    # "Invite Friend" button (pairing + native game invite)
│   │       ├── BlindOverlay.luau   # Full-screen overlay shown to the "blind" role during the Trust round
│   │       └── ResultsScreen.luau  # Displays the Sync Score and its breakdown
│   └── shared/
│       ├── Config.luau           # Shared constants (par time, penalties, tags, roles)
│       └── Remotes.luau          # Typed access to the RemoteEvents declared in default.project.json
├── state/
│   ├── backlog.md                # Roadmap, current phase, explicit scope cuts
│   └── session-log.md            # Per-session summaries
```

- `src/server` → `ServerScriptService`
- `src/client` → `StarterPlayer.StarterPlayerScripts`
- `src/shared` → `ReplicatedStorage.Shared`
- `ReplicatedStorage.Remotes` → `RoundStarted`, `RoundEnded`, `RequestPairing` (`RemoteEvent`s, declared directly in `default.project.json`)
