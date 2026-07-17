# sync-score

## What this is
A Roblox teamwork-compatibility party game. Anyone can join the lobby
(public server, not friend-invite-gated — see state/backlog.md), then
self-selects into 2-player pairs by standing together on platforms, and
every pair runs the same rotation of mini-challenges and gets a
"Compatibility Score" measuring how well they coordinated/know each other.
At the end, pairs are ranked against each other and the highest-scoring
pair is declared the most compatible team.

Explicitly NOT a dating/romantic matchmaking game, ever, in any copy, UI, or
mechanic — framing is teamwork/friendship compatibility only. This applies
with extra weight to the Phase 3 personality round (guessing a partner's
preferences) since it's the mechanic closest in shape to dating-app
"compatibility quiz" content — keep it strictly friendship-flavored.

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
│   │   ├── main.server.luau         # entry point, bootstraps every service below
│   │   ├── LobbyService.luau        # "Start Game" countdown, bulk-teleport into Match Room
│   │   ├── PairingService.luau      # Phase 1: pairing-pad detection, lobby timer, close-pad prompt
│   │   ├── RoundService.luau        # Blind Parkour orchestration — multi-pair, shared course
│   │   ├── ScoreService.luau        # scoring formula + calculation
│   │   ├── Knockback.luau           # shared PlatformStand knockback helper (all 3 hazards below)
│   │   ├── BoulderHazardService.luau # Boulder Cannon hazard, unrelated to Trust round scoring
│   │   ├── LogGateService.luau      # Log Gate swinging-pendulum hazard
│   │   └── RotatingLogService.luau  # Rotating Log floor-sweep hazard
│   ├── client/                    # -> StarterPlayer.StarterPlayerScripts
│   │   ├── main.client.luau       # entry point, wires round start/end UI
│   │   └── UI/
│   │       ├── StartGameScreen.luau # "Start Game" button + local countdown display
│   │       ├── PairingCountdownScreen.luau # Match Room HUD: server-driven pairing countdown
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

`ReplicatedStorage.Remotes` (`RoundStarted`, `RoundEnded`, `CameraSync`,
`RequestGameStart`, `GameStarting`, `PairingCountdown`) is declared
directly in `default.project.json`, not created at runtime.

- **Lobby / pairing:** the lobby itself is a normal public Roblox server —
  anyone can join, no friend-invite gate on entry (this reverses what an
  earlier session assumed; corrected 2026-07-17). Players spawn in the
  lobby and see a "Start Game" button (`StartGameScreen.luau`) — any
  player can press it, which fires `Remotes.RequestGameStart`.
  `LobbyService.luau` runs one shared countdown
  (`Config.GAME_START_COUNTDOWN`, 5s) for whoever's currently in the
  lobby: broadcasts `Remotes.GameStarting` (clients run their own local
  visual countdown off this, not a tick-by-tick remote) then, after an
  identical server-side wait, bulk-teleports everyone not already
  mid-round into `Workspace."Match Room"` (scattered around the room's
  pivot — no dedicated spawn markers there yet, unlike
  `TrustSpawn`/`RockSpawn`). A second "Start Game" press while a countdown
  is already running is a no-op. The old friend-invite button
  (`LobbyScreen.luau`) was removed entirely — this replaces it. Once
  Start Game's own countdown finishes client-side, `main.client.luau`
  starts `PairingCountdownScreen` (a small always-on-screen HUD) — this is
  the client's own signal for "I should now be in the Match Room."
  **Phase 1: Pairing round** (`PairingService.luau`, runs once players are
  in the Match Room) — parts/models tagged
  `Config.PAIRING_PAD_TAG` ("PairingPad") are pairing pads. Occupancy is
  polled (`Workspace:GetPartsInPart`, not `Touched`/`TouchEnded` — a
  player's limbs touch/leave independently, which makes event-based
  "still standing here" bookkeeping unreliable), and shown live via a
  `BillboardGui`/`TextLabel` ("0/2", "1/2", ...) parented directly to each
  pad — no remote needed for this, it's just a normal replicating
  `Workspace` instance the server updates directly. One lobby-wide
  countdown (`Config.PAIRING_TIMER_DURATION`) runs on a repeating cycle,
  not a per-pad timer: whoever is on a pad when it expires gets paired —
  exactly 2 people pair up, more than 2 get randomly paired off
  (leftover(s) wait for the next cycle), 0 or 1 is a no-op. Unlike the
  Start Game countdown, this one broadcasts every second
  (`Remotes.PairingCountdown`, driving `PairingCountdownScreen`'s text)
  rather than once per cycle — the cycle repeats continuously and a
  client can arrive mid-cycle, so it can't reconstruct "time remaining"
  from a single message the way Start Game's local timer does. To avoid a
  stranger trolling by jumping onto a pad two friends are about to use, a
  `ProximityPrompt` ("Close Pad") appears once exactly 2 players are on a
  pad, letting either of them lock the roster early — a closed pad's
  occupants are frozen (not re-polled) until the timer processes it, and
  its label shows "Locked (2/2)". Forms pairs by calling
  `RoundService.startRound(player1, player2)` directly — no separate
  remote for this.
- **Multi-pair Blind Parkour (`RoundService.luau`):** every pair plays on
  the same shared course at the same time (no private servers, no
  duplicated course copies — the user plans push/interaction mechanics
  between pairs later, so sharing space is intentional). Round state is
  keyed per-player (`playerToRound`) instead of one module-level round;
  players are teleported by scattering randomly around a single
  `Workspace.BlindObby.BlindObbySpawnCenter` point (not per-pair tagged
  spawn markers — `TrustSpawn`/`Config.SPAWN_TAG` were removed 2026-07-17
  once spawning switched to this model, since there's no exclusivity to
  claim when everyone already shares one course). `startRound` warns and
  refuses only if `BlindObbySpawnCenter` itself is missing. Obstacle/goal
  `Touched`
  connections and the `CameraSync` relay are created fresh per round
  instance and filtered to that round's own `blindPlayer`/`guidePlayer`,
  even though every round is listening on the same shared geometry —
  don't reintroduce a single module-level "current round" guard here.
- **Phase 2: Physical challenge** — one minigame chosen at random from a
  set of physical co-op challenges. **Blind Parkour is the only one built
  so far** (the existing Trust round: one player "blind" via a UI overlay,
  NOT actual Roblox blindness mechanics, the other guides verbally/via
  text; scored on time + mistake count). More physical minigames are a
  backlog item, not yet designed. The previously-planned "Coordination
  round" (`RopeConstraint`/`RodConstraint` tether) is now just one
  candidate for this slot, not a guaranteed second fixed round — don't
  build custom tether physics if it does get built.
- **Phase 3: Personality challenge** — new category, not yet built.
  Players guess facts about their partner's preferences/personality (e.g.
  favorite food) to measure how well they actually know each other. Keep
  this strictly in friendship/"how well do you know your partner" framing,
  never romantic-compatibility framing — see "What this is" above.
- **Phase 4:** TBD — no design yet, don't invent one without asking.
- **Compatibility score:** each phase contributes to a per-pair
  compatibility score; at the end all pairs in the lobby are ranked and
  the highest-scoring pair is declared the most compatible team/winner.
  This replaces the old single-round "Sync Score reveal" model —
  `ScoreService` currently only implements the Blind Parkour formula for
  one round and will need to become an aggregator across phases.
- **Blind Parkour scoring formula** (lives in `ScoreService.luau`,
  constants in `Config.luau`, never hardcoded elsewhere):
  ```
  100 - (mistakes * MISTAKE_PENALTY) - (max(0, timeElapsed - PAR_TIME) * TIME_OVER_PENALTY)
  ```
  clamped 0–100. Other minigames/phases will need their own scoring
  contribution once built.
- **No pay-to-win.** Score must reflect actual coordination/compatibility —
  monetization is cosmetic-only (avatar items, score-card themes). Flag any
  feature request that would let purchases affect the score.

## Environmental hazards
Separate from the Trust round/scoring system — standalone obstacles, not
wired through `RoundService`'s mistake-counting system. All three now live
under one `Workspace.BlindObby` folder (moved there 2026-07-17 while
building the Phase 1 pairing lobby; each hazard service does its own
`WaitForChild("BlindObby", ...)` rather than sharing one lookup, matching
this codebase's existing per-file convention). First one:
**Boulder Cannon** (`BoulderHazardService.luau`) — three spawn point
markers (`Workspace.BlindObby.RockSpawn1/2/3`, must be `Anchored` — a live
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

Second one: **Log Gate** (`LogGateService.luau`) —
`Workspace.BlindObby."Log Gate"`
(`LogStructure` model containing the log/rope parts, pivoting around a
separate `GateTop` part/model). Kinematic, not physics-driven: all parts
under `LogStructure` are forced `Anchored`, and a script manually rotates
the whole model around `GateTop`'s pivot **position** every frame (the
"rotate a model around an external point" CFrame formula —
`CFrame.new(pivotPosition) * delta * CFrame.new(-pivotPosition) *
originalCFrame`), eased via `TweenService:GetValue(...)` for a natural
pendulum decelerate/pause feel. Swings symmetrically ±`HALF_SWING`
degrees (default 160°, so 320° total) around the rest position captured
at server start — wide enough to swing up high on both sides, clearing
space under the post for a player to pass through during the pause at
each extreme.

Rotation uses a **hardcoded world-space axis** (`SWING_AXIS =
Vector3.new(1,0,0)`, via `CFrame.fromAxisAngle`), not `GateTop`'s own
local orientation — every local-axis attempt (X/Y/Z relative to
`GateTop`) produced visibly wrong results, consistent with `GateTop`
being an asset-pack `Model` without `PrimaryPart` set (same class of
issue as the Boulder Cannon's `Cannon1/2/3` models). If the swing plane
is ever wrong again, try `Vector3.new(0,0,1)` before suspecting anything
else.

Third one: **Rotating Log** (`RotatingLogService.luau`) —
`Workspace.BlindObby."Rotating Log"` spins continuously around its own
center (not an external pivot) in a horizontal plane — a floor sweep, not
a pendulum. Same world-axis-over-local-axis reasoning as Log Gate
(`Vector3.new(0,1,0)`, world up, via `CFrame.fromAxisAngle`), just
accumulated every `Heartbeat` frame instead of eased between two extremes
— no pause, constant `SPIN_SPEED`.

**Shared knockback**: all three hazards knock the player back rather than
kill (briefly sets `Humanoid.PlatformStand = true` so physics actually
carries the impulse, since the Humanoid controller otherwise fights
external velocity — the Boulder Cannon's version of this was a deliberate
change from an earlier instant-kill-on-touch version, don't reintroduce
`Humanoid.Health = 0` without asking). Once a third hazard needed the same
technique it was extracted into `Knockback.luau`
(`Knockback.apply(hit, sourcePosition, force, upward, duration)`) — all
three hazard files call into it. Per-character cooldown tracking is each
hazard's own local responsibility, not shared through the module,
since different hazards shouldn't suppress each other's knockback.

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
- Multiplayer testing: Studio's "Test → Clients and Servers" (pick a player
  count, e.g. 2-6) — since the lobby is public and the whole Start Game →
  Match Room → pairing-pad flow runs on plain `Workspace` teleports (no
  `TeleportService`/private servers involved), multiple local test clients
  exercise the real flow end-to-end, same as a published server. There's
  no more Studio-only dev-bypass in `RoundService` — that was removed
  2026-07-17 once it started conflicting with testing this flow (it used
  to auto-pair the first 2 players the instant they joined, skipping
  `LobbyService`/`PairingService` entirely).

## Session protocol
Per the user's global rules: read `state/session-log.md` and
`state/backlog.md` at the start of a session, confirm priority before
starting work, and write a session summary to `state/session-log.md` before
ending.
