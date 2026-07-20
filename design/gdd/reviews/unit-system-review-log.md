# Unit System — Review Log

## Review — 2026-07-20 — Verdict: NEEDS REVISION (revised same session)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 7 | Recommended: 7 | Nice-to-have: 3
Summary: First full review. Two flaws were found independently by two specialists each (highest
confidence): (1) the Trooper had no defensible efficiency niche — Heavy out-valued it on hp/AP and
atk/AP at the same range 2; (2) Core Rule 5 authored Combat's cardinal-line targeting rule and owned
4 of the 11 ACs, with no precedence clause, guaranteeing cross-doc drift once Combat (#6) is written.
The doc also violated the checked-in tuning-knob rule (no safe ranges), its instance model lacked
`entity_id` and `type` fields its own ACs require, and its highest-risk axis (ranged combat/Sniper)
was unvalidated yet locked into "approved" numbers. Creative-director verdict: NEEDS REVISION (upper
end), not MAJOR — the architecture is the right shape and needs no reconception.

Revisions applied same session (7/7 blockers):
1. Heavy `produce_cost` 6→7 — Trooper now owns the range-2 efficiency band (1.5 hp/AP > 1.43). Synced
   to entities.yaml + ap-economy.md illustrative note.
2. Core Rule 5 demoted to non-authoritative summary + "Combat wins on conflict" precedence clause;
   the 3 targeting ACs moved to a ⟶Combat section (authoritative test lives in Combat's suite).
3. Status → In Revision; ranged subsystem marked Provisional/Experimental, spike-gated.
4. Kiting: added per-unit `soft_move_cap` + `SOFT_MOVE_PENALTY` — tiles past the threshold cost
   escalating AP (diminishing-returns shape, per user's design intent). Kiting/rushing stays viable
   but self-taxing. Movement GDD (#5) owes the escalation formula (handoff logged).
5. Core Rule 2 now lists `entity_id` (Grid occupancy key) and `type` (template ref); clone AC updated.
6. Tuning-knob rows given safe ranges + measurable if-too-high/low proxies; soft-cap knobs added.
7. Added hp-clamp, can_afford move-gate, and research-liveness ACs; split #7/#8; cross-player reset
   isolation; Sniper 6→7 case; bidirectional clone independence.

Folded-in recommendeds: Heavy turn-1 "intentional turn-2 investment" note; AP Economy's per-unit-cap
open question marked RESOLVED; Research-coupling constraint + precedence note; `Detailed Design` →
`Detailed Rules` heading; "Produced" state marked presentation-only.

Open cross-doc follow-ups (NOT resolved in this GDD):
- Movement GDD (#5, Approved) MUST be revised to add the soft-cap escalation formula.
- Ranged-combat spike owed before Sniper / attack_range / soft_move_cap / SOFT_MOVE_PENALTY lock.
- Combat GDD (#6) to receive the migrated ⟶Combat targeting ACs when authored.

Prior verdict resolved: First review.
Next: independent re-review in a fresh session (run `/design-review design/gdd/unit-system.md` after
`/clear`) to verify the revisions with clean context.

## Review — 2026-07-20 — Verdict: NEEDS REVISION → revised + ACCEPTED (Approved) same session
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 7 | Recommended: 7 | Nice-to-have: several
Summary: Independent re-review of the 2026-07-20 revision. The 7 original blockers all HELD, but the
revision traded them for a new cluster the panel found with high convergence: (1) the central fix's
rationale was factually wrong — "Heavy keeps the alpha crown" (Sniper atk 6 > Heavy 5) and "Trooper
owns the range-2 efficiency band" (the Scout ties Trooper on hp/AP and beats it on atk/AP and total
value/AP), found independently by game-designer + economy-designer; (2) the newly-added
`soft_move_cap` kiting tax arrived under-specified — undefined counting scope + missing
`tiles_moved_this_turn` state field (systems-designer), fractional-AP output breaking the integer-AP
invariant (systems-designer), a flat-vs-"diminishing-returns curve" internal contradiction
(systems + game-designer), and — most tellingly — it does NOT tax the 1-2 tile kiting it was added
for, only deep rushes (game-designer + economy-designer); (3) AC hygiene leaks survived — a
conditional `can_attack()` escape-hatch AC, two "pure" ACs that depend on Turn Manager, and hardcoded
researched-attack totals the doc's own Formulas section warns go stale (qa-lead). CD verdict: NEEDS
REVISION (focused, not MAJOR) — all bounded doc edits, no redesign.

Revisions applied + ACCEPTED same session (user chose Accept & mark Approved; ranged/kiting numbers
remain spike-gated regardless):
1. soft_move_cap → per-turn-cumulative counting; added `tiles_moved_this_turn` state field (Rule 2) +
   reset owner (`reset_turn_flags()` at start-of-turn).
2. Surcharge = `ceil(move_cost × SOFT_MOVE_PENALTY)` per over-cap tile (Rule 6a) — integer-AP invariant
   restored; worked examples recomputed.
3. Flat single-step surcharge language made consistent everywhere (no more "curve/escalating").
4. Kiting tax REFRAMED (user decision) as a deep-rush / over-extension brake — honest purpose; kiting
   split to its own named spike question.
5. Roster identities rewritten with audited per-AP numbers: Sniper = raw-attack leader; Heavy =
   concentration (no per-AP niche, stated intentional — doc-fix, not rebalance, per user); Trooper =
   efficient range-2 body; Scout = value/AP leader. False "alpha crown" removed.
6. Pure `can_attack()` / `reset_turn_flags()` / `duplicate()` guards added (Rule 2a) so Logic-gate ACs
   are genuinely pure; effective_attack AC de-hardcoded (reads Research config); added entity_id
   uniqueness + clone-scoping, may-still-move, in-memory-DI fixture, Heavy-turn-2 regression ACs.
7. `SOFT_MOVE_PENALTY` declared Unit-owned global constant + registered in entities.yaml
   (referenced_by movement-system.md).
Folded-in recommendeds: Sniper no-counter as a NAMED spike hypothesis + measure outcome variance;
"odd cost" corrected (Heavy 7 also strands 1 AP); friendly-fire blocked-shot UX note; per-unit
stat-dimensions tuning knob; decreasing-efficiency-curve intent stated; cost-7-Heavy build-rate open Q.

Open cross-doc follow-ups (NOT resolved in this GDD):
- Movement GDD (#5, Approved) MUST be revised to add the soft-cap surcharge summation — run
  `/propagate-design-change`.
- Ranged-combat spike owed before Sniper / attack_range / soft_move_cap / SOFT_MOVE_PENALTY lock;
  spike must test the Sniper no-counter hypothesis and measure variance.
- Combat GDD (#6) to receive the migrated ⟶Combat targeting ACs + owns attack_cost (2 AP) / damage
  formula / line-of-fire rule.

Prior verdict resolved: Yes — the 7 first-review blockers were confirmed closed; this pass's 7 new
blockers were fixed and accepted. Status → Approved (spike-gated ranged/kiting numbers noted).
