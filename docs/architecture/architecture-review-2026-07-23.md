# Architecture Review Report — OVERCLOCK

- **Date:** 2026-07-23 (re-validation — supersedes the earlier same-day run)
- **Mode:** `/architecture-review` (full) · review-mode: lean
- **Engine:** Redot 26.2 (Godot 4.6-compatible fork)
- **GDDs Reviewed:** 12 (all Vertical-Slice systems)
- **ADRs Reviewed:** 8 (ADR-0001 … ADR-0008 — all **Proposed**)

The earlier same-day report validated 4 ADRs (0001/0002/0003/0005). Since then the
4 remaining Foundation ADRs — 0004 (event/signal), 0006 (AP economy), 0007
(entity/stat schema), 0008 (start-of-turn sequencing) — were authored. **All 8
Foundation ADRs now exist.** This run re-validates coverage, conflicts, dependency
order, and engine consistency across the full Foundation set.

---

## Traceability Summary

| Metric | This run | Prior same-day run |
|---|---|---|
| Total requirements | 200 | 200 |
| ✅ Covered (governing ADR written) | **84** | 42 |
| ⚠️ Partial | 0 | 0 |
| ❌ Gap (governing ADR planned, unwritten) | **116** | 158 |

The TR registry (`tr-registry.yaml` v2) is authoritative: 200/200 requirements mapped
to a governing ADR, 0 deprecated. **No requirement lacks a planned ADR** — every gap is
a not-yet-written ADR (0009–0016), not a coverage hole. Coverage nearly doubled with the
4 new ADRs.

## Per-System Coverage

| System | ✅ Covered | ❌ Gap | Gaps blocked on (unwritten ADR) |
|---|---|---|---|
| gamestate | 18 | 1 | ADR-0011 |
| grid | 13 | 2 | ADR-0011, ADR-0013 |
| apecon | 13 | 1 | ADR-0012 |
| unit | 10 | 5 | ADR-0009 / 0010 / 0012 / 0016 |
| baseprod | 9 | 8 | ADR-0010, ADR-0016 |
| research | 8 | 5 | ADR-0010, ADR-0016 |
| movement | 5 | 9 | ADR-0009 |
| combat | 3 | 11 | ADR-0010 |
| hud | 4 | 19 | ADR-0013 / 0014 / 0016 |
| ai | 1 | 16 | ADR-0011 |
| faction | 0 | 15 | ADR-0012 |
| cmdui | 0 | 24 | ADR-0013 / 0014 / 0015 |
| **Total** | **84** | **116** | |

**Foundation-layer authoring is complete (8/8 ADRs).** All 116 gaps fall in the
Core / Feature / Presentation layers, governed by the 8 build-time-of-system ADRs
(0009–0016), exactly as the master architecture planned.

### Coverage Gaps (all are planned, unwritten ADRs — not orphans)

| ADR (unwritten) | Layer | TRs | Suggested title |
|---|---|---|---|
| ADR-0010 | Core | 24 | Combat resolution & damage model |
| ADR-0016 | Presentation | 19 | HUD data-binding & panel model |
| ADR-0011 | Feature | 18 | AI decision loop & lookahead over `clone()` |
| ADR-0012 | Feature | 17 | Faction identity fold (income/loadout deltas) |
| ADR-0015 | Presentation | 14 | Command / action interface FSM |
| ADR-0009 | Core | 10 | Pathfinding & reachability |
| ADR-0013 | Presentation | 7 | Isometric render/projection layer (HIGH engine risk) |
| ADR-0014 | Presentation | 7 | Input & picking (HIGH engine risk) |

---

## Cross-ADR Conflicts — NONE

All 8 ADRs compared pairwise for data-ownership, integration-contract, performance-budget,
dependency, pattern, and state-authority conflicts. None found. The forward-declaration
handoffs are clean producer/consumer contracts, not conflicts:

- ADR-0006 forward-declares `completed_outpost_count()` / `economy_tech_income_bonus()` →
  **ADR-0007 supplies the concrete implementation.**
- ADR-0002 forward-declares `AP.spend()` as the sole AP deductor → **ADR-0006 fulfills it.**
- ADR-0004 formally defines the `Event` base class that ADR-0002 forward-referenced →
  ADR-0008 rides 2 new Event subclasses on ADR-0004's `action_applied` signal.
- Win-check authority is unambiguous: `apply_action` (ADR-0002) owns `run_win_check`;
  combat (ADR-0010, future) only produces the HQ-damaging mutation.

**Coordination note (not a conflict):** ADR-0008 introduces `GameState.starting_player`
(immutable after `start_match`), a field that logically belongs to ADR-0001's schema.
ADR-0001's `referenced_by` was updated for it; confirm it appears in ADR-0001's field
list when ADR-0001 moves to Accepted.

## ADR Dependency Order (topologically sorted — acyclic ✅)

Every `Depends On` edge points to a lower-numbered ADR; no cycles, no unresolved
external targets within the Foundation set.

```
Foundation (no deps):            ADR-0001  State model ownership & lifecycle
Depends on 0001:                 ADR-0002  apply_action command model
                                 ADR-0003  Deterministic simulation & RNG isolation
Depends on 0001 + 0002:          ADR-0004  Event / signal architecture
                                 ADR-0006  AP economy data model & spend contract
Depends on 0001 + 0003:          ADR-0005  Grid representation & map format
Depends on 0001/02/05/06:        ADR-0007  Unit & Structure entity/stat schema
Depends on 0001/02/04/06/07:     ADR-0008  Shared start-of-turn sequencing
```

**Caveat:** all 8 ADRs are `Proposed`, none `Accepted`. Nothing in the cluster is
implementation-ready until the Accept pass runs — and it gates on accepting ADR-0001
first (every other ADR transitively depends on it). Stories referencing a `Proposed`
ADR are auto-blocked (per `docs/CLAUDE.md`).

## Engine Compatibility — no blocking issues

- **Post-cutoff APIs:** `Resource.duplicate_deep()` (4.5) in ADR-0001 & ADR-0007;
  typed `Dictionary[int, EntityState]` / `Array[…]` (4.4) in ADR-0001 & ADR-0007.
  Used consistently — ADR-0007 *complements* ADR-0001 by refining the path-having
  (`preload`'d) Resource case (shared, not deep-copied, per `core/io/resource.cpp`
  `_duplicate_recursive()` gated on `is_built_in()`), not a contradictory assumption.
  All other ADRs declare "Post-Cutoff APIs Used: None".
- Each ADR carries a **dated godot-specialist review (2026-07-23)** in its Engine
  Compatibility block. The load-bearing `duplicate_deep()` deep-copy + zero-signal-carry
  behavior is CONFIRMED. Prior advisories **E2** (widen ADR-0001 clone spike to a typed
  Dictionary) and **E3** appear addressed — ADR-0001 now lists the typed Dictionary
  explicitly in its post-cutoff APIs.
- **Deprecated APIs:** none used. String-based `connect("sig", obj, "method")`
  (removed in 4.0) is noted project-wide; all connections use the modern `Callable` form.
- **Engine specialist re-consultation skipped (lean mode):** every ADR already embeds a
  fresh, dated specialist review authored the same day. Re-spawning would duplicate
  completed work with no new surface to check.

## GDD Revision Flags — None

No new HIGH-risk engine findings, so no GDD assumption is contradicted by verified engine
behaviour. The prior open item — `unit-system.md` declaring `defense` / `targeting_mode` /
`min_range` / `can_counterattack` in-schema — is already RESOLVED and folded into existing
TR-IDs. No new TR-IDs to register (registry is same-day current, v2).

---

## Verdict: CONCERNS

Internally consistent and coherent — Foundation authoring complete, zero cross-ADR
conflicts, acyclic dependency graph, engine-clean. **Not gate-ready**, because:

1. All 8 ADRs are **Proposed**, none **Accepted**. The cluster gates on accepting ADR-0001.
2. **8 ADRs unwritten** (0009–0016) → 116 TRs uncovered, all in the Core / Feature /
   Presentation layers.
3. **All 5 pre-gate infrastructure items are missing** (tests, CI, UX/accessibility docs).

Not a FAIL: no Foundation-layer requirement is uncovered and no blocking conflict exists.

### Required ADRs (most foundational first)

1. **ADR-0009** Pathfinding & reachability — unblocks 9 movement TRs; needed before combat/AI.
2. **ADR-0010** Combat resolution — 24 TRs (largest Core gap).
3. **ADR-0011** AI decision loop over `clone()` — 16 ai TRs (largest single gap).
4. **ADR-0012** Faction identity fold — 15 faction TRs.

### Pre-Gate Checklist (all ❌ — required before `/gate-check`)

- ❌ `tests/unit/` → run `/test-setup`
- ❌ `tests/integration/` → run `/test-setup`
- ❌ `.github/workflows/tests.yml` → run `/test-setup`
- ❌ `design/ux/interaction-patterns.md` → run `/ux-design`
- ❌ `design/accessibility-requirements.md` → run `/ux-design`
