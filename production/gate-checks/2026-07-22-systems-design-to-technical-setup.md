# Gate Check: Systems Design → Technical Setup

**Date**: 2026-07-22 | **Review mode**: lean | **Checked by**: gate-check skill

## Required Artifacts: [2/3 present]
- [x] `design/gdd/systems-index.md` — exists, 13 systems enumerated, Vertical Slice tier defined
- [ ] **All MVP-tier GDDs exist and individually pass `/design-review`** — NOT MET: AP Economy (#3) and Research/Tech (#8) are `Needs Revision`; Game HUD (#10) and AI Opponent (#11) were authored but have **never been run through an independent `/design-review`** (only self-checked during authoring); Faction Identity (#12) is `Not Started` (deliberate, gate-guardrailed exception, not an oversight)
- [x] Cross-GDD review report exists at `design/gdd/gdd-cross-review-2026-07-22.md` — but **stale**: verified via tool read (185 lines, real content), its own Verdict header still literally reads `FAIL` even though a same-day re-run confirmation pass (recorded only in session-state, not as a file) upgraded it to `CONCERNS`. Coverage also predates #9/#10/#11 — only 8 of 11 authored systems were ever cross-reviewed together.

## Quality Checks: [3/6 passing]
- [ ] All MVP GDDs pass individual design review — FAIL (2 Needs Revision, 2 never independently reviewed)
- [ ] `/review-all-gdds` verdict not FAIL — technically CONCERNS per the actual re-run, but the on-disk report file is stale and understates this
- [ ] All cross-GDD consistency issues resolved or explicitly accepted — NOT MET: the Economy-Tech dominant-strategy risk (boom + large-map composition) has been surfaced across multiple sessions without a final decision
- [x] System dependencies mapped & bidirectionally consistent — verified via `/consistency-check` (0 conflicts across all 11 systems)
- [x] MVP priority tier defined — Vertical Slice, clearly scoped
- [x] No significant stale GDD references — clean aside from one pre-existing, non-blocking hygiene note (a stale code-comment in `entities.yaml`)

## Director Panel Assessment

```
Creative Director:  CONCERNS
  Pillar fidelity strong across all artifacts. Sole concern: the dominant-strategy risk
  threatens Pillar 2's "no opening dominates" promise — a live tuning question, correctly
  owned and cross-linked, not a pillar violation. Must travel forward as a named open
  decision into the vertical slice, not be silently dropped.

Technical Director: CONCERNS
  GDD corpus is technically sound and sufficient to begin architecture work. Every
  perf-flagged item (Movement's reachable(), Combat's legal_targets(from_tile) fan-out,
  Command & Action Interface's CR-10 tiers, AI Opponent's clone()-per-commit loop) is
  named with concrete budget hooks, not silently missing. Two early-setup items: pin
  quantified performance budgets (technical-preferences.md still has [TO BE CONFIGURED]),
  and fix the dangling Redot engine-reference gap before any post-4.3 API lands.

Producer:           CONCERNS
  Scope is realistic for a solo dev. The dominant-strategy risk is the one item that
  genuinely reaches into Technical Setup itself — it touches map-size scaling, which an
  early board-representation ADR would otherwise hard-code around. Recommends scoping
  the first sprint to map-size-independent ADRs and making the map-size call a gating
  prerequisite before that specific ADR, not blocking the whole phase.

Art Director:       CONCERNS
  The Visual Identity Anchor was sufficient for the prior gate but not this one. The
  faction-hue colorblind fallback has propagated unresolved into 3 GDDs (Combat #6,
  Command & Action Interface #9 as OQ-4, Game HUD #10 as OQ-3 — HUD's own text says
  it "now gates three independent systems"). This has crossed from "fine to defer" to
  "should have been resolved by now." Recommends running /art-bible before or alongside
  Technical Setup, prioritizing Section 2 (faction identity + colorblind fallback).
```

**Notable convergence:** all four directors independently named the same root issue (the unresolved Economy-Tech dominant-strategy risk) as their primary or a leading concern — an unusually strong, cross-domain signal for a single open item.

## Blockers
None reach FAIL-level per the directors (all four returned CONCERNS, none NOT READY), but two items are load-bearing enough to treat as **soft gates on specific downstream work**, not the phase as a whole:
1. **The Economy-Tech dominant-strategy decision must be made before any map-size/board-representation ADR is written** — not before Technical Setup starts, but before that specific piece of it.
2. **Game HUD (#10) and AI Opponent (#11) have never been independently `/design-review`'d**, and the cross-GDD report is stale against the current 11-system corpus.

## Recommendations
- Decide the dominant-strategy question now (pin VS map size / scale rush timing with board size / explicitly name-and-defer to the planned economy spike) — or explicitly accept CONCERNS and carry it forward as a tracked open item, which the project's own prior analysis already treated as a valid path.
- Run `/design-review` on `design/gdd/game-hud.md` and `design/gdd/ai-opponent.md` in fresh sessions.
- Re-run `/review-all-gdds` across all 11 systems (current report only covers 8) — and correct the stale `FAIL` header on the existing report file regardless.
- Fix the dangling `docs/engine-reference/redot/` gap and quantify performance budgets as the first Technical Setup ADRs.
- Run `/art-bible`, prioritizing the faction-identity/colorblind-fallback section, before or alongside Technical Setup.

## Verdict: CONCERNS

Chain-of-Verification: 5 questions checked (2 via direct file re-reads: confirmed the cross-review report's real content and stale verdict header via `wc`/`grep`; confirmed the re-run's true CONCERNS outcome only exists in session-state history, not as its own file) — verdict unchanged. The strongest case for elevating to FAIL was the four-way director convergence on the dominant-strategy risk, but the project's own prior `/review-all-gdds` re-run already reached the same CONCERNS-not-FAIL conclusion, and no director found anything that would make architecture work itself impossible to *start* — only specific downstream pieces (the map-size ADR) need the decision made first.

## User Decision (2026-07-22)
User chose "Resolve first, then advance" — will not update `production/stage.txt` until the dominant-strategy decision, `/design-review` for #10/#11, and a full `/review-all-gdds` re-run are complete. Resolution order chosen: dominant-strategy decision first, then the two missing design-reviews, then the full re-review.

### Blocker 1 of 3 — RESOLVED (2026-07-22): dominant-strategy decision
A quantitative economy-designer model confirmed the Economy-Tech + boom + large-map risk is **real and structural** (not a tuning artifact): economy compounds on a fixed turn clock while rush compounds on a board-diagonal tile clock, so the two diverge sharply as board size grows — on 24×24 rush's earliest possible contact (turn 7) lands after boom has already outrun the income ceiling; on a small board rush contact lands while boom is still weak. The model also found the income formula is genuinely **uncapped** (`OUTPOST_BONUS_TIER2` +1/outpost forever; the "~26/~32" figures are illustrative, not enforced).

**User decision: pin the Vertical Slice to a single fixed 14×16 board** (map variety / editor / more terrain deferred to Alpha as future goals), and **deliberately NOT cap building count yet** (`MAX_OUTPOST_COUNT` stays disabled pending further simulation + playtest — tile scarcity on the fixed board is the interim ceiling). Propagated in-file: grid-terrain.md (Core Rule 1, Tuning Knobs, Open Question resolved), ap-economy.md ("Bimodal meta" Open Question resolved + the snowball-row hard-cap requirement softened to match the no-cap decision + the last owed Turn-Manager start-of-turn cite added), registry `grid_size_range` updated. **AP Economy #3 and Research/Tech #8 both returned to Approved** (the sole cited blocker is resolved; the separate non-blocking "which tech" concern stays a documented Open Question).

**Remaining before gate re-run:** Blocker 2 — `/design-review` for Game HUD (#10) and AI Opponent (#11) in fresh sessions. Blocker 3 — full `/review-all-gdds` re-run across all 11 systems (current cross-review predates #9/#10/#11 and its on-disk verdict header is stale at FAIL).
