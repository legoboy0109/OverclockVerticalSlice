# Architecture Review — AP → AP & Credits Economy Pivot (Phase 2)

- **Date:** 2026-08-05
- **Mode:** focused (pivot-delta consistency + traceability; not a full 200-TR rebuild — review-mode `lean`)
- **Engine:** Redot 26.2 (Godot 4.6-compatible)
- **Scope:** the 13 ADRs and 10 GDDs touched by the two-budget economy pivot, plus the 4 "Still-Valid" ADRs verified negative.
- **Driving change:** `design/gdd/ap-economy.md` → "AP & Credits Economy" (single AP pool → AP tactical + Credits economic); anchor ADR-0006 revised in place.
- **Companion:** `change-impact-2026-08-05-ap-credits-economy.md` (the propagation audit trail).

---

## Verdict: **PASS**

The 13 revised ADRs are mutually consistent post-pivot; the engine surface is unchanged; and the TR
registry — the one artifact that was lagging — was brought current **within this review** (28
requirement texts revised, 5 new TR-IDs added). No blocking or concern-level conflicts remain.

> The verdict was **CONCERNS** at the start of Phase 7 (stale TR registry). Applying the registry
> update (user-approved) cleared it to **PASS**.

---

## What was reviewed

| ADR | Role in pivot | Result |
|-----|---------------|--------|
| 0006 | **Anchor** — rewritten "AP & Credits Economy" (two mirrored `AP`/`Credits` classes, dual-cost contract, `EconomyConfig` 5→10) | consistent |
| 0001 | `PlayerState.current_credits` + accessor; `income_this_turn` retired | consistent |
| 0002 | Dual-cost both-or-neither atomicity; `CANT_AFFORD_CREDITS` | consistent |
| 0007 | `TechDef.ap_surcharge`; cost fields Credit-denominated | consistent |
| 0008 | Start-of-turn 4a `AP.reset_turn` + 4b `Credits.add_income`; no AP discard | consistent |
| 0011 | `CREDIT_TO_AP_RATE`; 16 knobs; AP-equivalent scoring; lethal-floor re-validated | consistent |
| 0012 | `effective_credit_income` fold; Neutral-inert | consistent |
| 0015 | `projected_remaining_credits`; dual-cost preview | consistent |
| 0016 | Dual AP+Credits counter; live `credit_income_breakdown` | consistent |
| 0017 | Dual-cost build/produce; Credit cancel refund | consistent |
| 0018 | Dual-cost research + per-tech `ap_surcharge`; Credit refund | consistent |
| 0003, 0009 | Name/label refs updated (still-valid decisions) | consistent |

**Still-Valid, verified negative (pivot genuinely does not affect them):** 0003 (determinism —
`CREDIT_TO_AP_RATE` is an AI-scoring float permitted by Rule 4; Credits are integer state), 0010
(combat — attack is AP-only, `AP.spend` unchanged), 0013 (iso render — orthogonal), 0014 (input/focus —
orthogonal; the `input_lock_ms ≥ ap_tick_duration_ms` invariant is HUD-timing, not pool count).

---

## Cross-ADR Conflict Detection (adversarial pass)

An adversarial reviewer read all 15 ADRs and actively tried to break 10 specific contract chains.
**Result: 0 BLOCKING, 0 CONCERN.** Every load-bearing contract holds:

| Contract chain | ADRs | Verdict |
|----------------|------|---------|
| Dual-cost validate-both/spend-both (no rollback object) | 0002 ↔ 0006 ↔ 0017 ↔ 0018 | agree |
| `CANT_AFFORD_CREDITS` (Credits-short) vs `CANT_AFFORD` (AP-short) mapping | 0002 ↔ 0015 ↔ 0017 ↔ 0018 | agree |
| `TechDef.ap_surcharge` default(=`research_ap_cost`)/per-tech-override handshake | 0007 ↔ 0018 | agree |
| Start-of-turn 4a/4b ordering (4b after build-timer advance) | 0008 ↔ 0006 | agree |
| `current_credits` 3-writer ownership (add_income / spend / credit) | 0001 ↔ 0006 | agree |
| AP surcharges owned by `EconomyConfig` (NOT per-type on Unit/Structure defs) | 0006 ↔ 0007 ↔ 0017 ↔ 0018 | agree |
| `income_this_turn` retirement — **no live dependents** (highest-risk check) | 0001 ↔ 0008 ↔ 0016 | clean |
| `AIConfig` knob count 15→16 (self-consistent w/ stated convention) | 0011 | consistent |

**5 cosmetic stale-name NITs** were found (deleted-symbol names — `AP.income`, `/income`, "discard" —
left in prose labels, a diagram legend, and Related-Decisions lists, each contradicted by its own ADR's
operative code) and **all 5 were scrubbed** (ADR-0011 ×2, ADR-0015 ×1, ADR-0008 ×2, ADR-0003 ×4 labels).

---

## Traceability (TR registry)

The pivot made the registry's requirement *texts* stale (the architecture covered the new mechanics;
the registry bookkeeping lagged). Updated in-review (registry `version: 4`):

**Revised in place (28 texts, ID unchanged, `revised: 2026-08-05`):**
`apecon` 001–009/011/012/013 (`ap_income`→`credit_income`; discard→carryover; `income_this_turn`
retired; `can_afford`/`spend`→`ap_`/`credits_`; "no parallel pool"→dual bounded budgets) ·
`baseprod` 004/006/007/008/013 (dual-cost build/produce; Credit refund; `credit_income`) ·
`research` 002/006/007/010 (dual-cost research; Credit-denominated; `credit_income`) ·
`hud` 019 (`Credits.credit_income_breakdown`, live) · `ai` 005/006/007/008/011
(dual afford gate, `ap_equiv_cost`, 16 knobs, lethal-floor × rate, tie-break) · `faction` 004
(`effective_credit_income`).

**New TR-IDs (5):**
- `TR-apecon-015` — dual-cost both-or-neither contract (ADR-0006/0002)
- `TR-apecon-016` — AP carryover cap + Credits banking (ADR-0006)
- `TR-apecon-017` — AP logistics surcharges, EconomyConfig-owned (ADR-0006)
- `TR-ai-018` — `CREDIT_TO_AP_RATE` two-currency conversion (ADR-0011)
- `TR-research-014` — `TechDef.ap_surcharge` per-tech override (ADR-0007)

All post-pivot economy requirements now have a covering ADR. No coverage gaps introduced by the pivot.

---

## Engine Compatibility

**Clean.** The pivot introduces no new engine API surface: two `int` fields (`current_credits`, and the
`EconomyConfig` additions) and one mirror static class (`Credits`) on shapes already engine-verified by
ADR-0001/0005 (Resource + `@export`, static utility). No deprecated APIs; no version drift; the
`CREDIT_TO_AP_RATE` float lives in AI scoring, never in state (ADR-0003 Rule 4). No GDD revision flags.

---

## Follow-ups (non-blocking)

- `/design-review design/gdd/ap-economy.md` remains nominally owed (the GDD flags it), but the GDD was
  cross-verified during propagation and the architecture gate passed clean — low marginal value.
- The pivot's 5 new tuning knobs (`FLAT_AP_PER_TURN`, `AP_CARRYOVER_CAP`, the three `*_AP_COST`
  surcharges) and `CREDIT_TO_AP_RATE` are the most playtest-sensitive numbers — validate against the
  S4-05 tempo playtest (the pivot's empirical gate).
- Credit banking → leader-snowball watch-item (GDD OQ): income rate is capped (~26/32) but stock is
  unbounded; the AP surcharge is the brake — confirm in playtest.
