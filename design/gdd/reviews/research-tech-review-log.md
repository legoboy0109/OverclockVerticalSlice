# Research / Tech — Review Log

Revision history for `design/gdd/research-tech.md`. Newest entries first.

---

## Review — 2026-07-21 — Verdict: NEEDS REVISION → fixed in-file → user accepted to APPROVED
Scope signal: M (single system, 3 simple effect formulas, 4 dependencies all already Approved/Designed, no new ADR — the Lab reuses Base & Production's structure state machine)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 4 | Recommended: 5 (all folded in) | Nice-to-have: 3

Summary: High-consensus review — four specialists independently converged on the Defense-Tech floor-lock and the closeout/snowball concern, which the creative-director flagged as the strongest signal in the packet. Verdict NEEDS REVISION with the core architecture (risk model, permanence rules, turn-ordering, formulas) affirmed sound; the defects were a documentation-accuracy issue and two things the GDD had mis-scoped as "playtest-gated" (a structural matchup property and its own snowball). All 4 blocking items were resolved in-file and the user accepted to Approved.

Blocking items resolved:
1. **Stale handoff documentation (qa-lead, verified).** The header claimed "2 unlanded handoffs / 5 Integration ACs BLOCKED" (only 4 tagged), but both handoffs had already landed — `unit-system.md` (Approved; `effective_defense` + two-flag split) and `base-production.md` (Approved; Research Lab 5th-structure entry). Header rewritten, 4 `[BLOCKED]` tags removed → landed cross-refs, AC preamble corrected, 5-vs-4 count fixed.
2. **Defense-Tech + Cover floor-lock (game-designer Pillar-3 + systems-designer structural).** The GDD's compounding sanity check only tested the asymmetric case; systems-designer proved the floor-lock persists into the researched **mirror match** — a researched Scout (atk 3) vs a researched Cover defender (def 1 + COVER_DR 1) = `max(1, 3−2) = 1`, making the Scout a permanent 1-damage matchup no attacker tech escapes (half the base roster, Scout + Trooper, affected). Decision: hold `DEFENSE_TECH_BONUS = 1`, correct the sanity check to show the mirror case, and elevate to a named Open Question with a **pre-committed non-stacking fallback lever** (`mitigation = max(defense, cover_reduction)`, a reserved `combat-resolution.md` change). Advisory AC now tests the mirror case too.
3. **Research as unbraked closeout accelerant / snowball (economy-designer ×2 + game-designer's "Lab-spam has no brake").** A winning player banks permanent, un-raidable +1/+1 (and, with Economy Tech, +income) on top of a board lead; the GDD claimed the opposite ("not a no-brainer"). Decision: **state-and-accept** — Player Fantasy reframed with an honest snowball note (Research = reward for winning the tempo duel, no Lab-count brake in the VS), added a closeout re-run advisory AC (Base & Production's CF-1 with the winner holding Attack Tech), and +2 Open-Question rows (snowball, simultaneous-Lab cap).
4. **Economy Tech AP-dominated (economy-designer).** Its bounded ~2–4 AP lifetime payoff (vs 7 AP cost) was not a peer to Attack/Defense's unbounded, army-scaling value. Decision: **retune to scale** — `ECONOMY_TECH_DISCOUNT` (a one-time −1 Economy-Outpost build-cost rebate) replaced by **`ECONOMY_TECH_INCOME_BONUS`** = +1 AP/turn per completed Economy Outpost. Now boom-scaling and a genuine peer.

Recommended (folded in): symbolic `effective_defense` AC (read-from-config, not literal 1); two negative-space ACs (cancel-vs-destroy same-step precedence = destruction wins; same-tech double-completion structurally unreachable); a tempo-cost honesty note (Lab + tech = 15–18 AP / ~5–6 turns exposure — rarely a correct first pick); a "which tech is the decision" note (Attack/Defense are symmetric timing sticks; Economy Tech is the differentiator).

Cross-doc reconciliation (applied in-file; both flagged RE-REVIEW OWED because their surface changed):
- `ap-economy.md` (Approved) — `ap_income` gained the Economy Tech term `+ (has_economy_tech ? ECONOMY_TECH_INCOME_BONUS × n : 0)`; practical ceiling ~26 → ~38; formula/variable-table/worked-examples/interaction-row/status-header updated. Balance-center formula changed → re-review owed.
- `base-production.md` (Approved) — Core Rule 2 Economy Outpost `economy_outpost_discount` hook removed (flat 4, no discount); header note updated. No number change → re-review owed only to confirm the removal.
- `entities.yaml` — `ECONOMY_TECH_DISCOUNT` deprecated (no-delete rule); `ECONOMY_TECH_INCOME_BONUS` added; `ap_income` expression/output_range[10,38]/notes/referenced_by synced; `economy_outpost` de-discounted; `DEFENSE_TECH_BONUS` note += mirror-case + fallback. YAML validated.

Prior verdict resolved: First review (Research/Tech had not been independently reviewed before this session).

Spike-gated / deferred (NOT resolved here — validate in the vertical-slice economy/combat spike): the raised income ceiling (~38) and Research snowball; the Defense-Tech Cover floor-lock magnitude + the non-stacking fallback trigger; the closeout re-run outcome; simultaneous-Lab cap; faction-differentiated techs; hidden-vs-visible tech; structure-attack research buffing.
