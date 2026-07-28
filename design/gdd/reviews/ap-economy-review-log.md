# AP Economy — Review Log

## Review — 2026-07-19 — Verdict: NEEDS REVISION → resolved same session (Approved)
Scope signal: M
Specialists: economy-designer, systems-designer, game-designer, qa-lead, creative-director (senior)
Blocking items: 4 | Recommended: 5
Summary: Full-mode adversarial review. Structure complete (8/8 sections, bidirectional deps intact,
formula arithmetic verified). Verdict NEEDS REVISION on four internal contract holes — all
resolvable inside the file, none blocked on the undesigned Base & Production (#7) / Research (#8):
(1) `ap_income` had no clamp on `n`, so a negative outpost count could drive `current_ap` negative,
violating Rule 7; (2) the "only active player's pool mutable" invariant and end-of-turn discard were
asserted in prose but unenforced in `spend()`; (3) the formula hardcoded `2×`/`1×` instead of its own
named tuning knobs; (4) AC gaps on named edge cases (spend-to-zero, completed-outpost-destroyed
mirror, active-player isolation) plus an ambiguous UI/backend AC. The creative-director sorted the
review along one line — internal contract hole (this doc's job) vs. joint-balance property (owned by
undesigned systems + playtest) — and overruled the economy-designer's snowball cluster and the
game-designer's per-unit-movement finding as genuinely DOWNSTREAM, not blockers on this Foundation
GDD. All 4 blocking items fixed: n-clamp added; `spend()` gated on active-player + discard formalized
as `current_ap := 0` + Rule 7 rewritten as enforcement with a writer-contract; formula wired to
`OUTPOST_BONUS_TIER1/TIER2`; ambiguous AC split and ~8 ACs added plus a stub-based test-strategy note
proving the Logic gate is not blocked on #7/#8. Downstream concerns (snowball/ROI/income-cap,
demand≥income joint AC, per-unit movement cap, map-size bimodality, downstream determinism,
`completed_outpost_count` contract precision) recorded as Open-Questions handoffs so ownership is
explicit. Accepted as Approved without a second-pass re-review (fixes were bounded and mechanical).
Prior verdict resolved: First review

## Review — 2026-07-22 — Verdict: NEEDS REVISION → resolved same session (Approved)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 5 | Recommended: 5
Summary: Narrow re-review scoped to a single delta — the Research/Tech #8 retune added an Economy
Tech income term (`+ ECONOMY_TECH_INCOME_BONUS × n` for a researched player) to `ap_income`, raising
the practical ceiling from ~26 to ~38 AP/turn. Specialists split on category: systems-designer verified
all arithmetic correct and framed the untiered term as a documentation-precision gap (recommended);
game-designer and economy-designer independently found the same fact — the term is unbounded/untiered
and structurally cancels `OUTPOST_BONUS_TIER2`'s diminishing-returns brake past n=4 (marginal value
reverts to the pre-tiering +2/outpost rate), with `MAX_OUTPOST_COUNT` confirmed disabled so no cap
exists anywhere in the stack — and classified it blocking. The creative-director sided with the
blocking framing: the original 2026-07-19 approval legitimately deferred snowball risk to Open
Questions *because tiering was a live brake*; the retune removed the premise of that deferral, so this
became an internal formula defect this doc must fix, not a known downstream risk. qa-lead separately
found zero acceptance criteria exercised `has_economy_tech(player)`, despite the Formulas section's own
worked examples including tech numbers. User chose to tier the Economy Tech bonus itself (own the fix
inside AP Economy, per creative-director's framing) rather than a flat cap or promoting a Base &
Production dependency, with the threshold raised from the specialists' suggested 4 to **6** completed
Economy Outposts (user's explicit choice, to keep the tech feeling stronger than a plain mirror of the
base tiers). Fixes: new AP-Economy-owned constant `ECONOMY_TECH_TIER_THRESHOLD` (6); formula's tech
term becomes `ECONOMY_TECH_INCOME_BONUS × min(n, ECONOMY_TECH_TIER_THRESHOLD)`; ceiling 38→32;
diminishing restored past n=6 (marginal reverts to +1/outpost, matching the no-tech rate); 4 new
tech-branch ACs added (tech-true, tech-false regression guard, tech-held boundary values, n=6-vs-n=7
cap-boundary assertion); test-strategy note updated to cover stubbing `has_economy_tech`; experiential
AC and two Open-Questions rows updated to the new ceiling. Economy-designer's separate finding — Economy
Tech's compounding payback may still make it strictly dominant over Attack/Defense Tech for a boomed
player — was **not** fixed here (routed as a recommended, non-blocking item to Research/Tech's next
revision, per creative-director's ownership split). Cross-doc reconciliation applied in-file (additive
only, no Research-owned value changed): research-tech.md's mirrored `economy_tech_income_bonus`
formula/tables/ACs, base-production.md's `MAX_OUTPOST_COUNT` knob note, and entities.yaml (new
`ECONOMY_TECH_TIER_THRESHOLD` constant, `ap_income` formula/output_range/notes updated, YAML
re-validated). User accepted the revision to Approved without a second independent pass.
Prior verdict resolved: Yes (2026-07-19 approval's snowball deferral was resolved for the internal
formula-defect portion; the dominant-strategy portion is routed onward, not resolved here)
