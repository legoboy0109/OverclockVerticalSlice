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
