# Consistency Check Report

**Date:** 2026-07-21
**Registry loaded:** 8 entities, 0 items, 4 formulas, 14 constants
**Scope:** full

**GDDs scanned (7):** ap-economy.md, base-production.md, combat-resolution.md,
game-state-turn-manager.md, grid-terrain.md, movement-system.md, unit-system.md
*(excluded: game-concept.md, systems-index.md — not system GDDs)*

---

## Conflicts Found (must resolve before architecture)

None.

---

## Stale Registry Entries (registry behind the GDD)

None — the registry itself is current; every numeric value checked (unit stat
table, structure stat table, `attack_cost`, `COVER_DR`, `MIN_DAMAGE`,
`BASE_INCOME`, `SOFT_MOVE_PENALTY`, grid dimensions, `DEFENSIVE_ATTACK_COST`,
`CANCEL_REFUND_RATE`) matches its owning GDD exactly.

---

## Stale GDD Narrative (GDD prose behind the registry/reality — fixed this run)

⚠️ **`ap-economy.md:151`** — illustrative note read *"outpost 5"*.
Registry (source: `base-production.md`): `economy_outpost.build_cost = 4`.
The note was explicitly marked non-authoritative ("if a quoted number ever
disagrees with its owning GDD, the owning GDD wins"), so this wasn't ambiguous
— just stale since Base & Production is now authored.
→ **Fixed**: `5` → `4`.

⚠️ **`ap-economy.md:100–102`** — three Interactions-table rows were still tagged
`*(undesigned)*` for **Base & Production**, **Movement**, **Combat**, and
**Unit** — all four are now authored (Designed/Approved/In Revision). Only
Research/Tech (#8) and Command & Action Interface/Game HUD (#9/#10) are
genuinely still undesigned.
Line 100's `completed_outpost_count` description ("tagged outpost") was also
looser than the contract Base & Production resolved: **Economy Outposts
only** (HQ/Production Outpost/Defensive Structure excluded).
→ **Fixed**: removed the stale `(undesigned)` tags from Base & Production /
Movement / Combat / Unit; tightened the `completed_outpost_count` description
in both the Interactions table and the Dependencies section to match the
resolved contract.

---

## Unverifiable References (no conflict, informational)

ℹ️ `unit-system.md:258` — an Edge Case still says "deploy a produced unit...
adjacent to the HQ," written before Base & Production existed (when the HQ
was the only imaginable producer). Base & Production's Rule 7 generalizes
this to *any* producer (HQ or Production Outpost). Not a registered-value
conflict — just pre-Base-&-Production wording that reads narrower than the
current design. Left open; candidate for `/review-all-gdds` rather than a
registry fix.

---

## Clean Entries (no issues found)

✅ **26 registry entries verified across all 7 GDDs with no conflicts**:
`scout`, `trooper`, `heavy`, `sniper`, `hq`, `economy_outpost`,
`production_outpost`, `defensive_structure` (entities); `manhattan_distance`,
`ap_income`, `effective_attack`, `damage_formula` (formulas);
`grid_terrain_types`, `grid_adjacency_mode`, `grid_size_range`,
`win_condition`, `ap_reset_policy`, `BASE_INCOME`, `outpost_income_tiers`,
`SOFT_MOVE_PENALTY`, `attack_cost`, `COVER_DR`, `MIN_DAMAGE`,
`DEFENSIVE_ATTACK_COST`, `CANCEL_REFUND_RATE`, `MAX_OUTPOST_COUNT`
(constants).

---

## Verdict: PASS

0 conflicts; 2 stale-narrative items found and fixed; 1 low-severity
informational note left open (not blocking).

## Corrections Applied This Run

- `design/gdd/ap-economy.md`: illustrative outpost cost `5` → `4`.
- `design/gdd/ap-economy.md`: removed stale `(undesigned)` tags for Base &
  Production / Movement / Combat / Unit; tightened `completed_outpost_count`
  description (Interactions table + Dependencies section) to "Economy
  Outposts only."

## Recommended Next Steps

- Run `/design-review design/gdd/base-production.md` in a fresh session
  (unreviewed structure numbers + closeout-drag brake + counters-on).
- Run `/review-all-gdds` once remaining Vertical-Slice GDDs are authored —
  good candidate to also resolve the `unit-system.md:258` wording note.
- Continue `/design-system` in priority order: Research / Tech (#8) is next.

---
---

# Consistency Check Report — Run 2 (post-Combat-approval)

**Date:** 2026-07-21
**Registry loaded:** 9 entities, 0 items, 5 formulas, 17 constants
**Scope:** full (triggered after Combat Resolution #6 approved + the structure-cover-immunity change propagated)

**GDDs scanned (8):** ap-economy.md, base-production.md, combat-resolution.md,
game-state-turn-manager.md, grid-terrain.md, movement-system.md, research-tech.md, unit-system.md
*(excluded: game-concept.md, systems-index.md — not system GDDs)*

---

## Entities (9) — ✅ all consistent

- **Units** (scout/trooper/heavy/sniper): stat tables agree across unit-system.md (Core Rule 3),
  combat-resolution.md (shots-to-kill matrix, atk in parens), and base-production.md (vs-structure
  shots-to-kill table). All match the registry: Scout 3/2/1/1/4/2, Trooper 6/3/2/2/3/4,
  Heavy 10/5/2/3/2/7, Sniper 3/6/3/2/3/5.
- **Structures** (hq/economy_outpost/production_outpost/defensive_structure/research_lab): hp/cost/
  time/def/attack all agree between base-production.md (owner), combat-resolution.md, and
  research-tech.md (Research Lab). HQ def 2, Defensive Structure atk 4/rng 2/def 1/counters-on,
  Research Lab 12/8/2 — consistent.
- base-production.md vs-structure shots-to-kill table spot-verified against the damage formula with
  structure defense: Scout(2)→HQ = 40 (2−2=0→floor 1), Heavy(5)→HQ = 14 (ceil(40/3)), Sniper(6)→HQ
  = 10 (ceil(40/4)). Correct.

## Formulas (5) — ✅ all consistent

- `damage_formula`: single expression `max(MIN_DAMAGE, effective_attack − cover_reduction − defense)`
  used identically everywhere. **Structure cover-immunity** (this run's change) now stated
  consistently in combat-resolution.md (Rule 6 + Formulas + Edge Cases), base-production.md
  (Edge Case + audit note + HQ_DEFENSE knob), grid-terrain.md (Cover terrain description), and the
  registry (damage_formula, COVER_DR, grid_terrain_types, HQ notes).
- `effective_attack` / `effective_defense`: expressions and the two independent tech flags
  (owner_has_attack_tech / owner_has_defense_tech) agree between unit-system.md and research-tech.md.
- `manhattan_distance`, `ap_income`: unchanged, consistent.

## Constants (17) — ✅ all consistent

COVER_DR 1, MIN_DAMAGE 1, attack_cost 2, DEFENSIVE_ATTACK_COST 1, BASE_INCOME 10,
RESEARCH_ATK_BONUS 1, DEFENSE_TECH_BONUS 1, ECONOMY_TECH_DISCOUNT 1, SOFT_MOVE_PENALTY 2.0,
ECON_OUTPOST_BUILD_COST 4 (→3 discounted), CANCEL_REFUND_RATE 0.5, MAX_OUTPOST_COUNT 10 (disabled),
and grid/turn constants all agree. `COVER_DR = 2` and `SOFT_MOVE_PENALTY 1.5` occurrences are
tuning-range/illustrative, not conflicting value declarations.

## Verdict: PASS

0 conflicts. 1 low-severity narrative imprecision found and fixed: grid-terrain.md's Cover
description said "reduction to an occupant" — tightened to "to a **unit** occupant … structures are
cover-immune" to match Combat Rule 6 (the cover-immunity change this run introduced). The registry
sync from the Combat design-review (4 entries) was verified consistent across all 8 GDDs.

## Corrections Applied This Run

- `design/gdd/grid-terrain.md`: Cover terrain now scoped to "unit occupant" + notes structure
  cover-immunity (aligns Grid's flag description with Combat's application scope).

*(The combat-resolution.md / base-production.md / entities.yaml cover-immunity edits were applied
during the preceding `/design-review` revision, not by this check — this run verified them consistent.)*

## Recommended Next Steps

- Run `/design-review design/gdd/base-production.md` (fresh session) — #7 still unreviewed
  (structure numbers + closeout-drag brake + counters-on Defensive Structure).
- Run `/design-review design/gdd/research-tech.md` — #8 still unreviewed.
- Unit System #4 re-review pending (effective_defense two-flag split).

---

## Run 3 — 2026-07-21 (post Research/Tech #8 design-review + Economy Tech retune)

**Scope:** focused on the values the Research/Tech design-review changed (the only edits this session), plus a corpus grep for the changed names.
**Registry:** 9 entities, 5 formulas, 18 constants (1 newly deprecated: ECONOMY_TECH_DISCOUNT).
**GDDs scanned:** research-tech, ap-economy, base-production (the docs the retune touched) + registry.

### Verdict: PASS (1 ⚠️ stale cross-reference found and fixed; 0 🔴 conflicts)

**Changed values verified consistent:**
- ✅ `ECONOMY_TECH_INCOME_BONUS` = 1 AP/turn per completed Economy Outpost — agrees across research-tech.md (owner), ap-economy.md (consumer), entities.yaml.
- ✅ `ECONOMY_TECH_DISCOUNT` — deprecated in registry; zero remaining *active* references in any GDD (only historical/removal notes remain, as intended).
- ✅ `ap_income` new term `+ (has_economy_tech ? ECONOMY_TECH_INCOME_BONUS × n : 0)` — identical in ap-economy.md and research-tech.md; registry expression + output_range [10,38] synced.
- ✅ economy_outpost `build_cost` = flat 4, no discount — base-production.md Core Rule 2, ap-economy.md, registry all agree; no stale "4→3" claims.
- ✅ `DEFENSE_TECH_BONUS` = 1 (unchanged) everywhere; research_lab hp12/cost8/time2 (unchanged) agrees research-tech ↔ base-production ↔ registry.

**⚠️ STALE (fixed this run):**
- `base-production.md` MAX_OUTPOST_COUNT tuning-knob note cited "the registry's `ap_income` output range (`[10, 26]`)" — the retune raised it to `[10, 38]`. Updated to cite `[10, 38]` and distinguish the un-teched board-tile ceiling (~26) from the Economy-Tech-boosted ceiling (~38). Sole staleness introduced by the retune.

**Note (not a conflict):** ap-economy.md Open-Question "model showed ~26 ceiling with tiers" is historically accurate for the *base* tiered model (no Economy Tech) — left as-is; the raised ceiling is documented in the formula body + a re-review-owed flag.

**Re-reviews owed (from the retune, tracked — not consistency defects):** AP Economy #3 (income formula changed), Base & Production #7 (discount hook removed).
