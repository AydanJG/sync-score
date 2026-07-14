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
4. Press Play — `CourseBuilder.build()` runs automatically on server start
   and generates the stylized lobby + Trust round course under
   `Workspace.GeneratedMap` (idempotent, so it only builds once; safe to
   leave running every session). No manual level-building needed. To bake
   the generated map permanently into `score_sync.rbxl` (so it's visible
   and hand-editable in Studio's Edit mode, not just during Play), paste
   `require(game.ServerScriptService.CourseBuilder).build()` into the
   Command Bar once, then save.
5. For local iteration without real friend-pairing: Studio → **Test → Clients and Servers** (2 clients) — a dev-only bypass auto-starts a Trust round once 2 players are present (Studio only, never runs in a published place).

## File structure

```
sync-score/
├── default.project.json   # Rojo project file — maps src/ folders to Roblox services, declares RemoteEvents
├── src/
│   ├── server/
│   │   ├── main.server.luau      # Entry point, bootstraps CourseBuilder + PairingService + RoundService
│   │   ├── CourseBuilder.luau    # Procedurally builds the stylized lobby + Trust round course
│   │   ├── PairingService.luau   # Reserves a private server + friend-invite pairing via TeleportService/SocialService
│   │   ├── RoundService.luau     # Trust round orchestration: roles, timer, obstacle/goal detection, scoring
│   │   └── ScoreService.luau     # Computes the Sync Score from mistakes + time elapsed
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
