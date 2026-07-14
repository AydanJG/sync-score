# sync-score

## What this is
A 2-player Roblox teamwork-compatibility game. Pairs (friends, MVP is
friend-invite only — see state/backlog.md) run short co-op mini-challenges
and get a "Sync Score" measuring how well they coordinated.

Explicitly NOT a dating/romantic matchmaking game, ever, in any copy, UI, or
mechanic — framing is teamwork/friendship compatibility only.

## Tech stack
- **Roblox Studio** — target platform
- **Rojo**, installed via **Rokit** (`rokit add rojo-rbx/rojo`) — NOT the npm
  `rojo` package, which is unofficial/deprecated. Syncs this filesystem with
  Studio.
- **Luau** — Roblox's typed Lua dialect
- Git, private repo

## Project structure
```
sync-score/
├── default.project.json      # Rojo config: maps folders below to Roblox services + RemoteEvents
├── src/
│   ├── server/                    # -> ServerScriptService
│   │   ├── main.server.luau       # entry point, bootstraps PairingService + RoundService
│   │   ├── PairingService.luau    # reserve private server + friend-invite pairing
│   │   ├── RoundService.luau      # Trust round orchestration (roles, timer, scoring)
│   │   └── ScoreService.luau      # scoring formula + calculation
│   ├── client/                    # -> StarterPlayer.StarterPlayerScripts
│   │   ├── main.client.luau       # entry point, wires round start/end UI
│   │   └── UI/
│   │       ├── LobbyScreen.luau   # Invite Friend button
│   │       ├── BlindOverlay.luau  # full-screen overlay for the "blind" role
│   │       └── ResultsScreen.luau # Sync Score reveal screen
│   └── shared/                    # -> ReplicatedStorage.Shared
│       ├── Config.luau            # shared constants (tags, roles, penalties)
│       └── Remotes.luau           # typed access to ReplicatedStorage.Remotes
├── state/
│   ├── backlog.md                 # roadmap, current phase, scope cuts
│   └── session-log.md             # per-session summaries
└── README.md
```

`ReplicatedStorage.Remotes` (`RoundStarted`, `RoundEnded`, `RequestPairing`)
is declared directly in `default.project.json`, not created at runtime.

## Core mechanics — source of truth, don't drift without asking
- **Pairing:** friend-invite only for MVP. No stranger-matching ("Quick
  Match") until MVP is validated — intentional scope cut, not an oversight.
- **Challenge rotation (MVP = 2 rounds, not 3):**
  1. Trust round — one player "blind" (camera/vision obscured via a UI
     overlay, NOT actual Roblox blindness mechanics), the other guides
     verbally or via text. Scored on time + mistake count.
  2. Coordination round — players tethered via Roblox's built-in
     `RopeConstraint`/`RodConstraint`. Do not build custom tether physics.
- **Scoring formula** (lives in `ScoreService.luau`, constants in
  `Config.luau`, never hardcoded elsewhere):
  ```
  100 - (mistakes * MISTAKE_PENALTY) - (max(0, timeElapsed - PAR_TIME) * TIME_OVER_PENALTY)
  ```
  clamped 0–100.
- **No pay-to-win.** Score must reflect actual coordination — monetization
  is cosmetic-only (avatar items, score-card themes). Flag any feature
  request that would let purchases affect the score.

## Conventions
- Server scripts: `.server.luau`; client: `.client.luau`; shared modules:
  plain `.luau`
- Use `RemoteEvent`s for client-server score/timer sync — no polling
- Prefer Roblox built-ins (`TeleportService`, `RopeConstraint`,
  `DataStoreService`) over custom-built equivalents
- Comment any function stub with what it will eventually do, even if empty
- Keep all magic numbers in `Config.luau`, never inline

## Known environment notes
- `rojo serve` must be running locally with the Rojo Studio plugin connected
  before syncing changes
- Multiplayer testing: Studio's "Test → Clients and Servers" (2 clients) for
  solo testing of the pairing flow; real playtesting needs a second human in
  a private server

## Session protocol
Per the user's global rules: read `state/session-log.md` and
`state/backlog.md` at the start of a session, confirm priority before
starting work, and write a session summary to `state/session-log.md` before
ending.
