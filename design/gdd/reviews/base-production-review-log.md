# Base & Production — Review Log

## Review — 2026-07-21 — Verdict: NEEDS REVISION → ACCEPTED (blocking items fixed in-file same session)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 6 | Recommended: 4
Summary: First independent `/design-review` of the Base & Production GDD (was user-approved,
pending review). All 8 sections present; dependency graph clean and reciprocal (Grid, AP Economy,
Unit, Game State, Combat, Research all exist and reciprocate). systems-designer independently
recomputed every formula and the full shots-to-kill matrix — **retracted** an initial divergence
claim after all cells verified correct (removing what would have been a false blocker). The creative
director applied the settled spike-gating precedent (Movement/Combat reviews): balance-risk concerns
about unplaytested closeout/turret/snowball numbers were ruled **advisory-and-spike-gated**, while
doc-honesty / cross-doc-staleness / AC-hygiene defects were sustained as blocking. Six blocking
clusters — all wording, cross-references, AC rewrites, and one ownership assignment, touching **zero
spike-gated numbers**:
(1) **[qa-lead, systems-designer]** the AC preamble claimed the Defensive-Structure-attack Integration
AC was "blocked until Combat's `attack()` accepts a structure attacker" — but `combat-resolution.md`
(same date) already defines that path; corrected to cite Combat's structure-attacker ACs as satisfied,
and Dependencies handoff #1 marked LANDED.
(2) **[systems-designer]** `MAX_OUTPOST_COUNT` "disabled = no-op" contradicted the registry: `ap_income`'s
`[10,26]` output range implicitly assumes n caps ~12 (verified: 26 = 10 + 2·4 + 1·(n−4) → n=12), so the
income ceiling silently leaned on a lever the doc called inert — clarified that "disabled" removes only
the *hard* cap and the range reflects the practical board-tile ceiling, with the large-board residual
flagged (same runaway AP Economy already tracks).
(3) **[systems-designer]** start-of-turn ordering (build-timer advance before income snapshot) had no
canonical owner — the Turn Manager's own Core Rule 3 even listed AP reset *before* start-of-turn
effects. Added an explicit numbered start-of-turn sequence to `game-state-turn-manager.md` (flags →
start-of-turn effects/build-advance → income snapshot); Rule 6 now cites it; AP Economy citation logged
as owed handoff #5.
(4) **[qa-lead]** the closeout-drag advisory AC was not falsifiable (bundled unbounded conditions, no
fixture, skill-sensitive) — split into two ACs (AC-CLOSEOUT-A / -B) with a shared fixed fixture (CF-1)
and reference play line, and stated plainly as tuning-advisory, not a correctness gate.
(5) **[qa-lead]** two ACs re-imported defects Combat's review log already fixed — the "spy hook"
win-check (undefined test-double infra) → a state-based win-signal assertion; "byte-identical results"
(undefined, implies nonexistent serialization) → a field-wise state-equality predicate + clone-isolation
AC, matching Combat's canonical language.
(6) **[economy-designer, CD-elevated]** the load-bearing closeout claim "winner is always ahead on the
exchange (6 vs 9 AP)" omitted the income-differential term that actually makes it true (winner's 6 AP is
marginal from a large pool; loser's 9 AP is the majority of a small one) — added explicitly, with a
24×24 AP-to-reach caveat; also corrected `economy_outpost_payback` (break-even turn 6, net-positive
turn 7) and the "20 AP to kill HQ" line (≥20 in attacks, materially more with no-banking + produce/march).
Three recommended items folded into the same pass: a Research Lab exclusion AC (`completed_outpost_count`),
design-rule-toggle smoke ACs (parallel construction on; structure attack research-buff off), and
cancel-refund boundary-rate (0.3/0.6) worked examples.
Advisory (spike-gated, NOT applied — validate in the vertical-slice combat/economy spike): the
multi-Production-Outpost closeout loophole; the 24×24 AP-to-reach vs rebuild-window question; the
absolute-AP-lead snowball with no decay; Defensive-Structure `can_counterattack` turtle-anchor tension
with Pillar 2; the placement rule's bias toward the safe HQ corner; the binary HQ-Scout-only fallback
feel; Defensive-Structure ROI (likely NOT a dominant "tax every boom" play); the 8×8 zero-legal-tiles
multi-turn softlock risk (flagged as a required 8×8 playtest case).
Specialist disagreement surfaced to user: game-designer rated the multi-outpost loophole BLOCKING;
economy-designer's arithmetic showed the base exchange is *more* lopsided in the winner's favor than the
doc claimed, which reduces the loophole's severity — CD resolved it as: the exchange math is a
doc-honesty fix (blocker 6), the multi-outpost residual is advisory/spike-gated.
Files touched: base-production.md (blockers + 3 recommended + status → Approved + handoffs),
game-state-turn-manager.md (canonical start-of-turn sequence + header), systems-index.md
(Base & Production → Approved; reviewed 5 / approved 4). User accepted the revisions to Approved without
a re-review. Cross-doc note owed: AP Economy (#3, Approved) to add a one-line cite of the Turn Manager
canonical start-of-turn sequence (additive, no value change).
Prior verdict resolved: First review.

## Review — 2026-07-22 — Verdict: NEEDS REVISION → resolved same session (Approved)
Scope signal: S
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 1 | Recommended: 3
Summary: Narrow re-review scoped to a single delta — Research/Tech #8's retune removed the
`economy_outpost_discount` build-cost hook (Economy Outpost `build_cost` is now flat, undiscounted 4 AP;
Economy Tech's benefit moved entirely into AP Economy's `ap_income` formula). All four specialists found
the removal itself clean — no stale discount references, formula errors, or broken incentives survived
anywhere in the doc; systems-designer independently recomputed `cancel_refund` and
`economy_outpost_payback` and confirmed both were always keyed off the flat cost, never the discount.
qa-lead found the one genuine gap: a missing regression-guard AC. The doc already carries a precedent
pattern for guarding a removed mechanism (the "Defensive Structure attack is not research-buffed" toggle
AC), but no equivalent AC guarded `build_cost` against the just-removed discount silently reappearing —
added, placed beside the existing design-rule-toggle smoke ACs. economy-designer self-flagged a
"borderline blocking" reader-misleading gap: nothing told a reader that build-cost is sequence-invariant
(research before/after building costs the same) while income *timing* is not (researching before
completion captures more teched-turns of AP Economy's bonus). Creative-director downgraded this to
Recommended — the timing math is AP Economy's ownership, not this doc's to duplicate — resolved with a
one-line cross-reference near the payback formula rather than importing the formula. Two more Recommended
items from game-designer folded in: the Dependencies "Provisional" entry on Research/Tech was stale (the
discount hook was its only live numeric tie; now zero), reworded to state that plainly; and Player
Fantasy's "richer future turns" framing got a one-line acknowledgment that the Economy Outpost's payoff
math is computed entirely by AP Economy, not this document. Nice-to-have items (un-teched ~26 ceiling
footnote, `build_cost` immutability note, `MAX_OUTPOST_COUNT` name-citation, teched-payback note)
deferred to a future hygiene pass — none load-bearing. Zero balance-number changes; fully consistent with
the doc-honesty/AC-hygiene character of the 2026-07-21 full review. User accepted the revisions to
Approved without a second independent pass.
Prior verdict resolved: Yes — the "B&P re-review of this removal is owed" note from the 2026-07-21
session is now satisfied.
