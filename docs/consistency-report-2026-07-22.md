# Consistency Check Report

**Date:** 2026-07-22
**Registry loaded:** 9 entities, 0 items, 5 formulas, 19 constants
**Scope:** full

**GDDs scanned (8):** ap-economy.md, base-production.md, combat-resolution.md,
game-state-turn-manager.md, grid-terrain.md, movement-system.md, research-tech.md,
unit-system.md
*(excluded: game-concept.md, systems-index.md — not system GDDs)*

**Context:** Run 4 for this corpus. Triggered by two same-day re-reviews: AP Economy
(`/design-review` — the Economy Tech income term was found to defeat its own
diminishing-returns brake, refit with a new `ECONOMY_TECH_TIER_THRESHOLD` (6) cap,
ceiling 38→32) and Base & Production (`/design-review` — confirmed the
`economy_outpost_discount` hook removal was clean, added one regression-guard AC).

---

## Conflicts Found (must resolve before architecture)

🔴 **`research-tech.md:555–556`** (an Acceptance Criterion, "Templates" block)
Registry / source (`ap-economy.md` + `research-tech.md`'s own Formulas section) say
Economy Tech grants `+1 AP/turn income per completed Economy Outpost` (capped at 6).
Conflict: this AC still asserted the *original, pre-2026-07-21* mechanic —
`"−1 Economy Outpost cost"` — a stale build-cost-discount description that survived
two retunes (discount → uncapped income bonus → capped income bonus) without being
updated. Predates this session.
→ **Fixed**: AC now reads "+1 AP/turn income per completed Economy Outpost, capped at
`ECONOMY_TECH_TIER_THRESHOLD` (6) outposts."

🔴 **`systems-index.md:91`** (Research / Tech design-order summary row)
Same stale `"−1 Economy Outpost cost"` framing in the narrative dependency list.
Predates this session.
→ **Fixed**: now reads "+1 AP/turn income per completed Economy Outpost, capped at 6
outposts."

---

## Stale Registry Entries (registry behind the GDD)

None — `entities.yaml` was already current from this session's earlier reconciliation
work (new `ECONOMY_TECH_TIER_THRESHOLD` constant registered; `ap_income` formula,
output_range, and notes updated; `ECONOMY_TECH_INCOME_BONUS` notes updated;
`last_updated` bumped to 2026-07-22; YAML re-validated).

---

## Stale GDD Narrative (GDD prose behind the registry/reality — fixed this run)

⚠️ **`research-tech.md`** — three spots (Core Rule 8, the Interactions table, the Tech
templates table) correctly described the term's *mechanism* (per-outpost income bonus)
but predated today's cap, so they read as unbounded. Not factually wrong at time of
writing, but incomplete after the `ECONOMY_TECH_TIER_THRESHOLD` fix.
→ **Fixed**: all three now cite the cap.

---

## Unverifiable References (no conflict, informational)

ℹ️ `base-production.md` and `research-tech.md` both mention `~26` as the un-teched
practical income ceiling — consistent with `ap-economy.md`'s Formulas section, not
independently re-derived this pass (flagged as a nice-to-have in the Base & Production
re-review, not a conflict).

---

## Clean Entries (no issues found)

✅ 31 of 33 registry entries verified across all 8 GDDs with no conflicts, including
every constant/formula touched this session: `ap_income`, `ECONOMY_TECH_INCOME_BONUS`,
`ECONOMY_TECH_TIER_THRESHOLD`, `economy_outpost` (build_cost flat 4, no discount path),
and `ECONOMY_TECH_DISCOUNT` (deprecated, zero live references in any GDD — grep-confirmed).
All previously-verified values (unit stat table, structure stat table, `attack_cost`,
`COVER_DR`, `MIN_DAMAGE`, `BASE_INCOME`, `SOFT_MOVE_PENALTY`, grid dimensions,
`DEFENSIVE_ATTACK_COST`, `CANCEL_REFUND_RATE`, `effective_defense`, `research_lab`,
`DEFENSE_TECH_BONUS`) remain consistent.

---

**Verdict: CONFLICTS FOUND → RESOLVED** (2 stale narrative conflicts, both predating
this session, fixed in-file; 3 incompleteness notes also fixed; registry required no
changes beyond this session's earlier sync)
