# Consistency Check Report

**Date:** 2026-07-22
**Trigger:** Post-authoring of `design/gdd/command-action-interface.md` (System #9, UI/Presentation)
**Registry entries checked:** 9 entities, 0 items, 5 formulas, 20 constants
**Scope:** Focused — the newly-authored 9th GDD against the registry + existing 8 GDDs
(the prior full run, Run 4 / `consistency-report-2026-07-22.md`, verified GDDs 1–8 clean).
**GDDs scanned:** command-action-interface.md (new) vs. registry-of-record (which encodes the other 8).

---

## Method note

The Command & Action Interface GDD is governed by a **Pass-Through Invariant**: it holds
**zero balance constants** and only *displays* values returned by owning-system queries.
This makes value-conflict risk structurally low — the GDD cannot desync from a balance
constant it never copies. The only conflict surface is **illustrative numbers in worked
examples**, which were each verified against the registry.

---

## Conflicts Found

**None.** 🔴 0 conflicts.

## Stale Registry Entries

**None.** ⚠️ 0 stale entries. (Five `referenced_by` links were appended during authoring —
`ap_income`, `damage_formula`, `attack_cost`, `DEFENSIVE_ATTACK_COST`, `CANCEL_REFUND_RATE` —
pure cross-reference hygiene, no value changes.)

## Verified Values (worked-example numbers vs. registry)

| Value | GDD | Registry | Result |
|---|---|---|---|
| `attack_cost` | 2 (all units) | 2 | ✅ |
| `DEFENSIVE_ATTACK_COST` | 1 (Defensive Structure) | 1 | ✅ |
| `attack_cost` range | 1–2 | 2 / 1 split | ✅ |
| `ap_income` output range | 10–~32 | [10, 32] | ✅ |
| Trooper move example | 3-tile in-cap = 6 AP | move_cost 2 × 3 | ✅ |
| Scout move example | 3-cost tile | move_cost 1, illustrative | ✅ |
| Sniper attack example | attack_cost 2 | flat 2 all units | ✅ |
| `CANCEL_REFUND_RATE` | `floor(build_cost × RATE)` (no value hardcoded) | 0.5 | ✅ |
| Structure/produce costs | kept generic — none hardcoded | — | ✅ no surface |

## Ownership / formula-attribution check

- `damage_formula` → Combat ✅ · `ap_income` → AP Economy ✅ · `move_path_cost` → Movement ✅ · cancel refund → Base & Production ✅
- No registered formula's variables or output ranges are redefined by this GDD — it consumes outputs only. ✅
- No new cross-system entities/constants introduced → no reciprocal updates owed to other GDDs. ✅

---

## Verdict: **PASS**

The Command & Action Interface GDD is consistent with the entity registry and the existing
8 GDDs. No conflicts, no stale entries. Its Pass-Through Invariant makes it inherently
resilient to future balance-value changes. Cleared for `/design-review` (fresh session) and
subsequent `/review-all-gdds` / `/create-architecture`.
