# Consistency Check Report

**Date:** 2026-07-22
**Trigger:** Post `/design-review` re-review and Approval of `design/gdd/command-action-interface.md` (System #9) — verifying today's CR-10 rewrite, new `GAME_OVER` terminal state, CR-6a gesture constraint, and the two reciprocal contracts opened earlier today (Movement's `is_surcharged`, Combat's `legal_targets(unit, from_tile)`) didn't desync anything.
**Registry entries checked:** 9 entities, 0 items, 5 formulas, 20 constants (34 total)
**Scope:** Full — all 10 in-scope GDDs
**GDDs scanned:** ap-economy.md, base-production.md, combat-resolution.md, command-action-interface.md, game-hud.md, game-state-turn-manager.md, grid-terrain.md, movement-system.md, research-tech.md, unit-system.md

---

### 🔴 Conflicts Found

**None.** Zero numeric or categorical conflicts detected across all 34 registry entries and all 10 GDDs.

---

### ⚠️ Stale Registry Entries

**None.** No registry entry lags behind its source GDD's current body text.

One minor **stale internal documentation note** (not a registry issue, not a value conflict):
- `command-action-interface.md` still labels `is_surcharged` (Dependencies/Formulas tables) as "pending Movement contract addition (OQ-2)" / "owed reciprocally," even though `movement-system.md` and `combat-resolution.md` already landed `is_surcharged` and `legal_targets(unit, from_tile)` with matching semantics earlier today. The values/contracts themselves are fully consistent — only the "pending" wording is stale.

---

### Today's Reciprocal Contract & Revision Changes — Verification Summary

| Check | Result |
|---|---|
| `is_surcharged` (Movement `reachable()` → Combat/CAI consumers) | ✅ CLEAN — same field, same type/meaning everywhere. Only the stale "pending" wording noted above. |
| `legal_targets(unit, from_tile)` hypothetical-tile overload | ✅ CLEAN — combat-resolution.md and command-action-interface.md agree on signature, purity, and semantics. |
| `INPUT_LOCK_MS` / `AP_TICK_DURATION_MS` | ✅ CLEAN — both = 120ms in command-action-interface.md and game-hud.md; the `INPUT_LOCK_MS ≥ AP_TICK_DURATION_MS` invariant (120≥120) stated identically in both, including matching "80→120ms" retune history. |
| `GAME_OVER` / `GameOver(winner)` / `win_condition` | ✅ CLEAN — game-state-turn-manager.md (source), command-action-interface.md's new `GAME_OVER` terminal state, and game-hud.md's CR-9 all agree: trigger = HQ hp reaches 0; effect = terminal, input frozen immediately after the triggering commit resolves. No contradiction on timing or trigger. |
| `CANCEL_REFUND_RATE` math check | ✅ CLEAN — floor(build_cost × 0.5): Economy Outpost floor(4×0.5)=2 ✓, Production Outpost floor(9×0.5)=4 ✓, Defensive Structure floor(6×0.5)=3 ✓. command-action-interface.md's CR-6a/AC-17/AC-18 use the identical formula and figures; CR-6a's new gesture constraint doesn't touch the refund math. |
| `ap_income` ceiling (32 vs. historical 38) | ✅ CLEAN — every current-state assertion across all GDDs says ~32 (post `ECONOMY_TECH_TIER_THRESHOLD` cap). "38" appears only in explicitly historical/hypothetical framing ("was ~38 uncapped"), never asserted as current anywhere. |
| Per-doc "CR-10" label collision | ℹ️ Note — game-hud.md has its own locally-numbered "CR-10" (Turn-scoped interactivity), unrelated to command-action-interface.md's "CR-10" (Recompute-fresh query tiers). Same label, different docs, no cross-referencing between them — normal per-doc numbering, not a conflict. |

---

### New Cross-System Facts (Phase 6 registry candidates — not added automatically)

Two facts now appear in 2+ GDDs and are structurally significant:
- **`is_surcharged`** (owned by movement-system.md `reachable()`; consumed by command-action-interface.md)
- **`legal_targets(unit, from_tile)`** (owned by combat-resolution.md; consumed by command-action-interface.md)

---

### Clean Entries Summary

✅ **9/9 entities** clean (scout, trooper, heavy, sniper, hq, economy_outpost, production_outpost, defensive_structure, research_lab)
✅ **5/5 formulas** clean (manhattan_distance, ap_income, effective_attack, effective_defense, damage_formula)
✅ **20/20 constants** clean (grid_terrain_types, grid_adjacency_mode, grid_size_range, win_condition, ap_reset_policy, BASE_INCOME, outpost_income_tiers, SOFT_MOVE_PENALTY, attack_cost, COVER_DR, MIN_DAMAGE, DEFENSIVE_ATTACK_COST, CANCEL_REFUND_RATE, MAX_OUTPOST_COUNT, RESEARCH_ATK_BONUS, DEFENSE_TECH_BONUS, ECONOMY_TECH_DISCOUNT [deprecated, correctly unreferenced], ECONOMY_TECH_INCOME_BONUS, ECONOMY_TECH_TIER_THRESHOLD)

**Total: 34/34 clean, 0 conflicts, 0 stale registry entries.**

---

## Verdict: PASS

The registry and all 10 in-scope GDDs are fully consistent, including today's reciprocal contract changes (Movement's `is_surcharged`, Combat's `legal_targets(from_tile)`) and command-action-interface.md's re-review revisions (CR-10 four-tier rewrite, `GAME_OVER` terminal state, CR-6a gesture constraint). Only action item is optional documentation hygiene in command-action-interface.md (see below).
