# Backlog

## Current phase
**MVP redefined (2026-07-17) — 4-phase party-game loop, multi-pair lobby.**
See `CLAUDE.md`'s "Core mechanics" section for the full phase breakdown.
This replaces the old "Trust round only" MVP definition below.

## Roadmap
- [x] **Phase 1 — Pairing round**: `PairingService.luau` rewritten —
      pairing pads (`Config.PAIRING_PAD_TAG`), polled occupancy, one
      lobby-wide countdown (`Config.PAIRING_TIMER_DURATION`), random
      pairing on pad overflow, `ProximityPrompt` "Close Pad" to lock in an
      intended pair early. Calls `RoundService.startRound` directly to
      form pairs. **Not yet playtested** — needs the physical pad geometry
      (user is building this) tagged `PairingPad` before it can be
      exercised at all.
- [ ] **Phase 2 — Physical challenge**: random selection among a set of
      physical co-op minigames.
      - [x] Blind Parkour (the old "Trust round") — level geometry + tags,
        3 environmental hazards (Boulder Cannon, Log Gate, Rotating Log —
        knockback, not scoring; all 3 now live under `Workspace.BlindObby`),
        guide camera-mirror mechanic, and multi-pair support (`RoundService`
        reworked 2026-07-17: per-player round state instead of a single
        module-level round, all pairs share one course). Spawning switched
        same day from tagged `TrustSpawn` markers (removed) to scattering
        around `Workspace.BlindObby.BlindObbySpawnCenter` — no more spawn
        capacity ceiling on concurrent pairs. Full end-to-end Studio
        playtest — including actually running 2+ concurrent pairs at once
        — still not confirmed.
      - [ ] Any additional physical minigames — not designed yet.
      - [ ] Random-selection logic across whichever minigames exist (today
        Blind Parkour is the only option, so there's nothing to select
        between yet).
- [ ] **Phase 3 — Personality challenge**: guess-your-partner's-preferences
      minigame (e.g. favorite food). Not designed or built yet. Must stay
      strictly friendship-framed, never romantic/dating-quiz framed.
- [ ] **Phase 4**: TBD — no design yet.
- [ ] **Compatibility scoring**: aggregate per-pair score across all
      phases, rank pairs against each other at the end, declare the
      highest-scoring pair the winning/most-compatible team.
      `ScoreService` currently only implements the Blind Parkour formula
      for a single round — needs to become a cross-phase aggregator.
- [ ] **v1 (post above)**: score history per friend-pair, basic cosmetic
      shop.
- [ ] **Post-launch**: Quick Match / stranger entry into a lobby, weekly
      rotating challenge pool, leaderboards.

## What NOT to build yet
Intentional scope cuts, not oversights. Don't reintroduce any of these into
a plan or implementation without asking first:
- Leaderboards, score history persistence (DataStore) — MVP uses
  in-session state only.
- Any romantic/dating framing, ever, in any copy or UI (see CLAUDE.md) —
  applies with extra weight to the Phase 3 personality round.

**Correction (2026-07-17, same day as the pivot):** the lobby is a normal
public server — anyone can join, it's not friend-invite-gated. There is no
"Quick Match" cut anymore; open lobby entry was always the intended
design, an earlier pass in this same session assumed wrong.

## Superseded (kept for history, don't follow)
- Old MVP definition: "Trust round + friend-pairing only, 2-round rotation
  (Trust + Coordination), exactly 2 players per private server." Replaced
  2026-07-17 by the 4-phase multi-pair structure above.
- Old cut item "the third mini-challenge (decision-speed round)" — no
  longer a cut; the new plan explicitly has more than 2 phases/minigames.
