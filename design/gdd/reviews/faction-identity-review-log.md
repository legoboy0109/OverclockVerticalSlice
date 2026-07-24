# Faction Identity — Review Log

## Review — 2026-07-22 — Verdict: NEEDS REVISION → revised in-file (pending confirmation re-review)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, ux-designer, ai-programmer + creative-director (senior synthesis)
Blocking items: 8 clusters | Recommended: ~10 (folded in same session)
Prior verdict resolved: First review

**Framing:** Framework-only GDD (locks the modifier schema/contract; all Rush/Boom balance numbers deferred to the faction-asymmetry prototype). Ships Neutral-vs-Neutral (all deltas 0), so the corpus's Approved numbers are unchanged. Bar = "is the framework sound + is the Neutral-ships-unchanged guarantee airtight," not "are the factions balanced."

**Deciding issue (why NEEDS REVISION, not APPROVED):** economy-designer #2 and systems-designer B-1 converged on the SAME latent defect — the published `ap_income` formula table (faction-identity.md:101) was a 3-term formula, missing the Economy Tech term + its `ECONOMY_TECH_TIER_THRESHOLD=6` cap that AP Economy (ap-economy.md:118) added to fix a real unbounded-income defect (ceiling 26→38 pre-cap). An implementer coding to the wrong table produces a Neutral build that silently diverges from the Approved economy curve = Neutral-correctness breach, the one class of error a framework-only GDD may not defer. Two independent methodologies landing on it = strongest signal of the review. NOT MAJOR: clamp arithmetic has zero degeneracy at any boundary (systems-designer confirmed); no schema re-architecture needed.

**8 blocker clusters — all fixed in-file same session (documentation + one formula correction, zero faction numbers required):**
1. Income formula table corrected to AP Economy's full 4-term form (tech term + cap load-bearing).
2. Added combined-income-ceiling framework rule (base×tech×faction re-approved as ONE n-swept ceiling) + split CR-2.3 into named intercept vs slope sub-levers.
3. `production_cap`: faction deltas floored at 1 (never 0) — asymmetric verb-deletion foreclosed; false Research-Lab (symmetric) precedent dropped. [user decision: floor at 1]
4. Combat-stat lock named as an accepted VS boundary; "teeth/overwhelms" prose reconciled to tempo/quantity-only; OQ-9 expanded to require prototype validation of Pillar-4 sufficiency-under-tempo-only + per-stat headroom audit.
5. `MIN_MOVE_COST` reclassified: it's Movement's existing `move_cost ≥ 1` precondition (needed today), not a faction-deferred floor — corrected in OQ-2, Formulas floors para, Tuning floors row.
6. Added OQ-10 (no cross-domain total-power budget — prototype must define/check an aggregate fairness metric across all 6 domains jointly before any real deltas).
7. AC-4 → AC-4a (executable now: effective_X==base_X vs base tables) + AC-4b (CI wiring, TD/lead-programmer-owned, infra-gated); AC-24 → behavioral half kept, "zero AI-specific code path" routed to code review (like CR-1/CR-3).
8. Three UX/schema contracts: (a) experimental factions gated behind an acknowledgment before lock (AC-27) [user decision]; (b) reserved non-hue `faction_pattern_id` field added to FactionDef schema (AC-6b) — closes the colorblind gap flagged 4× across the corpus (Combat/CAI/Game HUD/here), this GDD being the schema owner; (c) starting-loadout preview-before-lock (AC-28), per the corpus's preview-before-commit precedent.

**Other user decisions (via widget):** tech_available=false sanctioned as the deliberate binary "big" identity lever (intent stated in CR-2.5, flagged for per-faction review in OQ-5).

**Also folded in:** AC-26 (UNASSIGNED→ASSIGNED loadout-placement side effect), AC-20/21 renamed to prevent test-merging, AC-16 N defined (≥50), ceiling_X-is-dead-in-all-domains note.

**Owed to OTHER GDDs (NOT edited this session — cross-domain, route via /propagate-design-change):** OQ-6 reciprocity (5 upstream GDDs don't list #12 as downstream dependent); OQ-7 three AI Opponent contracts — LETHAL_FLOOR_BONUS re-opening along a faction axis (Rush cost delta shrinks build_cost → economy_ceiling_score rises → can cross the Neutral-tuned invariant), clone() must deep-copy faction_of(player), future AI cost-cache key must include `player`.

**Registry:** NOT touched (all changed values are faction-internal schema/contract; no shared-fact change). No /consistency-check triggered.

**NEXT:** confirmation re-review — `/clear` then re-run `/design-review design/gdd/faction-identity.md`. Confirm: (a) the corrected income formula matches ap-economy.md exactly and Neutral still computes base_X everywhere; (b) the production_cap floor-at-1 + tech-denial-sanctioned pair is internally consistent with CR-3; (c) no new inconsistency from the interlocking OQ/AC renumber. If it passes → #12 Approved (last VS system; corpus then 10/10 core Approved, Faction framework locked, values prototype-gated).

---

## Review — 2026-07-22 — Verdict: APPROVED (confirmation re-review; 2 new blockers fixed in-file, user-accepted without a 3rd pass)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, ux-designer, ai-programmer + creative-director (senior synthesis)
Blocking items: 2 (both fixed same session) | Recommended: ~8 (folded or logged as deferrable)
Prior verdict resolved: **Yes** — the prior round's deciding blocker (the `ap_income` formula table omitting AP Economy's Economy-Tech term + `ECONOMY_TECH_TIER_THRESHOLD=6` cap) was independently re-verified as a **byte-for-byte match** to `ap-economy.md:118` by both economy-designer and systems-designer. The one class of error a framework-only GDD may not defer (Neutral-correctness) is closed.

**Framing:** 2nd full pass on the same framework-only GDD. Bar unchanged: "is the framework sound + is the Neutral-ships-unchanged guarantee airtight." All 8 prior fixes held; the pass surfaced 2 genuinely new blockers introduced/exposed by those fixes.

**2 new blockers — both fixed in-file same session (documentation + one clamp rule + one FSM row, zero faction numbers):**
1. **[systems-designer, NEW — verified live vs base-production.md] `production_cap` cap-0 boundary gap.** Last round's floor-at-1 fix scoped only to structures whose base cap ≥ 1. But CR-2.4 grants factions `production_cap` delta authority with no roster exclusion, and `base-production.md` ships the Research Lab **and** Defensive Structure at `production_cap = 0`. "Faction delta on a base-cap-0 structure" was undefined — the default `max(1, base+Δ)` clamp would have silently forced a non-producer's cap 0→1, manufacturing a producer the design says doesn't exist (the exact asymmetric-verb-mutation bug 4c was written to prevent, relocated one case over). AC-12 tested only the no-delta half. **Fix:** Formulas 4c now defines a base-cap-0 branch (faction delta **inert** — effective cap stays 0); mirrored into CR-2.4, Edge Cases, and a new third GIVEN in AC-12. Unifying rule: a faction `production_cap` delta moves a cap only *within* the producing range [1, ∞) and crosses the produces/doesn't-produce boundary in **neither** direction (can't zero a base-positive cap; can't un-zero a base-zero cap).
2. **[ux-designer — verified real FSM contradiction] No pre-lock preview sub-state.** AC-27 (acknowledge before lock) + AC-28 (preview before lock) both require a "selected but not committed" state, but the States table jumped UNASSIGNED→ASSIGNED (which already fires loadout placement per AC-26)→LOCKED — the GDD's own ACs contradicted its own state machine, and `/ux-design` cannot invent a state the framework forbids. **Fix:** added a **SELECTING** sub-state; preview + acknowledgment now live on the SELECTING→ASSIGNED confirm transition; AC-26 updated so placement fires exactly once, at commit, never during preview.

**2 minor cleanups (folded same session):** AC-4a's "executable TODAY / no second build" softened to "runnable once any test-execution path exists" (project `tests/` is empty); Overview gained an explicit provisional-framework marker + a named OQ-9 reopen-trigger (if the prototype finds tempo-only asymmetry insufficient for Pillar 4, the CR-6 combat-stat lock reopens as a framework change, not a tuning pass).

**Specialist calls the creative-director OVERRODE (recorded for the log):**
- game-designer tagged 3 items "Blocking" arguing the framework should not be approved until Pillar-4 *sufficiency* (tempo-only vs combat-stat asymmetry) is validated. CD overrode: this holds a framework-only GDD to a balance bar it explicitly disclaims 4×, and inverts the pipeline (the prototype needs the locked framework to run against). 20% upheld → the provisional-framework marker (cleanup above).
- qa-lead tagged AC-4a "executable today" as Blocking → downgraded to a wording nit (cleanup above).

**Logged as deferrable (non-blocking — all no-op under the VS's Neutral default; NOT fixed this session):**
- `faction_pattern_id` (AC-6b) placeholder loophole — needs a real colorblind-safe asset gate before any *non-Neutral* faction ships; none ships in the VS. Owner: `/art-bible`.
- `BASE_INCOME_FLOOR` value undefined — economy-designer to pre-commit a concrete value (suggested: reuse BASE_INCOME=10) before any subtractive Rush income delta ships.
- **[ai-programmer] Add a forward-pointer in `ai-opponent.md` OQ-1** (the future caching ADR) recording the "cost-cache key must include `player`" constraint, so it isn't missed when that ADR is written. Cheap, cross-domain — route via `/propagate-design-change` with OQ-6/OQ-7.
- OQ-7's `LETHAL_FLOOR_BONUS` text under-scopes the risk (applies to any faction cost-reduction delta — units/tech, not just economy `build_cost`); widen when actioned.

**Registry:** NOT touched (all changed values are faction-internal schema/contract). No `/consistency-check` triggered.

**Corpus status:** **All 12 Vertical-Slice systems now Approved.** Faction framework locked; all Rush/Boom asymmetry values prototype-gated. Owed next (cross-domain, not this session): OQ-6 `/propagate-design-change` (5 upstream GDDs + the 3 AI Opponent contracts from OQ-7 + the cache forward-pointer above); a full `/review-all-gdds` re-run to confirm the corpus post-#9/#10/#11/#12; then `/gate-check` (Systems Design → Technical Setup).
