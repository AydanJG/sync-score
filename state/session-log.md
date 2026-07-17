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

- User reported cannons not shooting. Couldn't see Studio's Output myself,
  so hardened `BoulderHazardService.luau` defensively against the two
  likeliest causes rather than guessing blind:
  - All `WaitForChild` calls now use a 10s timeout instead of blocking
    forever if `BoulderRamp`/`Cannon1-3`/`Rock` names don't match exactly
    — warns and disables gracefully instead of silently hanging.
  - `Rock` is now handled as either a single `BasePart` or a multi-part
    `Model` (suspected root cause: if `Rock` is actually a `Model`, e.g.
    from the imported asset pack, `rock.Anchored = false` would've
    errored immediately and silently killed that cannon's firing loop
    forever after one attempt).
  - Wrapped each `fireCannon` call in `pcall` so a future failure just
    warns instead of permanently disabling a cannon.
  - Asked user to check Studio's Output window (F9) to confirm actual
    root cause rather than assume the fix is right blind.
- Got real Output from the user, confirming two separate things:
  - Rojo sync **was** the root cause of "literally nothing happening" —
    `ReplicatedStorage.Remotes` didn't exist yet (`Infinite yield... on
    'ReplicatedStorage:WaitForChild("Remotes")'`), which hangs `Remotes.luau`
    and cascades into every script that requires it. User reconnected the
    Rojo plugin and it's syncing now (`Server started` printed).
  - Real bug once sync worked: `CFrame is not a valid member of Model
    "Workspace.BoulderRamp.CannonX"` — `Cannon1`/`2`/`3` are `Model`s, not
    `Part`s (same asset-pack pattern as `Rock`, which was already handled
    defensively — the cannons themselves weren't). Fixed by using
    `cannon:GetPivot()` instead of `cannon.CFrame` everywhere in
    `fireCannon` — `GetPivot()` works uniformly on both `BasePart` and
    `Model`, unlike `.CFrame`.
  - Also flagged a separate, unrelated issue in the user's own asset-pack
    content: `Workspace.Lobby.Lobby.Text.SurfaceGui.TextLabel.PoseTexture`
    /`TextureConfiguration` throws `cannot require using asset ID (lacking
    capability LoadUnownedAsset)` — a script attempting to `require()` an
    unowned asset ID, a known backdoor pattern in sketchy free models.
    Blocked by Roblox's sandbox (didn't execute), but flagged for the user
    to inspect/remove since it's outside anything in this repo.
- **Learning for future hazard/geometry code**: don't assume Studio
  objects referenced by path are a single `Part` — this asset pack makes
  everything a `Model` (`Rock`, all three `Cannon`s). Prefer
  `:GetPivot()`/`:PivotTo()` over `.CFrame` for any object whose type
  isn't guaranteed, and handle both `BasePart` and `Model` cases whenever
  touching user-placed Studio content.
- No errors after that fix, but rocks got stuck in the cannon instead of
  launching — classic cause: they were spawning exactly at the cannon's
  own pivot, overlapping its collision geometry, so physics fought the
  velocity instead of letting it fly. Fixed by adding a spawn offset so
  rocks spawn clear of the cannon before `AssemblyLinearVelocity` is
  applied. Still stuck after that — switched both spawn offset and launch
  velocity to a hardcoded world `+Z` direction instead of trusting the
  cannon `Model`'s `GetPivot()` orientation (per user's diagnosis; likely
  cause: these asset-pack Models don't have `PrimaryPart` set, so their
  pivot doesn't reliably match how they look in Studio). **This worked**
  — rocks launch — but spawning wasn't clean off the cannon geometry.
- User's fix: dedicated invisible spawn point markers instead of deriving
  position from the cannon models at all (matches the existing
  `TrustSpawn`/`TrustGoal` marker pattern, and was my own recommendation
  once the LookVector issue showed up). Also manually moved the `Rock`
  template to `ServerStorage.Rock` directly (previously
  `BoulderHazardService` reparented it there itself from
  `BoulderRamp.Rock`).
  - Rewrote `BoulderHazardService.luau`: spawns/fires from
    `Workspace.RockSpawn1/2/3` (their own `GetPivot()`, no offset needed
    since the user places them exactly where wanted) instead of the
    `Cannon1/2/3` models. Reads `ServerStorage.Rock` directly — no more
    runtime reparenting. `Workspace.BoulderRamp` and the `Cannon1/2/3`
    lookups are gone entirely; cannon models are now purely decorative,
    unreferenced by code. Kept the hardcoded `+Z` launch direction (that
    part was already confirmed working).
  - Updated `CLAUDE.md`'s "Environmental hazards" section to match the
    new structure.
- **Still not fully confirmed**: this rewrite (spawn-point-based) hasn't
  been Play-tested yet — next session/test should confirm rocks spawn
  cleanly from the three `RockSpawn` markers and launch correctly.
- Follow-up round of small fixes from continued playtesting:
  - Rocks weren't spawning far enough in front of the `RockSpawn` markers
    — reintroduced `SPAWN_OFFSET` (5 studs along `LAUNCH_DIRECTION`),
    this time applied to the spawn markers instead of the old cannons.
  - Rocks weren't despawning at the tagged platform — same root cause as
    the earlier `Model`-vs-`Part` issues: the despawn tag was almost
    certainly applied to a parent `Model`, but `Touched` only fires with
    the specific child `Part` actually hit, so the exact-instance
    `HasTag` check missed it. Added `isDespawnZone()`, which walks up the
    ancestry checking every level instead of just the touched part.
  - Two cannons could fire close enough together that rocks overlapped —
    replaced the 3 independent per-spawn timers with one shared loop that
    cycles `RockSpawn1 → 2 → 3 → repeat`, guaranteeing only one rock is
    ever launched at a time. Side effect: each individual spawn point now
    fires roughly 3x less often than before (shares one cadence across
    all three) — flag if the pacing feels off.
  - Rocks didn't roll straight down the ramp — inherent to physics-based
    rolling on an irregular mesh shape (contact with the ramp imparts
    sideways drift/spin), not fixable via launch velocity alone. Added a
    `RunService.Heartbeat` connection per rock that zeroes any sideways
    (X-axis) velocity every frame, leaving vertical (gravity/slope) and
    forward motion untouched. Tracked in the same connection-cleanup
    table as the Touched handlers.
  - User asked for "roll slower, shoot further apart, roll straight only"
    at one point, then said nevermind before I acted on it — only the
    "roll straight" part was later explicitly re-requested and done above
    ("shoot further apart"/"roll slower" were never actually implemented,
    don't assume they were).
  - Cannons weren't killing anymore — deliberately replaced instant-kill
    (`Humanoid.Health = 0`) with physical knockback (briefly
    `Humanoid.PlatformStand = true` so physics actually carries an
    impulse, since Humanoid otherwise resists external velocity every
    frame). Rock can now knock a player off the ramp into the void
    instead of guaranteeing death on touch.
  - Fixed rocks not launching/despawning/staying together across several
    rounds: spawn markers not `Anchored` (added a loud
    `warnIfUnanchored` check — this was the actual root cause of
    "nothing spawns/rocks appear randomly"), despawn tag likely applied
    to a parent `Model` not the touched `Part` (fixed via ancestry-walk
    in `isDespawnZone`), multi-part `Rock` models not rigidly connected
    (added `WeldConstraint`s at spawn time), and firing order made
    random instead of fixed round-robin per request.

- **New hazard: Log Gate** (`Workspace."Log Gate"`, `LogStructure`
  pivoting around `GateTop`) — user reported an old hand-written Studio
  script for this had stopped working; I have no visibility into
  Workspace-local scripts (confirmed nothing about it exists in `src/`),
  so built `LogGateService.luau` fresh rather than debug-blind. User
  needs to delete/disable whatever old script was in Studio to avoid it
  fighting the new one.
  - Multiple rounds of axis/direction guessing (local X, then Z, then Y
    — all wrong) before recognizing the real pattern: `GateTop` is
    almost certainly an asset-pack `Model` without `PrimaryPart` set,
    making its local orientation unreliable — same root cause as
    `Cannon1/2/3` earlier. Fixed by rotating around a **hardcoded
    world-space axis** (`CFrame.fromAxisAngle`, not `GateTop`'s local
    axes) instead — this is now the go-to fix whenever local-axis
    rotation on a hand-placed object looks wrong.
  - Swing arc: started at a full 320° one-sided sweep (matching the
    original spec literally), user reported it looped "up over the
    post," so reduced to a small symmetric ±60° swing ("like a real
    swing" reading) — then user clarified they actually wanted the wide
    320°-total sweep back (±160° symmetric this time), specifically so
    it swings up high enough on both sides to leave a gap for the player
    to pass under during the pause. **Lesson**: the "up over the post"
    complaint was about broken rotation math (wrong axis), not the arc
    size — don't reflexively shrink an arc when the user says something
    "swings wrong," check whether it's actually a math/axis bug first.
  - Not yet confirmed working after the final wide-swing change.

- **New hazard: Rotating Log** (`Workspace.BlindObby."Rotating Log"`) —
  spins continuously around its own center in a horizontal plane (floor
  sweep, not a pendulum). Asked the user whether touching it should count
  as a Trust round mistake (given the "BlindObby" naming) or knockback
  like the other hazards — they chose knockback, so it's a standalone
  hazard like the other two, not wired into `RoundService`.
  - This was the third hazard needing the PlatformStand knockback
    technique, crossing the threshold noted when Log Gate was built —
    extracted `Knockback.luau` (single `Knockback.apply(...)` function)
    and refactored `BoulderHazardService`/`LogGateService` to use it
    instead of a third duplicated copy. Cooldown tracking stays local to
    each hazard file, not shared through the module.
  - Also removed `BoulderHazardService`'s temporary spawn-position debug
    print during this pass, since that issue was confirmed fixed several
    fixes ago and the print was marked for removal once confirmed.
  - Not yet tested.

Next: user tests Log Gate (wide swing) and Rotating Log in Studio, and
reports back what breaks. Three environmental hazards now exist
(`BoulderHazardService`, `LogGateService`, `RotatingLogService`), all
sharing `Knockback.luau`, all separate from Trust round scoring.

- Knockback tuning pass, confirmed working by end of session:
  - User reported all three hazards' knockback felt like ragdolling, not
    a dramatic launch — bumped force/upward/duration significantly
    across all three (roughly: Boulder Cannon and Log Gate to
    FORCE=130/UPWARD=55/DURATION=1.0s, Rotating Log to
    FORCE=150/UPWARD=60/DURATION=1.1s, since it's a floor sweep and
    wanted to launch further specifically).
  - Log Gate/Rotating Log still felt weak after that — flattened the
    push direction in `Knockback.luau` to horizontal-only (X/Z) before
    scaling by force, with `upward` applied as a fully separate vertical
    component, since a vertical offset between player and hazard at
    contact was partially canceling the upward boost. Pushed both log
    hazards further still (Log Gate UPWARD 95, Rotating Log UPWARD 100).
  - Still "just sits" instead of launching — this turned out to be a
    real bug, not a tuning issue: setting `Humanoid.PlatformStand = true`
    and overwriting `AssemblyLinearVelocity` on the *same frame* can get
    silently eaten while the Humanoid controller is still mid-transition
    out of its normal movement state. Fixed in `Knockback.luau` by
    calling `humanoid:ChangeState(Enum.HumanoidStateType.Physics)`
    alongside `PlatformStand`, waiting one `RunService.Heartbeat` before
    applying velocity, and adding an extra `ApplyImpulse` (scaled by
    `AssemblyMass`) on top of the direct velocity set. **User confirmed
    this fixed it** ("Much better").
  - **Lesson for future knockback/launch work in this codebase**: if a
    scripted `AssemblyLinearVelocity` launch looks like it's not
    applying at all (character stays put / just ragdolls in place
    rather than moving), suspect the PlatformStand-same-frame timing bug
    first — the fix (`ChangeState(Physics)` + wait one Heartbeat before
    setting velocity) is already in `Knockback.luau`, reuse it rather
    than re-debugging from scratch.

Session end (2026-07-15, spilled over from 2026-07-14): all three
environmental hazards (Boulder Cannon, Log Gate, Rotating Log) are built,
debugged, and confirmed working by the user, including knockback feel.
MVP Trust round itself (geometry, tags, full 2-client playtest) still
hasn't been confirmed end-to-end — that's still the actual `state/backlog.md`
MVP item, unchecked. Next session should either finish that verification,
or continue on whatever the user prioritizes (confirm before assuming).

## 2026-07-17
- Built the guide-side camera-mirror mechanic for Blind Parkour (formerly
  "Trust round"): the blind player's camera CFrame streams to the server
  every `Heartbeat` over a new `CameraSync` `UnreliableRemoteEvent`
  (`default.project.json`/`Remotes.luau`), `RoundService` relays it
  server-side only after validating the sender is that round's actual
  blind player, and a new client module `CameraLink.luau` puts the guide's
  camera into `CameraType.Scriptable` and snaps it to whatever arrives —
  restored to `Custom` on `RoundEnded`. Wired into `main.client.luau`
  alongside the existing `BlindOverlay`/guide-label logic. Not yet
  playtested. Flagged one open question to the user: Roblox's default
  spatial voice chat attaches its `AudioListener` to the local camera, so
  while voice itself isn't broken by this change, the guide's perceived
  audio direction/distance will follow the mirrored camera position rather
  than their real one for the round's duration — worth checking during
  next playtest.
- **Major scope/architecture pivot, confirmed with user**: the game is no
  longer a single 2-player Trust round. New structure, now the MVP
  definition (see `CLAUDE.md` "Core mechanics" and `state/backlog.md`,
  both rewritten this session):
  1. **Phase 1 — Pairing round**: a lobby of more than 2 friends (invited
     as a group, not stranger-matched) self-selects into 2-player pairs by
     standing together on platforms — replaces one-friend-invites-one-
     friend as the pairing model.
  2. **Phase 2 — Physical challenge**: one minigame chosen at random from a
     set of physical co-op challenges. Blind Parkour (the old Trust round)
     is the only one built; more are backlog items.
  3. **Phase 3 — Personality challenge**: new category, not built —
     guessing a partner's preferences/personality (e.g. favorite food) to
     score how well they know each other. Confirmed with user this must
     stay strictly friendship-framed, never romantic/dating-quiz framed,
     since it's the closest any mechanic has come to that territory.
  4. **Phase 4**: TBD, no design yet.
  - End state: a per-pair **compatibility score** aggregated across all
    phases, with every pair in the lobby ranked against each other —
    highest score wins, framed as "most compatible team." This replaces
    the old single-round Sync Score reveal model.
  - Confirmed with user: this is a real multi-pair lobby (not just flavor
    text over a 2-player game) — multiple pairs run the same phases in
    parallel and get ranked against each other. Also confirmed this new
    structure fully replaces the old MVP definition rather than being a
    later v1/vision item.
  - **Not yet started**: no implementation for any of this. Biggest known
    gap: `PairingService`/`RoundService` currently hardcode exactly 2
    players and a single round instance server-wide — supporting multiple
    concurrent pairs each running independent round instances needs a
    design pass before Phase 1 (or a multi-pair-aware Phase 2) can be
    built. `ScoreService` similarly only implements one formula for one
    round and will need to become a cross-phase aggregator.
  - Old scope-cut item "the third mini-challenge (decision-speed round)"
    is now obsolete/superseded — the new plan explicitly has more than 2
    phases. The "no stranger-matching" cut still stands, but now
    specifically means no strangers *into the lobby*; self-selecting into
    pairs *within* an already-invited group is in scope (Phase 1).

Next: no priority confirmed yet for actual implementation order among
Phase 1 (multi-pair pairing rework), finishing the Blind Parkour
playtest/camera-mirror verification, or designing Phase 3. Ask before
starting any of them.

- User asked to prioritize the **multi-pair `PairingService`/`RoundService`
  rework** for Phase 1. Two design questions resolved before writing code:
  - Concurrency model: all pairs share **one physical course** at the same
    time (no private servers, no duplicated course copies) — user plans to
    add player-vs-player push/interaction mechanics on the shared course
    later, so this is intentional, not something to isolate against.
  - Also corrected: the lobby is a normal **public** server, anyone can
    join — not friend-invite-gated as an earlier pass in this same session
    had assumed. `CLAUDE.md`/`backlog.md`/memory corrected to match.
  - Pairing mechanic confirmed: shared "pairing pad" platforms + one
    lobby-wide countdown timer (not per-pad). Whoever is standing on a pad
    when the timer expires locks in; exactly 2 → paired; more than 2 →
    randomly paired off (leftover waits for next cycle); a pad with only 1
    (or 0) just waits. To avoid trolling (a 3rd stranger jumping on your
    pad), 2 players who already intend to pair can "close" their pad early
    via a `ProximityPrompt` once exactly 2 are on it, freezing that pad's
    roster until the timer processes it.
- **Also flagged to the user (not a code change)**: a pasted Studio asset
  script ("TextureConfigurationLoader" day/night light system) has a
  legitimate-looking light-cycle implementation wrapped around a
  suspicious embedded block that (a) gates behavior on
  `not EffectBuilding:InStudioMode()` — classic Studio-evasion, (b)
  `require()`s an unexplained module (`CoreSkyboxSystem`) only under that
  gated condition, and (c) pads itself with non-functional decoy code
  (e.g. calling `:split()` on a `CFrame`, which doesn't exist). This is the
  same class of issue as the `PoseTexture`/`TextureConfiguration`
  unowned-asset `require()` flagged 2026-07-15 in this same asset pack —
  likely the same or a sibling backdoor mechanism. Recommended deleting
  the embedded block (and inspecting/deleting `CoreSkyboxSystem`) rather
  than publishing with it intact. Purely advisory — this script lives in
  Workspace/asset content outside `src/`, not something I can edit
  directly.
- Implemented the Phase 1/Phase 2 rework:
  - `Config.luau`: added `PAIRING_PAD_TAG` ("PairingPad") and
    `PAIRING_TIMER_DURATION` (20s default).
  - `PairingService.luau` rewritten from scratch — the old
    `TeleportService:ReserveServer`/private-server/`RequestPairing` flow is
    gone entirely (obsolete now that the lobby is public). New: polls
    `PairingPad`-tagged parts' occupancy via `Workspace:GetPartsInPart`
    (not `Touched`/`TouchEnded`, which is unreliable for "is this player
    still standing here" across multiple limbs), a repeating lobby-wide
    countdown (`Config.PAIRING_TIMER_DURATION`) that pairs off whoever's on
    each pad when it expires (shuffle-then-pair-consecutively handles both
    the exactly-2 and overflow-random-pairing cases with one code path),
    and a `ProximityPrompt` ("Close Pad") that appears once exactly 2
    players are on a pad, letting them freeze/lock their pairing early.
  - `RoundService.luau` reworked from a single module-level `currentRound`
    to per-player round state (`playerToRound`), since every pair now
    shares one course concurrently. Spawn points (`Config.SPAWN_TAG`) are
    claimed/released per round so concurrent pairs don't teleport onto
    each other; `startRound` warns and refuses if there aren't 2 free
    spawns left. Obstacle/goal `Touched` connections and the `CameraSync`
    relay are created fresh per round instance, each filtered to that
    instance's own `blindPlayer`/`guidePlayer` — multiple rounds can share
    listeners on the same physical geometry without cross-talk. Added
    `RoundService.isPlayerInRound` (used by `PairingService` to exclude
    already-playing players from pad occupancy) and a
    `Players.PlayerRemoving` handler to end a player's round and release
    its spawns if they disconnect mid-round — a real leak risk now that
    stale rounds aren't the only thing running on the server. Dropped the
    old `roundToken` mechanism entirely — no longer needed since each
    round is its own table instance rather than a reused module-level
    slot. Studio dev-bypass updated to pair off any 2 not-yet-in-a-round
    players rather than assuming exactly 2 players total.
  - `LobbyScreen.luau` simplified: "Invite Friend" now always calls
    `SocialService:PromptGameInvite` directly (no more branching on
    `game.PrivateServerId`, since the server is always public now).
  - `default.project.json`/`Remotes.luau`: removed the now-unused
    `RequestPairing` `RemoteEvent`.
  - `CLAUDE.md`/`backlog.md` updated to match (Phase 1 checked off
    pending playtest, Phase 2 multi-pair support noted as built).
  - **Not yet playtested at all** — needs the user's physical pairing-pad
    geometry in Studio (tagged `PairingPad`) to exercise Phase 1, and
    ideally 2+ free `TrustSpawn` pairs to actually exercise concurrent
    pairs running Blind Parkour at once. The existing Studio 2-client dev
    bypass still works without any pad geometry (skips straight to
    `RoundService.startRound`), but doesn't exercise `PairingService` at
    all.

Next: user builds/tags the physical pairing-pad geometry (`PairingPad`
tag) in Studio, then playtest Phase 1 pairing + confirm at least 2
concurrent pairs can run Blind Parkour on the shared course without
colliding (needs enough `TrustSpawn`-tagged spawn points for however many
concurrent pairs are being tested).

- User reported all 3 hazards suddenly not working. Diagnosed via Output
  (F9) in two parts:
  - `Remotes.luau`'s new hardened timeout (added earlier this session)
    confirmed `CameraSync` isn't in this Studio session yet — Rojo hasn't
    resynced since `default.project.json` changed. Not yet resolved on the
    user's end; needs a Rojo reconnect/resync.
  - Real, separate bug: `Workspace.RockSpawn1`/`RockSpawn2` reported
    missing. Root cause: the user regrouped the entire hazard course under
    a new `Workspace.BlindObby` folder while building the Phase 1 pairing
    lobby. `RotatingLogService` already looked for its objects under
    `BlindObby` (so it was unaffected), but `BoulderHazardService` and
    `LogGateService` still hardcoded top-level `Workspace.RockSpawn1/2/3`
    and `Workspace."Log Gate"` lookups. Fixed both to `WaitForChild`
    `BlindObby` first, then the hazard objects under it (matching
    `RotatingLogService`'s existing pattern) — same 10s-timeout-then-warn
    style, not a structural rewrite. `CLAUDE.md`'s "Environmental hazards"
    section updated to the new `Workspace.BlindObby.*` paths for all
    three.
  - Also recurring: the same malicious `TextureConfiguration`/`PoseTexture`
    asset script flagged earlier this session is still present and still
    throwing its blocked-by-sandbox error on every run — not yet removed
    by the user.
  - **Not yet confirmed working** — user needs to resync Rojo (for
    `CameraSync`) and re-test; the `BlindObby` path fix hasn't been
    playtested yet either.
- User built the Phase 1 Match Room (`Workspace."Match Room"`, 10 "Circle
  Pad" instances) and asked for a pre-lobby "Start Game" flow, replacing
  the old Invite Friend UI entirely. Built:
  - `Config.luau`: added `GAME_START_COUNTDOWN` (5s).
  - New remotes `RequestGameStart`/`GameStarting`
    (`default.project.json`/`Remotes.luau`).
  - New `LobbyService.luau` (server): any player firing
    `RequestGameStart` kicks off one shared countdown (guarded by a
    `countdownInProgress` flag so a second press mid-countdown is a
    no-op) — broadcasts `GameStarting` to all clients, waits the same
    duration server-side, then teleports everyone not already
    `RoundService.isPlayerInRound` into the Match Room, scattered around
    its pivot (no dedicated spawn markers there yet — flagged as a
    possible follow-up if scattering isn't precise enough).
  - New `StartGameScreen.luau` (client) replaces the deleted
    `LobbyScreen.luau` — "Start Game" button fires the request; on
    receiving `GameStarting` it runs its own local 5→1 visual countdown
    (not a tick-by-tick remote) then hides, timed to line up with the
    server's identical-duration wait.
  - `main.server.luau`/`main.client.luau` updated to wire in
    `LobbyService`/`StartGameScreen` in place of `LobbyScreen`.
  - Also flagged (not yet sized): with 10 pads, up to 10 pairs (20
    players) could lock in in one lobby-timer tick — needs at least that
    many `TrustSpawn` points on the Blind Parkour course or some rounds
    will fail to start (`RoundService.claimSpawns` warns and refuses).
  - **Not yet playtested.**
- User created `Workspace.BlindObby.BlindObbySpawnCenter` and asked to
  spawn Blind Parkour players around that single point instead of using
  tagged `TrustSpawn` markers. Reworked `RoundService.luau`: removed
  `claimSpawns`/`releaseSpawns`/`usedSpawns` and the `TrustSpawn` tag
  entirely (`Config.SPAWN_TAG` deleted, unused elsewhere) — every player
  now scatters randomly around `BlindObbySpawnCenter`'s pivot (8-stud
  radius) via `GetPivot()`, not `.CFrame` (works whether the marker ends
  up a Part or Model). This also resolves the capacity concern flagged
  earlier (needing ~20 `TrustSpawn` points for 10 concurrent pairs) —
  there's no exclusivity to claim anymore, so no ceiling on concurrent
  pairs from spawning alone. `startRound` now only refuses to start if
  `BlindObbySpawnCenter` itself is missing. `CLAUDE.md`/`backlog.md`
  updated to match. Not yet playtested.
- User asked how to observe the pairing lobby timer and pad registration
  while testing — there was no visibility into either. Chose to build a
  real in-game UI (not just debug prints):
  - `PairingService.luau`: each pad now has a `BillboardGui`/`TextLabel`
    ("0/2", "1/2", "2/2", or "Locked (2/2)" once closed) parented directly
    to it, updated live from the existing polling loop — no remote needed
    since it's just a normal replicating `Workspace` instance.
  - New remote `PairingCountdown` (`default.project.json`/`Remotes.luau`).
    The lobby-timer loop now broadcasts remaining seconds every second
    (not once per cycle like `GameStarting`) — this cycle repeats
    continuously and a client can join mid-cycle, so it can't reconstruct
    "time remaining" from a single message the way the Start Game
    countdown's local timer does.
  - New `PairingCountdownScreen.luau` (client): small always-on-screen HUD
    showing "Pairing locks in: Xs", driven entirely by the server
    broadcast above (no local timer).
  - `main.client.luau`: added its own `GameStarting` listener that starts
    `PairingCountdownScreen` after `task.delay(duration, ...)` — i.e. once
    the Start Game countdown would have finished and `LobbyService` will
    have teleported the client into the Match Room. Stops it on
    `RoundStarted` (now paired). This is a second, independent listener
    on the same remote `StartGameScreen` already listens to — intentional,
    keeps the two UI modules decoupled rather than one calling into the
    other.
  - `CLAUDE.md` updated to match. Not yet playtested.
- User reported two problems after trying it: (1) UI "looks bad, too
  basic," and buttons appear to get bigger the farther away you are; (2)
  the per-pad occupant counter flashes between 0 and 1 while standing
  still on a pad.
  - Root cause of (2): `findOccupants` used `Workspace:GetPartsInPart`
    against the pad's own (likely thin) collision geometry — a standing
    character rests on TOP of a thin platform rather than meaningfully
    inside its volume, so whether the exact-geometry overlap test
    registers flickers with ordinary physics jitter frame to frame. Fixed
    by checking a taller invisible zone above the pad's surface instead
    (`Workspace:GetPartBoundsInBox` with a custom box, `DETECTION_HEIGHT =
    6` studs), which reliably catches a standing character regardless of
    that jitter.
  - Root cause of (1), for the pad status BillboardGui specifically: it
    was sized with `UDim2.fromOffset(150, 50)` — pure Offset, zero Scale.
    For a BillboardGui (unlike a ScreenGui), the Scale component of Size
    is a stud measurement, not a percentage — a billboard with zero stud
    scale and only pixel offset doesn't behave like a normal world object
    and was rendering larger at distance instead of shrinking like one.
    Fixed by sizing it in studs (`UDim2.new(3, 0, 1, 0)`) and adding
    `MaxDistance = 40`.
  - Redesigned all 3 UI surfaces built this session for a more polished
    look (rounded `UICorner`, `UIStroke` accent borders, dark translucent
    panels, consistent blue accent color across all of them): the pad
    status billboard (`PairingService.luau`), `StartGameScreen.luau`
    (button + countdown — countdown is now a circular panel, not a bare
    label), and `PairingCountdownScreen.luau` (rounded HUD panel). Not
    touched: `BlindOverlay`/`ResultsScreen`/guide HUD label, since those
    weren't part of the complaint and weren't built this session.
  - Not yet playtested.
- User (testing solo) asked how to test with multiple players. Pointed to
  Studio's Test → Clients and Servers (pick a player count) as the way to
  simulate several players from one machine. In the process, noticed and
  removed the Studio-only dev-bypass in `RoundService.luau` (and the now-
  unused `RunService` import) — it auto-paired the first 2 joining players
  directly via `RoundService.startRound`, bypassing `LobbyService`/
  `PairingService` entirely. It existed because `TeleportService`-based
  private servers didn't work in local Studio testing, but that
  justification no longer applies: the whole Start Game → Match Room →
  pairing-pad flow is plain `Workspace` teleports now, so multiple local
  test clients exercise the real flow directly. Left in place, it would've
  silently started rounds before the user could test Start Game or the
  pads at all. `CLAUDE.md`'s "Known environment notes" updated to match.
