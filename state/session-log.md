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
