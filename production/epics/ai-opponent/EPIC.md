# Epic: AI Opponent (Minimal Vertical Slice)

> **Layer**: Feature
> **GDD**: design/gdd/ai-opponent.md
> **Architecture Module**: AI Opponent (Feature Layer)
> **Status**: Complete (VS in-slice) — 2026-07-27
> **Stories**: 8 stories — **6/6 VS-in-slice Complete** (001–006); **007 (diff-harness/fuzz corpus) + 008 (perf-budget assertion) TRIMMED to Production** (not in the VS, per `production/vertical-slice/scope.md` §4). The 6 in-slice stories deliver a full headless, deterministic, credible-not-masterful AI that takes complete turns via `AITurnDriver`. 74 tests, all green.

## Overview

The AI Opponent is the Feature-layer computer rival that plays the full tempo-duel
economy through the exact same queries and atomic `apply_action` the player uses —
no privileged information, no privileged cost, no hidden currency. Each turn is a
repeating **clone → enumerate-all-legal-affordable-actions → score-on-one-normalized-scale
→ commit-best** loop, terminating when no candidate clears `PASS_THRESHOLD` or the
win-check ends the match. For the Vertical Slice it is deliberately scoped to a
**simple greedy / tempo-competent heuristic** (one-ply, no deep search), per the
systems-index guidance to "ship a simple greedy heuristic first, deepen later."
Architecturally it is a pure policy consumer: it holds no balance constant, reads
only via the approved query set (`reachable`, `legal_targets` / hypothetical,
`preview_damage`, `can_afford`, `legal_build_tiles` / `legal_deploy_tiles`,
`completed_outpost_count`, `legal_research_targets`), and is fully deterministic
(ties broken by lowest `ap_cost` then lowest entity ID, no RNG). Concrete shape
(ADR-0011): `AI` (static, `RefCounted`), `AITurnDriver` (`Node`, the only caller of
`apply_action`), `AIConfig` (`Resource`, 15 `@export` knobs).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0011: AI query-façade & headless decision loop | DI query-façade; headless clone→enumerate→score→commit loop; rejection handling; 15 tunable knobs; `LETHAL_FLOOR_BONUS > economy-ceiling` cross-knob invariant; per-commit streaming; perf budget | LOW (QQ-06 spike CLEARED PASS 2026-07-25) |
| ADR-0003: Deterministic simulation & RNG isolation | No engine RNG in transitions; deterministic tie-break (`SCORE_TIE_EPSILON`, lowest `ap_cost`, lowest entity ID) | LOW |

## GDD Requirements

All 17 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0011 (decision loop / scoring / perf / harness) | TR-ai-001, -002, -003, -004, -005, -006, -007, -008, -009, -010, -012, -013, -014, -015, -016, -017 | ✅ |
| ADR-0003 (deterministic selection) | TR-ai-011 | ✅ |

**Untraced Requirements**: None.

## Scope (Minimal VS)

**In scope:** the single "balanced tempo-racer" competence level — one-ply greedy
density scoring (`combat_value`, `production_value`, `economy_value`, `research_value`
→ `action_score`) plus the positional/retreat move exceptions; the full
clone→enumerate→score→commit loop; deterministic tie-break; rejection handling;
per-commit streaming; the AI-vs-human `apply_action` diff harness and the seeded /
fuzz corpus.

**Out of scope (deferred per the GDD Open Questions):** difficulty tiers (OQ-4),
relative-economy / opponent-aware weighting (OQ-7), 1-ply baitability counter-check
(OQ-8), cancel-build threat-awareness (OQ-3), Faction-Identity per-faction weighting
(OQ-6). **AC-34 (win-rate band) is aspirational** — it needs a reference-opponent
build + match harness that does not yet exist (OQ-9); do not count it among
testable-now stories.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All in-scope acceptance criteria from `design/gdd/ai-opponent.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The AI-vs-human diff harness proves field-level equivalence (position / hp / `current_ap` / existence) between an AI-committed action and the same action committed by a human through `apply_action`, and the seeded + fuzz corpus proves `current_ap` never goes negative

## Dependencies & Sequencing

- **Depends on (Complete):** Foundation (`clone()`/`apply_action`/`current_ap`/`ap_income_breakdown`/`entities`/`entity_at`/`match_status`/`manhattan_distance`), Unit System, Movement, Combat Resolution, Base & Production — the live queries the scorer consumes. Fully headless and independent of both Presentation epics; buildable in parallel (shares no files, needs no rendered board).
- **QQ-06 perf-spike gate — ALREADY SATISFIED (PASS, 2026-07-25):** ~3.7 ms p95 per `choose_action()` at N≤24 on the pinned 14×16 board (~2 orders of magnitude headroom); bench `prototypes/spikes/qq06_ai_loop_bench.gd`. ADR-0011 is Accepted on that basis with full re-enumeration (no incremental-invalidation fallback needed). **No outstanding spike-gate — this epic may proceed straight to `/create-stories`.** (Implementation tripwire: if a future roster grows N > 24, a playtest check re-opens the perf question — does not gate VS stories.)
- **Story-authoring caveat:** AC-5 / AC-6b (query-instrumentation seam) and AC-24 (`apply_action` interception to inject a between-clone-and-commit mutation) require the DI-façade + interception seams ADR-0011 defines — confirm those seams exist in ADR-0011 before writing the stories that assert them.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | AIConfig — 15 Knobs + LETHAL_FLOOR_BONUS Cross-Knob Invariant | Logic | Ready | ADR-0011 |
| 002 | Query-Façade Allowlist + Deterministic Entity Enumeration | Logic | Ready | ADR-0011, ADR-0003 |
| 003 | Scoring — combat_value, production_value, Lethal Floor, HQ Siege | Logic | Ready | ADR-0011 |
| 004 | Scoring — economy, research (stubbed), positional/retreat/cancel, cadence cap | Logic | Ready | ADR-0011 |
| 005 | Deterministic Tie-Break Comparator (`_is_better`) | Logic | Ready | ADR-0003, ADR-0011 |
| 006 | AITurnDriver — Loop, Termination, Rejection, Streaming | Integration | Ready | ADR-0011 |
| 007 | AI-vs-Human Diff Harness + Seeded/Fuzz Corpus | Integration | Ready | ADR-0011, ADR-0003 |
| 008 | Perf-Budget Assertion (ports the cleared QQ-06 bench) | Integration | Ready | ADR-0011 |

**Implementation order**: 001 → 002 → {003, 004 parallel} → 005 → 006 → {007, 008 parallel}.
Fully headless/deterministic; no Board Renderer or CAI seam dependency.

> **⚠ Deferred integration points** (flagged in-story, not blocking the breakdown):
> - **Story 004** `research_value` enumeration is stubbed to return no candidates until the
>   **Research/Tech epic** implements `legal_research_targets` — the formula ACs are unit-testable
>   today; re-enable the enumeration when Research lands.
> - **CI query-allowlist lint** (AC-5/AC-14 enforcement) is routed by ADR-0011 to godot-specialist/CI
>   tooling — a separate **tools-programmer** task, not an AI-epic story. The allowlist *property* is
>   covered by Story 002's ACs.
> - **Story 006** adds `PlayerState.is_ai_controlled` — owes a non-blocking follow-up note to ADR-0001.
> - AC-34 (win-rate band vs a reference opponent) is out of scope — no reference-opponent harness (OQ-9).

## Next Step

Run `/story-readiness production/epics/ai-opponent/story-001-ai-config-knobs-invariant.md`,
then `/dev-story` to begin. Work through stories in dependency order (001 → 008).

