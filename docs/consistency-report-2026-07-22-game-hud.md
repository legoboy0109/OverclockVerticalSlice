# Consistency Check Report

**Date:** 2026-07-22
**Trigger:** Post-authoring of `design/gdd/game-hud.md` (System #10, UI/Presentation)
**Registry entries checked:** 9 entities, 0 items, 5 formulas, 20 constants
**Scope:** Focused — the newly-authored 10th GDD against the registry + existing 9 GDDs
(prior focused run verified #9; the full Run 4 earlier verified GDDs 1–8).
**GDDs scanned:** game-hud.md (new) vs. registry-of-record.

---

## Method note

Like the Command & Action Interface, the Game HUD is governed by a **Pass-Through Invariant**:
it holds **zero balance constants** and only *displays* values read from owning systems. Conflict
risk is structurally low — the only surface is illustrative numbers used to justify UI decisions
(e.g. the `PIP_MAX_HP` threshold), which were each verified.

---

## Conflicts Found

**None.** 🔴 0 conflicts.

## Stale Registry Entries

**None.** ⚠️ 0 stale. (Six `referenced_by` links appended during authoring —
`ap_income`, `BASE_INCOME`, `win_condition`, `hq`, `production_outpost`, `ap_reset_policy` —
cross-reference hygiene, no value changes.)

## Verified Values (numbers cited in game-hud.md vs. registry)

| Value | GDD | Registry | Result |
|---|---|---|---|
| `BASE_INCOME` | 10 (income breakdown line) | 10 | ✅ |
| `ap_income` | decomposition base 10 + tiered outpost + Economy-Tech; range 10–~32 | [10, 32] | ✅ |
| `win_condition` | victory/defeat presentation (opponent HQ destroyed) | opponent HQ destroyed | ✅ |
| `MAX_ROUNDS` | "off in VS", tiebreak deferred (AC-22) | off in VS | ✅ |
| HQ hp | 40 (PIP_MAX_HP threshold example) | hq hp 40 | ✅ |
| Production Outpost hp | 14 (PIP_MAX_HP upper-bound reference) | production_outpost hp 14 | ✅ |

## New shared facts introduced

**None.** The HUD's tuning knobs (`PIP_MAX_HP`, `ACTION_LOG_LENGTH`, `AP_FILL_FLOURISH_MS`,
`AP_TICK_DURATION_MS`, `TURN_BANNER_DURATION_MS`, `SHOW_OPPONENT_AP`, `SHOW_OPPONENT_FILL_FLOURISH`,
`INCOME_BREAKDOWN_DEFAULT`) are UI-local UX-feel values — not cross-system facts — so no registry
entries are owed and no other GDD is affected.

## Ownership / attribution check

- `ap_income` → AP Economy ✅ · `win_condition` → Game State ✅ · HUD redefines no formula, owns none. ✅
- Reciprocity clean: all 7 read-dependencies (Game State, AP Economy, Grid, Unit, Combat, Base & Production, Research) already list Game HUD downstream. ✅

---

## Verdict: **PASS**

The Game HUD GDD is consistent with the entity registry and the existing 9 GDDs. No conflicts,
no stale entries, no new shared facts. Its Pass-Through Invariant makes it inherently resilient to
balance-value changes. Cleared for `/design-review` (fresh session) and subsequent
`/review-all-gdds` / `/create-architecture`.
