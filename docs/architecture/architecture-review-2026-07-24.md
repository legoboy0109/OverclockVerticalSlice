# Architecture Review Report — OVERCLOCK

> **Date:** 2026-07-24
> **Mode:** `/architecture-review` (full)
> **Engine:** Redot 26.2 (Godot 4.6-compatible fork)
> **GDDs Reviewed:** 12 (Vertical-Slice corpus)
> **ADRs Reviewed:** 16 (ADR-0001 … ADR-0016, all `Proposed`)
> **Supersedes:** `architecture-review-2026-07-23.md` (that run: 8 of 16 ADRs written)

---

## Verdict: CONCERNS

The architecture is coherent, its dependency graph is acyclic and well-ordered, it is
engine-consistent, and the full 16-ADR set now exists mapping all 200 technical
requirements. It is **not gate-ready as written**: three cross-ADR integration-contract
conflicts (one a genuine correctness bug) and one Core-layer coverage gap must be resolved
before the ADRs move `Proposed → Accepted`.

Under a strict gate, conflict **C3** alone (Economy-Tech income double-cap) would justify
FAIL until its one-line fix lands. Because every ADR is still `Proposed` and all three fixes
are surgical, the corpus is scored **CONCERNS** rather than FAIL.

---

## Traceability Summary

| | Count |
|---|---|
| Total requirements (registry v3) | 200 |
| ✅ Covered (governing ADR written + specifies the requirement) | 193 |
| ⚠️ Partial (governing ADR planned, not yet written) | 7 |
| ❌ Uncovered (no ADR at all) | 0 |

All 200 TRs map to an ADR in `tr-registry.yaml`. The 7 ⚠️ Partial are the Base &
Production / Research mechanic TRs re-pointed this run to the **planned-but-unwritten**
ADR-0017 / ADR-0018 (see Coverage Gap below).

### Per-system coverage

| System | TRs | Governing ADR(s) | Status |
|--------|-----|------------------|--------|
| Grid & Terrain | 15 | ADR-0005 (+0001, 0013) | ✅ |
| Game State & Turn Manager | 19 | ADR-0001 / 0002 / 0008 (+0003, 0004, 0011) | ✅ |
| AP Economy | 14 | ADR-0006 (+0007, 0003) | ✅ |
| Unit System | 15 | ADR-0007 | ✅ |
| Movement | 14 | ADR-0009 | ✅ |
| Combat Resolution | 14 | ADR-0010 | ✅ |
| **Base & Production** | 17 | ADR-0007 / 0008 / 0002 / 0010 / 0006 / 0016 **+ 4 → ADR-0017 (planned)** | ⚠️ |
| **Research / Tech** | 13 | ADR-0007 / 0008 / 0002 / 0006 / 0001 / 0010 **+ 3 → ADR-0018 (planned)** | ⚠️ |
| Command & Action Interface | 24 | ADR-0015 | ✅ |
| Game HUD | 23 | ADR-0016 | ✅ |
| AI Opponent | 17 | ADR-0011 | ✅ |
| Faction Identity | 15 | ADR-0012 | ✅ |

---

## Coverage Gap — Base & Production / Research mechanics (Core layer)

Base & Production and Research/Tech are the **only two Core systems without a dedicated
governing ADR** (AP → 0006, entities → 0007, movement → 0009, combat → 0010; B&P and
Research got none). Their state schema lives in ADR-0007, their mutation vector in ADR-0002
(`apply_action` verb handlers), their timers in ADR-0008, their destruction in ADR-0010,
and their principal query signatures are **forward-declared** in ADR-0011 and consumed by
ADR-0015. But **no ADR specifies the build/produce/research algorithms or the per-Lab
research state machine.**

Seven TRs were parked on `ADR-0010` in the registry, yet ADR-0010's own "Requirements
Addressed" section covers only the combat/destruction slice (baseprod-010/011/012,
research-008) — it disclaims these seven:

| TR | Requirement (the mechanic, not its destruction) | Re-pointed to |
|----|--------------------------------------------------|---------------|
| TR-baseprod-002 | Structure instance FSM (Under-Construction→Completed→Destroyed→Removed); per-instance runtime fields | ADR-0017 |
| TR-baseprod-003 | Structures occupy 1 tile, hard blocker for movement + DIRECT LoF, targetable while building | ADR-0017 |
| TR-baseprod-005 | `legal_build_tiles(player,type)` placement/adjacency rules, live-recomputed | ADR-0017 |
| TR-baseprod-008 | `produce(producer,type,tile)` validation + chosen deploy tile (`legal_deploy_tiles`) | ADR-0017 |
| TR-research-003 | Per-player tech-unlock flags (has_attack/defense/economy_tech), permanent, survive Lab loss | ADR-0018 |
| TR-research-004 | Per-Lab research state + cross-Lab mutual exclusion | ADR-0018 |
| TR-research-005 | `legal_research_targets(lab)` exclusion set | ADR-0018 |

**Resolution (user decision, 2026-07-24):** author **ADR-0017 — Base & Production
Mechanics** (build FSM, `legal_build_tiles`, `produce`/deploy) and **ADR-0018 —
Research/Tech Mechanics** (per-Lab research state, `legal_research_targets`, tech-unlock
effects). The registry `adr:` fields for the 7 TRs now point to ADR-0017/0018; they are
⚠️ Partial until those ADRs are written. The forward-declared signatures in ADR-0011/0015
are the binding contract those ADRs must honour.

---

## Cross-ADR Conflicts

> **✅ Post-review update (2026-07-24, same session):** All three conflicts below were **fixed**
> immediately after this report. C3/C1/C2 are resolved entirely within ADR-0006 (with a
> non-behavioral ownership annotation added to ADR-0007). No consumer ADRs required edits.
> `income()` is now defined as the sum of `ap_income_breakdown()`, so the per-term breakdown and
> the total cannot drift and the Economy-Tech cap is applied exactly once. See each conflict's
> Resolution line for what changed.

All three are **integration-contract drift** on forward-declared AP-adjacent contracts.
Each was confirmed against ADR source text. No data-ownership, performance-budget,
dependency-cycle, architecture-pattern, or state-management conflicts were found — state
authority is cleanly single-owned throughout (AP → `PlayerState.current_ap` via `AP.spend`;
hp → `EntityState.current_hp` via Combat; occupancy → `GridState.occupancy` by `entity_id`).

### 🔴 C3 — `economy_tech_income_bonus` double-applies the tier cap · HIGH (correctness bug)

- **ADR-0007** (`economy_tech_income_bonus()`, lines 206–211) returns the **already-tiered,
  already-capped** value: `ECONOMY_TECH_INCOME_BONUS * min(completed_outpost_count(...),
  ECONOMY_TECH_TIER_THRESHOLD)` (and internally guards `has_economy_tech`, returning 0 if absent).
- **ADR-0006** (`income()`, line 139) multiplies that return **again**:
  `tech = Research.economy_tech_income_bonus(state, player) * min(n, cfg.economy_tech_tier_threshold)`.
- **Impact:** the `min(n, threshold)` factor is squared. At n=6, threshold=6: correct
  Economy-Tech bonus = `1×6 = 6`; as-written = `(1×6)×6 = 36`. Ships a broken economy if
  both Accept as-is. Also duplicates the threshold constant across two owners
  (`EconomyConfig.economy_tech_tier_threshold` vs ADR-0007's `ECONOMY_TECH_TIER_THRESHOLD`).
- **Resolution:** delete the `* min(n, cfg.economy_tech_tier_threshold)` from ADR-0006
  line 139 — ADR-0007's fully-computed return is the final term. Matches ADR-0007's own
  stated unit test ("returns the tiered/capped value … including the cap case").

### C1 — `AP.current_ap()` is called but never declared · MEDIUM (won't compile)

- **ADR-0006's `AP` public surface is exactly** `income / can_afford / spend / reset_turn /
  discard` — there is **no `AP.current_ap`**. Current AP is read via `GameState.current_ap(player)`
  (ADR-0001, line 144), backed by `PlayerState.current_ap`.
- **ADR-0015** (line 100), **ADR-0016** (line 92), and **ADR-0011** (line 258) all call
  `AP.current_ap(state, player)`. ADR-0011 is internally inconsistent — line 253 also lists
  `GameState.current_ap(player)`.
- **Resolution (pick one):** (a) add a thin `static func current_ap(state, player) -> int`
  pass-through to ADR-0006's `AP` class (makes all three callers correct as written), or
  (b) retarget all callers to `state.current_ap(player)`.

### C2 — `AP.ap_income_breakdown()` is consumer-declared only · LOW

- **ADR-0016** forward-declares `AP.ap_income_breakdown(state, player) -> {base, outpost,
  econ_tech}` as "owed to ADR-0006" (TR-hud-019), but **ADR-0006's text never carries it**.
- Note: `architecture.md` line 123 already lists `ap_income_breakdown(p)` as an AP read
  interface — so this is ADR-0006 lagging the master architecture doc, not a design gap.
- **Resolution:** back-declare `AP.ap_income_breakdown(state, player) -> Dictionary` on
  ADR-0006 (implement as a labeled variant of the existing four-term `income()`).

> **Related (not a conflict):** `CommandInterface.selection_changed` is consumer-declared by
> ADR-0016 and owned by ADR-0015 but not yet declared in ADR-0015's text. ADR-0016
> self-documents this and requests the back-reference; ADR-0004 scoped the signal to the
> read-facade side. Fold the declaration into ADR-0015 at Accept. Same family as C2, milder.

---

## ADR Dependency Order — ✅ acyclic, well-ordered

No cycles. **No ADR depends on a higher-numbered ADR.** Forward-declarations (e.g. ADR-0006
→ `completed_outpost_count`/`economy_tech_income_bonus` implemented by ADR-0007; ADR-0014's
`INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant closed by ADR-0016) are declaration-only and
create no back-edges.

**Recommended implementation order (topological):**

```
Layer 0 (root):   0001
Layer 1:          0003, 0002
Layer 2:          0005, 0004, 0006
Layer 3:          0007, 0013
Layer 4:          0008, 0009, 0010, 0014
Layer 5:          0011
Layer 6:          0012, 0015
Layer 7:          0016
Planned (Core):   0017 (B&P mechanics), 0018 (Research mechanics) — slot after 0008/0010
```

Valid linear order: `0001 → 0003 → 0002 → 0005 → 0004 → 0006 → 0007 → 0013 → 0008 → 0009 →
0010 → 0014 → 0011 → 0012 → 0015 → 0016`.

Three ADRs carry perf/engine **Accept-gates** (QQ-05 → 0009, QQ-06 → 0011, iso + dual-focus
spikes → 0013/0014). These constrain *Accept* order, not *dependency* order.

---

## Engine Compatibility — ✅ clean

Engine: Redot 26.2 (Godot 4.6-compatible). Engine Compatibility sections present: **16 / 16**.

- **Deprecated API references:** NONE. ADR-0013 correctly **bans** `local_to_map()` /
  `map_to_local()` for isometric picking, citing the verified GH#89423 accuracy bug, and
  uses a hand-rolled exact-inverse 2:1 dimetric transform instead.
- **Stale version references:** NONE. All 16 cite Redot 26.2 / Godot 4.6 consistently.
- **Post-cutoff API conflicts:** NONE. `duplicate_deep()` semantics (path-less Resources
  deep-copied; `preload()`'d path-having Resources shared by reference) are asserted
  identically across ADR-0001/0004/0005/0007/0012 — a well-managed shared fact, not
  independently re-guessed. `TileMapLayer`, `y_sort_enabled`, `TILE_SHAPE_ISOMETRIC`,
  `queue_redraw()` coalescing, `create_timer().timeout`, `AudioStreamPlayer` single-stream
  ducking, and `assert()`-stripped-in-release (→ `push_error`+clamp) all confirmed correct
  for 4.6.

### Engine Specialist Findings (godot-specialist second opinion)

- **One open residual (MEDIUM, already gated):** ADR-0014's Godot 4.6 **dual mouse/keyboard
  focus split × `focus_neighbor_*` consumption** for the two asymmetric states
  (keyboard-only focus; mouse-hover-only focus) is undocumented in the reference corpus.
  It is correctly scoped as ADR-0014's pre-Accept spike. It is the single most load-bearing
  spike in the set — ADR-0015 and ADR-0016 both structurally depend on that input-arbitration
  claim holding. **Not a new blocker**, but must not be skipped.
- All other engine-heavy claims (0001/0007 clone sharing, 0013 iso transform + z_index/y_sort
  banding, 0015 `extends Node` coordinator + `_process` hold-timer, 0016 facade / audio
  ducking / release-surviving guard) were **CONFIRMED**.

---

## GDD Revision Flags (Architecture → Design Feedback)

**None** — no HIGH-risk engine finding contradicts a GDD assumption. All engine risk lives in
gated pre-Accept spikes, not in verified-reality-vs-GDD conflicts. Systems index unchanged.

---

## Architecture Document Coverage

`docs/architecture/architecture.md` (v1.0) maps all 12 systems into the 5-layer model with
the two new modules (Board Renderer, Event bus). No orphaned architecture. It carries the
**same B&P/Research caveat**: both appear as Core "gameplay verb" modules whose mechanics
are routed through 0002/0007/0008 + forward-declared queries rather than a dedicated ADR —
which ADR-0017/0018 will close. (It also already lists `ap_income_breakdown(p)`, confirming
C2 is ADR-0006 lag, not a design gap.)

---

## Blocking Issues (must resolve before PASS)

1. ~~**C3** — remove the double `min(n, threshold)` from ADR-0006 `income()`.~~ ✅ Fixed 2026-07-24.
2. ~~**C1** — reconcile `AP.current_ap` vs `GameState.current_ap`.~~ ✅ Fixed 2026-07-24 (`AP.current_ap` added).
3. ~~**C2** — back-declare `AP.ap_income_breakdown` on ADR-0006.~~ ✅ Fixed 2026-07-24.
4. **Coverage gap (OPEN)** — author ADR-0017 (B&P mechanics) and ADR-0018 (Research mechanics).

**Remaining before PASS:** item 4 only (plus the two pre-gate UX docs). With C1/C2/C3 resolved,
the sole architectural blocker is the two unwritten Core-layer ADRs.

## Required ADRs (most foundational first)

1. **ADR-0017 — Base & Production Mechanics** (build FSM, `legal_build_tiles`,
   `produce`/`legal_deploy_tiles`). Governs 4 Core-layer TRs.
2. **ADR-0018 — Research/Tech Mechanics** (per-Lab research state + mutual exclusion,
   `legal_research_targets`, tech-unlock effects). Governs 3 Core-layer TRs.

(Both are additive to the existing set; they harvest already-forward-declared signatures, so
no cross-ADR renegotiation is required — only specification of the algorithms.)

---

## Next Steps

1. Fix C1/C2/C3 in ADR-0006 / ADR-0007 (one-line each) while they are still `Proposed`.
2. Author ADR-0017 and ADR-0018 (`/architecture-decision` in fresh sessions).
3. Run the perf spikes (QQ-05, QQ-06) and the ADR-0013/0014 engine spikes before Accept.
4. Complete the pre-gate UX docs (see checklist), then re-run `/architecture-review` and
   proceed to `/gate-check pre-production`.

## Pre-Gate Checklist

| Artifact | Status |
|----------|--------|
| `tests/unit/` | ✅ |
| `tests/integration/` | ✅ |
| `.github/workflows/tests.yml` | ✅ |
| `design/ux/interaction-patterns.md` | ❌ → run `/ux-design` |
| `design/accessibility-requirements.md` | ❌ → run `/ux-design` |

Two UX artifacts remain before `/gate-check` is available.
