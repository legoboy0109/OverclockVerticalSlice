# Review Log — AI Opponent (`design/gdd/ai-opponent.md`)

Revision history for `/design-review` and `/review-all-gdds` passes on this GDD.
Most recent entry first.

---

## Review — 2026-07-22 — Verdict: NEEDS REVISION → revised in-file → ACCEPTED to Approved (confirmation re-review)
Scope signal: M (localized cleanup, no new ADRs, numeric core verified sound)
Specialists: ai-programmer, game-designer, systems-designer, economy-designer, qa-lead, performance-analyst, creative-director (senior synthesis)
Blocking items: 3 | Recommended: ~12 | Prior verdict resolved: Yes — the prior pass's 5 blocking clusters were independently re-derived and CONFIRMED held (every worked example recomputes exactly: combat 2.0/4.0/1.5, production 4.4, economy 7.06/3.53, research Attack 2.3644 / Defense 1.8424 / Economy 4.029; zero constant drift vs. ap-economy.md/research-tech.md/registry; no division-by-zero on any verb).

Summary: The confirmation re-review succeeded at its primary job — the interlocking numeric surgery did not break the settled fixes. But it surfaced 3 new blockers, all traceable to the two mechanisms this session added (`SETUP_ADVANCE_BONUS` and the un-capping of `economy_value`), and one reopened the creative-director's own prior "passivity must be fixed" condition. CD ruling: "the numeric core is sound; fix the 3 and this is APPROVED — the last mile, not another major pass."

Blocking fixes (all applied in-file, user decisions where noted):
- **B1 [systems-designer] — LETHAL_FLOOR_BONUS invariant silently voids CR-7 inside documented safe ranges.** Un-capping `economy_value` made its ceiling scale with `ECONOMY_HORIZON`/`ECONOMY_DECAY`; at `ECONOMY_DECAY`=0.95 a first-outpost `action_score` = 2.517 > 2.5 (floor min), and both knobs at safe-max → 3.812 > 3.5 (floor default), so a non-lethal build outscores a finishing blow. Fix (user: cross-ref + ceiling formula): added `economy_ceiling_score = OUTPOST_BONUS_TIER1 × Σ ECONOMY_DECAY^t / build_cost` + the explicit invariant to both `LETHAL_FLOOR_BONUS` rows, ⚠-flagged the two economy-knob rows, and rewrote Knob Interactions to couple the trio.
- **B2 [ai-programmer] — AC-20 contradicted Edge-Case Term 1 ("nearest forward entity" vs "nearest enemy"); "forward" undefined.** Fix (user: simplify to nearest enemy): Term 1 now uses nearest live enemy entity, matching AC-20; tradeoff + historical note documented.
- **B3 [game-designer; reopened CD's prior passivity ruling] — only move_cost-1 units (Scout) cleared PASS_THRESHOLD for a standing-start advance** (Trooper/Sniper 0.08, Heavy 0.053 — 3/4 of the roster froze at spawn). Fix (user: retune so all units clear): re-normalized pure-advance AND retreat scoring by **tiles traversed** instead of `move_path_cost` — a scoped exception mirroring `cancel_build` — so a full advance scores ≈0.16 for every unit regardless of move_cost; added a worked example (Heavy≡Scout), updated AC-20/AC-31, raised the two per-tile knob floors 0.05→0.10 (also closes systems-designer's dead-zone finding).

Recommended folded in: wounded-unit anti-oscillation exclusion + OQ-10 [ai-programmer]; OQ-1 corrected — narrowed the dirty-set pre-authorization to require a proven-equivalence gate, fixed the factually-inverted "memoization owed by movement/combat" claim (they defer a budget number; movement has a no-stale-cache invariant), noted the understated complexity constant [performance-analyst]; cadence-cap causal claim softened to "secondary" (Formulas note + knob row + Knob Interactions) + provenance flag + OQ-5 larger-board caveat [economy-designer]; AC tightening — AC-6 (two-path diff), AC-9b (placeholder 3000/400 ms), AC-17b (numeric ≈2.686/≈0.384), AC-18 (dropped phantom fixture path), AC-21 (concrete verification), AC-28 (field-scoped, not "byte-identical"), AC-33 (enumerated GIVEN + lethal-only scope note), new OQ-9 (AC-34 reference-opponent harness has no owning artifact) [qa-lead]; "economy-first accountant" passivity folded into OQ-7 [game-designer/economy-designer]; SCORE_TIE_EPSILON 64-bit-float note [systems-designer].

Registry: NOT touched — every changed constant is an AI-internal scoring knob (not a shared game fact); values referenced from other systems (OUTPOST_BONUS_TIER1, economy_outpost.build_cost) unchanged. No `/consistency-check` needed.

Deferred by design (tracked as OQs, not blockers): one-ply baitability incl. the new SETUP_ADVANCE_BONUS bait surface (OQ-8, ship-and-validate); relative-economy blindness + economy-first accountant tendency (OQ-7); AC-34 reference-opponent harness (OQ-9); perf ms budget + caching + test seams → `/create-architecture` (OQ-1). Two Player-Fantasy residues remain playtest-only advisory (AC-34 win-rate band; the subjective "credible sparring partner" questionnaire).

---

## Review — 2026-07-22 — Verdict: MAJOR REVISION NEEDED → revised in-file (re-review queued)
Scope signal: L (multi-system integration, 6 formulas, 7 hard dependencies; ADR hooks owed — perf budget, test seams, Pass-Through lint)
Specialists: ai-programmer, game-designer, systems-designer, economy-designer, qa-lead, performance-analyst, creative-director (senior synthesis)
Blocking items: 5 clusters | Recommended: 8 | Nice-to-have: 4
Summary: One hard correctness defect — the HQ (win-condition target) had no `build_cost`, so `combat_value`'s `ap_cost_opponent_paid_for(HQ)` was undefined → the AI would score every non-lethal HQ attack at 0 (below `PASS_THRESHOLD`) and never voluntarily siege, or crash on a strict lookup (confirmed independently by ai-programmer + systems-designer). Plus a cluster of Player-Fantasy *coherence* contradictions where the formulas forbade the behavior the fantasy promised: near-zero repositioning value (freezes between transactions = the doc's own "plays too passively" failure mode) and zero self-preservation (never retreats a dying unit). Creative-director's ruling: **"simple heuristic" excuses shallow, not incoherent** — deferring lookahead/opponent-modeling is fine for a VS, but passivity + no-self-preservation must be fixed. Also: Defense Tech scored below `PASS_THRESHOLD` (would never be researched) and Economy Tech scored 0 when researched early (inverting the game's own recommended sequencing); the ROI valuation cap made the AI a ~35% worse economic player than a human and flattened all outposts to one score; a wrong CR-4 citation; two undefined constants; and untestable determinism ACs (no epsilon).

Resolution (same session, per user decisions):
- **HQ gap** — added `HQ_SIEGE_VALUE` (12), live-field lookup, Worked Example 3, AC-29.
- **Tech scoring** — `TECH_VALUE_HORIZON` (10) for permanent buffs (Defense now clears at 0.184); `projected_completed_outposts` (completed + in-flight) for Economy Tech; `ATTACKS_LANDED_PER_TURN_ESTIMATE` → defensible 1.5; AC-17a/17b.
- **ROI cap** — decoupled: cap removed, replaced by `MAX_ECONOMY_INVESTMENTS_PER_TURN` cadence guardrail (CR-5 + AC-30); `economy_value` now ranks outposts (AC-16).
- **Coherence** — added forward-looking `SETUP_ADVANCE_BONUS` positional term + `retreat_value` self-preservation (AC-31/32).
- **Mechanical** — CR-4 citation fixed (+ AC-6b); `CANCEL_REFUND_RATE`, `SCORE_TIE_EPSILON` defined; "contact" operationalized; CR-7 pre-filter/post-hoc contradiction tightened; OQ-1 expanded (O(N²·W·H) shape, pre-authorized incremental-enumeration fallback, N≤24 worst case); AC-9b (responsiveness); AC-3 platform-scoped; AC-7 fixture+seed; AC-18 self-contained; AC-23 epsilon; test-seam dependency flagged (AC-5/6b/24); N/A row split → AC-33 (overextension) + AC-34 (win-rate band) promoted; new OQ-7 (relative-economy blindness) + OQ-8 (baitability, ship-and-validate).

Deferred by design (tracked as OQs, not blockers): baitability of the one-ply greedy model (OQ-8, ship-and-validate per creative-director); relative-economy blindness (OQ-7); performance ms budget + test seams (OQ-1 → `/create-architecture`).

Prior verdict resolved: First review (Status was "Designed", no prior log). Re-review recommended before implementation to confirm the in-file fixes hold and the large interlocking numeric changes introduced no new inconsistency.
