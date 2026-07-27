# Architecture Review Report — OVERCLOCK

- **Date:** 2026-07-25
- **Engine:** Redot 26.2 (Godot 4.6-compatible fork)
- **GDDs Reviewed:** 12 (Vertical-Slice corpus)
- **ADRs Reviewed:** 18 (ADR-0001 … ADR-0018, all `Proposed`)
- **Mode:** `/architecture-review` (full)
- **Source of stable IDs:** `docs/architecture/tr-registry.yaml` (v3)

---

## Verdict: ✅ PASS

First full-coverage result for the corpus. All 200 technical requirements are covered by
written governing ADRs; the three prior cross-ADR conflicts are verified fixed; the dependency
graph is acyclic and well-ordered; engine compatibility is consistent across all 18 ADRs and
independently re-confirmed for the two new ones (ADR-0017/0018); and no GDD assumption conflicts
with verified engine reality. ADR-0017 and ADR-0018 closed exactly the gaps they were written to
close, with signatures matching their forward-declared contracts in ADR-0011/0015.

---

## Traceability Summary

- **Total requirements:** 200
- ✅ **Covered:** 200
- ⚠️ **Partial:** 0
- ❌ **Gaps:** 0

The 7 TRs that were ⚠️ Partial in the 2026-07-24 review (parked on the then-unwritten
ADR-0017/0018) are now fully covered. ADR-0017 addresses TR-baseprod-002/003/005/008; ADR-0018
addresses TR-research-003/004/005. Both ADRs' "GDD Requirements Addressed" sections and Decision
bodies specify each requirement concretely, and the registry `adr:` fields already point at them.

## Coverage Gaps (no ADR exists)

**None — full coverage.** 200/200 TRs map to a written governing ADR whose own text specifies the
requirement. This is the first review in which the corpus reaches 100% coverage.

## Cross-ADR Conflicts

**None found.** The three integration-contract conflicts from the 2026-07-24 review are verified
fixed in ADR-0006:

- **C1** — `static func current_ap(state, player)` pass-through present (ADR-0006).
- **C2** — `ap_income_breakdown(state, player) -> Dictionary` declared, with `income()` defined as
  its sum.
- **C3** — the duplicate `* min(n, threshold)` removed; the `econ_tech` term now consumes
  `Research.economy_tech_income_bonus()` verbatim, cap applied exactly once.

ADR-0017 and ADR-0018 introduce no new data-ownership, integration-contract, performance-budget,
dependency-cycle, architecture-pattern, or state-management conflicts. State authority remains
cleanly single-owned (AP → `PlayerState.current_ap`; hp → `EntityState.current_hp`; occupancy →
`GridState`; tech flags → `PlayerState` via `advance_research_timers` as sole writer; per-Lab
research state → `StructureState`). Both new ADRs reuse the established static-utility +
apply_action + clone-free-config pattern with no ownership overlap (ADR-0018 reads ADR-0017's
`cancel_refund_pct` read-only; ADR-0017's `effective_production_cap` honors ADR-0012's two-sided
invariant).

## ADR Dependency Order

Acyclic, well-ordered. No true `Depends On` edge points at a higher-numbered ADR (forward-declared
contracts are declaration-only and create no back-edges). The 2026-07-24 topological order extends
cleanly with the two new Core ADRs appended:

```
Layer 0:  0001
Layer 1:  0003, 0002
Layer 2:  0005, 0004, 0006
Layer 3:  0007, 0013
Layer 4:  0008, 0009, 0010, 0014
Layer 5:  0011
Layer 6:  0012, 0015
Layer 7:  0016
Core mechanics (slot after 0008/0010, before their epics):  0017 (B&P), then 0018 (Research; depends on 0017)
```

Valid linear order:
`0001 → 0003 → 0002 → 0005 → 0004 → 0006 → 0007 → 0013 → 0008 → 0009 → 0010 → 0014 → 0011 → 0012 → 0015 → 0016 → 0017 → 0018`.

**FYI (not a defect):** all 18 ADRs are `Proposed`, so no requirement is yet
implementation-ready (stories on `Proposed` ADRs are auto-blocked per `docs/CLAUDE.md`). Accepting
bottom-up in the order above — after running the still-open perf/engine spikes (QQ-05→0009,
QQ-06→0011, iso+dual-focus→0013/0014) — is the path to gate-readiness.

## GDD Revision Flags

**None — all GDD assumptions consistent with verified engine behaviour.** No HIGH-risk engine
finding exists in the two new ADRs (both LOW knowledge risk, pure logic-layer GDScript). The one
GDD representation delta ADR-0017 owed — base-production.md's `CANCEL_REFUND_RATE = 0.5` float vs
the ADR's fixed-point `cancel_refund_pct: int = 50` — is already reconciled in the GDD (the
fixed-point footnote is present; numerically identical, no behavior change). research-tech.md's
tech-flag permanence, Lab-destruction revert, cross-Lab mutual exclusion, and 0.5 cancel-refund
reuse match ADR-0018 exactly.

## Engine Compatibility Issues

Engine: Redot 26.2 / Godot 4.6. Engine Compatibility sections present: **18 / 18**. No
deprecated-API references, no stale version references, no post-cutoff API conflicts across the
set. Both new ADRs correctly specify `duplicate_deep()` (4.5+) with the corpus-wide shared
semantics (path-less Resources deep-copied; preload'd path-having Resources shared by reference)
and reference no deprecated API.

### Engine Specialist Findings (godot-specialist, 2026-07-25 — second opinion on ADR-0017/0018)

- **Confirmed, no blocking issues.** Both ADRs touch zero post-4.3 API surface (no
  TileMap/Jolt/dual-focus/rendering/physics) — pure static-typed GDScript over
  `RefCounted`/`Dictionary`/`Array[T]`/`Resource`, exactly where the 4.3→4.6 knowledge gap does
  not apply.
- Verified idiomatic for 4.6: `RefCounted` static-utility shape; `Array[Vector2i]`/`Array[TechDef]`
  typed returns; `sort_custom(Callable)` (the deprecated string form is pre-4.0, correctly
  avoided); integer `/` = floor for non-negative operands (refund arithmetic correct); Resource-ref
  `==`/`in` identity on preload'd registries; `null == tech` → false; `@export bool` value-copy on
  clone; `duplicate_deep()` keeping preload'd `TechDef`/`producible_types` shared by reference (the
  guarantee the post-clone `==` relies on); Dictionary-as-set + trailing `sort_custom` for
  determinism; config-as-Resource out of the clone graph.
- No engine anti-patterns missed (no `get_node` chasing, no `_process` polling, no
  `runtime_load_of_type_templates`).
- **One non-blocking documentation nit (ADR-0018 D1):** the Engine-Review summary line calls the
  three tech flags "`@export` bool" but the D1 code snippet shows plain typed fields
  (`has_attack_tech: bool = false`) with no `@export`. One-line internal-consistency fix (decide
  whether inspector/save visibility needs `@export`); not a correctness issue.
- The sole open engine residual in the whole set remains ADR-0014's Godot 4.6 dual mouse/keyboard
  focus split (a gated pre-Accept spike) — untouched by these two ADRs.

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1.0) maps all 12 systems into the 5-layer model with no
orphaned architecture. The prior review's B&P/Research caveat — that both appeared as Core
"gameplay verb" modules routed through 0002/0007/0008 + forward-declared queries rather than a
dedicated ADR — is now closed: ADR-0017 and ADR-0018 supply the missing build/produce/research
mechanics and per-Lab state machine. The master doc's data-flow already listed the relevant
signatures (`ap_income_breakdown`, `legal_build_tiles`, `legal_deploy_tiles`,
`legal_research_targets`), which the two ADRs now formally own. No orphaned systems; no system in a
GDD is missing from the architecture.

## Blocking Issues (must resolve before PASS)

None. (Verdict is PASS.)

Non-blocking, pre-Accept housekeeping (does not affect this PASS):

1. ADR-0018 D1 `@export` annotation consistency (one-line, per specialist).
2. Run the still-open Accept-gate spikes (QQ-05, QQ-06, ADR-0013 iso, ADR-0014 dual-focus) before
   flipping ADRs `Proposed → Accepted`.
3. Pre-gate UX artifacts — **both now complete** as of this session: `design/ux/interaction-patterns.md`
   (APPROVED via `/ux-review`) and `design/accessibility-requirements.md` (Standard tier, authored).
   These gate `/gate-check pre-production`, not this architecture review.

## Required ADRs

**None — architecture is complete.** The 18-ADR plan is fully written and maps 200/200
requirements. No further ADRs are required for the Vertical-Slice scope. (The deferred Persistence
& Campaign system and Full-Vision Vehicle/Mech tier are out of VS scope and will need their own
ADRs when designed.)

---

## Appendix — Coverage by System

Primary governing ADR per `tr-registry.yaml` (v3); totals to 200. Full machine-readable per-TR
mapping lives in `tr-registry.yaml`.

| System | GDD | # TRs | Governing ADR(s) | Status |
|--------|-----|-------|------------------|--------|
| Grid & Terrain | grid-terrain.md | 15 | ADR-0005 (11), 0001 (2), 0011 (1), 0013 (1) | ✅ |
| Game State & Turn Manager | game-state-turn-manager.md | 19 | ADR-0001 (9), 0002 (4), 0003 (2), 0008 (2), 0004 (1), 0011 (1) | ✅ |
| AP Economy | ap-economy.md | 14 | ADR-0006 (11), 0003 (1), 0008 (1), 0012 (1) | ✅ |
| Unit System | unit-system.md | 15 | ADR-0007 (7), 0001 (2), 0010 (2), 0006 (1), 0009 (1), 0012 (1), 0016 (1) | ✅ |
| Movement System | movement-system.md | 14 | ADR-0009 (9), 0003 (3), 0002 (1), 0007 (1) | ✅ |
| Combat Resolution | combat-resolution.md | 14 | ADR-0010 (11), 0007 (2), 0003 (1) | ✅ |
| Base & Production | base-production.md | 17 | ADR-0007 (4), **0017 (4)**, 0010 (3), 0008 (2), 0002 (1), 0003 (1), 0006 (1), 0016 (1) | ✅ |
| Research / Tech | research-tech.md | 13 | ADR-0007 (3), **0018 (3)**, 0010 (1), 0001 (1), 0002 (1), 0003 (1), 0006 (1), 0008 (1), 0016 (1) | ✅ |
| Command & Action Interface | command-action-interface.md | 24 | ADR-0015 (14), 0014 (6), 0013 (4) | ✅ |
| Game HUD | game-hud.md | 23 | ADR-0016 (16), 0004 (3), 0013 (2), 0006 (1), 0014 (1) | ✅ |
| AI Opponent | ai-opponent.md | 17 | ADR-0011 (16), 0003 (1) | ✅ |
| Faction Identity | faction-identity.md | 15 | ADR-0012 (15) | ✅ |

**New TR-IDs minted this run:** None. ADR-0017/0018 satisfy 7 already-registered TRs
(TR-baseprod-002/003/005/008, TR-research-003/004/005); no new requirements extracted.

**Registry text revisions this run:** None. All 200 entries retain original `requirement` text;
no ID renumbered, deprecated, or superseded. (The v3 bump — already recorded — only re-pointed the
7 `adr:` fields to ADR-0017/0018.)
