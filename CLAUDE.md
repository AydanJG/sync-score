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
│   │   ├── main.server.luau         # entry point, bootstraps PairingService + RoundService + BoulderHazardService
│   │   ├── PairingService.luau      # reserve private server + friend-invite pairing
│   │   ├── RoundService.luau        # Trust round orchestration (roles, timer, scoring)
│   │   ├── ScoreService.luau        # scoring formula + calculation
│   │   └── BoulderHazardService.luau # Boulder Cannon hazard (kills on touch, unrelated to Trust round scoring)
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

## Environmental hazards
Separate from the Trust round/scoring system — standalone obstacles, not
wired through `RoundService`'s mistake-counting system. First one:
**Boulder Cannon** (`BoulderHazardService.luau`) — three spawn point
markers (`Workspace.RockSpawn1/2/3`, must be `Anchored` — a live
`warnIfUnanchored` check catches this if forgotten) each launch a clone of
`ServerStorage.Rock` down the ramp (hardcoded world `+Z` direction — the
decorative cannon models' orientation isn't reliable, likely no
`PrimaryPart` set), one at a time from a random spawn point, on a
randomized interval. Rocks are cleaned up via a `CollectionService`-tagged
despawn zone (`Config.BOULDER_DESPAWN_TAG`, tag name `"BoulderDespawn"`)
at the bottom, with a lifetime safety net as backup.

Touching a rock does **not** kill — it applies a physical knockback
(briefly sets `Humanoid.PlatformStand = true` so physics actually carries
the impulse, since the Humanoid controller otherwise fights external
velocity) that can knock a player off the ramp into the void, where
Roblox's own fall-death handles it — no custom kill/respawn logic. This
was a deliberate change from an earlier instant-kill-on-touch version;
don't reintroduce `Humanoid.Health = 0` here without asking.

Second one: **Log Gate** (`LogGateService.luau`) — `Workspace."Log Gate"`
(`LogStructure` model containing the log/rope parts, pivoting around a
separate `GateTop` part/model). Kinematic, not physics-driven: all parts
under `LogStructure` are forced `Anchored`, and a script manually rotates
the whole model around `GateTop`'s pivot **position** every frame (the
"rotate a model around an external point" CFrame formula —
`CFrame.new(pivotPosition) * delta * CFrame.new(-pivotPosition) *
originalCFrame`), eased via `TweenService:GetValue(...)` for a natural
pendulum decelerate/pause feel. Swings symmetrically ±`HALF_SWING`
degrees (default 60°, so 120° total) around the rest position captured at
server start — like a real playground swing, staying under the post, not
looping over the top.

Rotation uses a **hardcoded world-space axis** (`SWING_AXIS =
Vector3.new(1,0,0)`, via `CFrame.fromAxisAngle`), not `GateTop`'s own
local orientation — every local-axis attempt (X/Y/Z relative to
`GateTop`) produced visibly wrong results, consistent with `GateTop`
being an asset-pack `Model` without `PrimaryPart` set (same class of
issue as the Boulder Cannon's `Cannon1/2/3` models). If the swing plane
is ever wrong again, try `Vector3.new(0,0,1)` before suspecting anything
else.

Touching it uses the same knockback technique as the Boulder Cannon
(duplicated locally rather than shared — revisit extracting a common
knockback helper if a third hazard needs it), plus a 1s per-character
cooldown since continued contact during a swing could otherwise trigger
repeated `Touched` events.

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
