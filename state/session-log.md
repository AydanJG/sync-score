# Session Log

## 2026-07-14
- Scaffolded the Rojo project (`rojo init`, restructured into
  `src/server` / `src/client` / `src/shared`, rokit-pinned rojo 7.7.0).
- Wrote minimal boilerplate: `main.server.luau`, `main.client.luau`,
  `PairingService.createPrivateServer` stub, `ScoreService.calculateScore`
  (formula implemented, reads constants from `Config.luau`),
  `ResultsScreen.luau` stub, `Config.luau` constants.
- Kept the pre-existing `score_sync.rbxl` (had prior Studio work), added it
  to `.gitignore` rather than committing it.
- Initialized git, made the initial commit.
- Set up project memory: `CLAUDE.md` (architecture/mechanics/conventions,
  source of truth), `state/backlog.md` (roadmap + explicit scope cuts),
  this session log.
- Confirmed MVP scope: Trust round + friend-pairing only, 2-round rotation
  (not 3), no Quick Match/leaderboards/DataStore yet.

- Planned and implemented the MVP: Trust round + friend-pairing + results
  screen (plan approved before implementation, see milestones below).
  - Shared plumbing: `Config.luau` tags/roles/timeout, `Remotes.luau`,
    `ReplicatedStorage.Remotes` (`RoundStarted`, `RoundEnded`,
    `RequestPairing`) declared in `default.project.json`.
  - `RoundService.luau` (new): role assignment, spawn teleport, server-
    authoritative mistake tracking via `CollectionService` tags
    (`TrustObstacle`/`TrustGoal`/`TrustSpawn`), timeout, scoring via
    existing `ScoreService`, fires `RoundEnded` with score breakdown.
  - Client: `BlindOverlay.luau` (new), `LobbyScreen.luau` (new, Invite
    Friend button), `ResultsScreen.luau` implemented (score + breakdown),
    `main.client.luau` wired to `RoundStarted`/`RoundEnded`.
  - `PairingService.luau` implemented: `TeleportService:ReserveServer` +
    `TeleportToPrivateServer`, native `SocialService:PromptGameInvite` for
    the actual friend invite, starts the round once 2 players are in the
    private server.
  - Added a `RunService:IsStudio()`-gated dev bypass in `RoundService` so
    2 local Studio test clients can skip real pairing — `TeleportService`
    doesn't work in local Studio multiplayer testing.
  - Updated `README.md` and `CLAUDE.md` file-structure sections to match.
- Replaced the manual Studio geometry-tagging step with a code-generated
  map: **`CourseBuilder.luau`** (new) procedurally builds a stylized
  "modern neon minigame" lobby + slalom Trust round corridor under
  `Workspace.GeneratedMap` and tags parts with the existing
  `TrustObstacle`/`TrustGoal`/`TrustSpawn` constants — idempotent (no-ops
  if `GeneratedMap` already exists), so it's safe to call on every server
  start and won't clobber manual Studio edits made afterward.
  - `main.server.luau` now calls `CourseBuilder.build()` first, before
    `PairingService`/`RoundService`.
  - `default.project.json`: removed the placeholder `rojo init`
    `Baseplate` (the generated lobby floor replaces it), added
    `ColorShift_Bottom` to `Lighting` and a declarative `Atmosphere`
    instance for the moody theme.
  - `README.md`/`CLAUDE.md` updated — the old "tag geometry by hand in
    Studio" step is gone, replaced with "press Play, it builds itself";
    documented the one-time Command Bar call
    (`require(game.ServerScriptService.CourseBuilder).build()`) for
    baking the map permanently into `score_sync.rbxl`.
  - No changes needed to `RoundService`/`ScoreService`/client code — they
    already discover geometry generically via `CollectionService`.
- **Reverted the above**: user Play-tested `CourseBuilder`'s output in
  Studio and it looked bad, deleted the generated map, and is hand-building
  the lobby + level in Studio's editor instead. Undid the procedural
  approach:
  - Removed `CourseBuilder.build()` from `main.server.luau` (it's
    idempotent, so leaving it wired in would have silently regenerated
    the same unwanted map on the next Play now that `GeneratedMap` is
    gone).
  - Deleted `src/server/CourseBuilder.luau` entirely (user's choice — no
    reuse planned).
  - Reverted `default.project.json` back to the original `rojo init`
    `Baseplate` + plain `Lighting` (removed `ColorShift_Bottom` and
    `Atmosphere`) — the neon theming was part of the same rejected
    package, and leaving mood lighting with no matching hand-built
    geometry would look inconsistent, plus it's Rojo-managed so it'd keep
    fighting any manual Lighting tweaks made in Studio.
  - `README.md`/`CLAUDE.md` reverted to the manual Tag Editor
    instructions (`TrustObstacle`/`TrustGoal`/`TrustSpawn`).
  - **Decision for future sessions**: level geometry is hand-built in
    Studio going forward, not code-generated. Don't re-suggest procedural
    map generation without asking first.
- **Not yet done**: no level exists yet (user is about to hand-build it in
  Studio). Once it's built and tagged, next session should Play-test the
  full Trust round loop (2-client dev bypass: blind overlay, mistake
  counting, goal detection, results screen) before checking off the MVP
  item in `state/backlog.md`.

Next: user hand-builds the lobby + Trust round level in Studio, tags it,
then playtest the full loop (2-client local test) and fix whatever
breaks.

- User hand-built a lobby and a "Log Gate" structure, and a "Boulder
  Cannon" hazard (`Workspace.BoulderRamp` with `Cannon1`/`Cannon2`/
  `Cannon3` + a `Rock` template). Various small Studio-side asset
  questions along the way (wood color, rope texture tiling, asset pack
  storage via `ServerStorage`, MeshPart `TextureID` vs `Decal`/`Texture`,
  free-cam navigation) — no code changes from those, pure Studio guidance.
- Implemented the Boulder Cannon hazard (plan approved first — this is a
  new mechanic, not covered by the MVP plan):
  - `Config.luau`: added `BOULDER_DESPAWN_TAG = "BoulderDespawn"`.
  - `BoulderHazardService.luau` (new): each of the 3 cannons fires on its
    own independently staggered/randomized timer, cloning the `Rock`
    template, launching it via `AssemblyLinearVelocity` along the
    cannon's `LookVector`, letting ramp geometry + gravity carry it down.
    Kills any player character it touches (`Humanoid.Health = 0` — first
    real "kill" mechanic in the codebase, previously only
    `RoundService`'s mistake-counting existed). Despawns via the
    `BoulderDespawn` tag on a part the user places at the ramp's bottom,
    plus a ~20s lifetime safety net. Rock template is reparented to
    `ServerStorage` so it isn't itself a live hazard sitting in
    `Workspace`.
  - `main.server.luau`: requires `BoulderHazardService` **last** (after
    `PairingService`/`RoundService`) — it does a blocking `WaitForChild`
    on `Workspace.BoulderRamp` at require-time, so ordering it last means
    a missing/renamed ramp can't block the core Trust round system from
    initializing.
  - `README.md`/`CLAUDE.md` updated — new "Environmental hazards" section
    in `CLAUDE.md` documents this as the pattern for future kill-on-touch
    hazards (explicitly: don't wire hazard kills through `RoundService`'s
    mistake system, they're unrelated).
  - Manual step still needed from user: tag one part at the ramp's bottom
    `BoulderDespawn`.
- **Not yet done**: none of this (Trust round geometry+tags, or the
  Boulder Cannon hazard) has been Play-tested yet.

Next: user tags the boulder despawn part, then Play-test everything built
so far — Trust round loop AND the Boulder Cannon hazard — and report back
what breaks.
