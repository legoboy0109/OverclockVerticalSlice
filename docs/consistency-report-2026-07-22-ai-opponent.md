# Consistency Check Report

**Date:** 2026-07-22
**Trigger:** Post-authoring of `design/gdd/ai-opponent.md` (System #11, Gameplay/Feature) — the prior full scan (`consistency-report-2026-07-22-post-review.md`) already verified GDDs 1–10 clean; this run scopes to the new 11th GDD plus the same-session propagation of "AI Opponent" as a downstream dependent into its 7 Hard-dependency GDDs.
**Registry entries checked:** all 9 entities, 5 formulas, 20 constants referenced by ai-opponent.md (unit stats, structure costs, `damage_formula` inputs, `attack_cost`/`DEFENSIVE_ATTACK_COST`, `CANCEL_REFUND_RATE`, `MIN_DAMAGE`, `outpost_income_tiers`, `RESEARCH_ATK_BONUS`/`DEFENSE_TECH_BONUS`/`ECONOMY_TECH_INCOME_BONUS`/`ECONOMY_TECH_TIER_THRESHOLD`, `is_surcharged`, `legal_targets_from_tile`)
**Scope:** Focused — new GDD (#11) vs. registry-of-record, plus the 7 propagation edits
**GDDs touched this session:** ai-opponent.md (new), game-state-turn-manager.md, movement-system.md, combat-resolution.md, base-production.md, research-tech.md, ap-economy.md, grid-terrain.md (all: one added downstream-dependent line each, 2 of the 7 needed the edit — the other 5 already anticipated it)

---

### 🔴 Conflicts Found

**None.**

### ⚠️ Stale Registry Entries

**None.**

### Verification Detail

| Check | Result |
|---|---|
| `produce_cost` (Scout 2 / Trooper 4 / Heavy 7 / Sniper 5) | ✅ matches registry exactly |
| `build_cost` (Economy Outpost 4 / Production Outpost 9 / Defensive Structure 6 / Research Lab 8) | ✅ matches registry exactly, same order as doc's "(4/9/6/8)" |
| Trooper worked example (hp 6, atk 3, produce_cost 4) | ✅ matches registry `trooper` entity |
| `MIN_DAMAGE`=1, `attack_cost`=2, `DEFENSIVE_ATTACK_COST`=1 | ✅ all match |
| `outpost_income_tiers` (+2 tier-1, +1 tier-2) | ✅ matches doc's `OUTPOST_BONUS_TIER1`/`TIER2` usage |
| Research: Attack/Defense `research_cost`=10, Economy=7; `research_time` Attack 3 / Defense 4 / Economy 3 | ✅ all match |
| `CANCEL_REFUND_RATE` usage (symbolic, ×build_cost) | ✅ consistent, no numeric restatement to conflict |
| `is_surcharged` / `legal_targets_from_tile` (registered this session) | ✅ ai-opponent.md's usage matches their registered signatures exactly |
| 7-file downstream-dependent propagation | ✅ confirmed present in all 7 files via direct grep; no duplication |
| Cross-doc consistency bonus find | ℹ️ movement-system.md's OQ table already independently flags "`reachable()` perf budget owed to the AI Opponent GDD" — matches ai-opponent.md's own OQ-1 verbatim in spirit. Mutual acknowledgment, not a conflict. |

---

## Verdict: PASS

Zero conflicts, zero stale registry entries. AI Opponent (#11) is fully consistent with the registry and all 10 prior GDDs.
