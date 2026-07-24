# Cross-GDD Review Report

**Date:** 2026-07-22
**GDDs Reviewed:** 8 (grid-terrain.md, game-state-turn-manager.md, ap-economy.md, unit-system.md,
movement-system.md, combat-resolution.md, base-production.md, research-tech.md)
**Systems Covered:** all 6 Approved Vertical-Slice core/economy/progression systems (AP Economy, Unit
System, Movement, Combat Resolution, Base & Production, Research/Tech) + 2 Foundation systems (Grid &
Terrain, Game State & Turn Manager)

**Context:** Triggered as a checkpoint after two same-day re-reviews (AP Economy, Base & Production)
resolved the Research/Tech retune's owed re-reviews, and a `/consistency-check` full run fixed 2 stale
narrative bugs. This is a deeper relationship pass — three parallel agents covered Cross-GDD Consistency
(Phase 2), Game Design Holism (Phase 3), and a Cross-System Scenario Walkthrough (Phase 4).

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **Non-reciprocal dependency — Base & Production ↔ Research/Tech**
`research-tech.md`'s Dependencies section lists Base & Production as a Hard upstream dependency (the
Research Lab is built entirely through B&P's generic structure mechanics — Core Rule 2b / build/cancel/
destroy lifecycle reuse). `base-production.md`'s Downstream dependents table does **not** list Research/
Tech — it appears only under B&P's "Provisional (undesigned dependency)" block. That framing is stale:
Research/Tech #8 is Approved, and the Research Lab is a landed, roster-table structure in B&P's own
Section D. Violates the project's bidirectional-dependency rule (`.claude/rules/design-docs.md`).
→ **Resolution needed:** `base-production.md` should list Research/Tech (#8) as a Hard downstream
dependent (Research Lab lifecycle), and drop the "undesigned" tag.

### Warnings (should resolve, but won't block)

⚠️ **Stale "Provisional/undesigned" tag** — same location as above; even independent of the reciprocity
gap, tagging an Approved system's only touch-point as "undesigned" is internally inconsistent with the
systems-index status.

⚠️ **Unit System asserts Movement is still "In Revision"** — `unit-system.md` (two spots, including its
own status framing around the soft-cap handoff) states the Movement GDD is "In Revision pending an
independent `/design-review`." Movement has been Approved since 2026-07-21 (confirming re-review, 3
blocking AC/precondition gaps fixed). Stale cross-reference.

⚠️ **Outpost payback figure mismatch** — `ap-economy.md`'s Open Questions table says outpost payback is
"≈2.5 turns at tier 1"; `base-production.md`'s `economy_outpost_payback` formula computes `4/2 = 2.0`
turns from completion (3 turns total elapsed including build time). Not load-bearing, but two documents
publish different numbers for the same quantity.

---

## Game Design Issues

### Blocking

🔴 **Economy-Tech + boom + large-map dominant strategy — a cross-system composition no single document
owns.** Three independently-flagged facts compose into a plausible dominant strategy:
1. `ap-economy.md` (Open Questions, "Bimodal meta by map size"): large maps (24×24) are boom-favored,
   small maps (8×8) rush-favored — economy is turn-bound, rush is tile-bound.
2. `base-production.md` (`MAX_OUTPOST_COUNT`): the hard cap is **disabled** in the VS — on a large board,
   `completed_outpost_count` is bounded only by tiles + AP, not a real ceiling.
3. `ap-economy.md` (Open Questions, "Economy Tech dominant-strategy risk") + `research-tech.md`: Economy
   Tech's compounding payback may make it strictly better than Attack/Defense Tech for any player ahead
   on outposts — **explicitly logged as not fixed** by today's `ECONOMY_TECH_TIER_THRESHOLD` cap (that
   cap restored the formula's diminishing-returns *shape*, not the strategic dominance question).

On a large map, a boom player who reaches Economy Tech may dominate with rush structurally unable to
close the game before the compounding spike lands — the exact "no single opening dominates" property the
concept prototype validated only at 8×8 symmetric melee (pure rush vs. boom, no tech layer), not
confirmed at scale or with the tech layer present.
→ **This is a genuine design judgment call, not a mechanical fix** — options include pinning the Vertical
Slice to one map size, making rush timing/economy scale with board size, or naming the composed risk in
one cross-linked place and deferring resolution to the already-planned economy spike. Not resolved
unilaterally in this review — flagged for the user to decide.

### Warnings

⚠️ **Unbounded outpost/research positive feedback (soft-braked only).** `completed_outpost_count` and
research-Lab count both compound with no hard cap — `MAX_OUTPOST_COUNT` is disabled, and Research's own
docs note Lab-spam "has no brake" (unlike the closeout-drag answer outposts get). Both are individually
flagged as "residual runaway" / "accepted snowball" in their owning docs, but the promised hard-cap lever
still doesn't exist anywhere, and today's ceiling increase (26→32) widens the surface.

⚠️ **Defense-Tech + Cover floor-lock on units.** A researched Scout is structurally capped to
`MIN_DAMAGE=1` against a Cover+Defense-Tech defender, and this **persists in the researched mirror match**
— both a dominant-defensive-posture risk and a difficulty-curve discontinuity (a downward cliff where a
stronger attacker reads identically to a weaker one, a Pillar 3 legibility hit). Already flagged with a
pre-committed fallback (`max(defense, cover_reduction)`) in research-tech.md's Open Questions — not a
fresh defect, but worth carrying forward as a real risk, not just a footnote.

⚠️ **Player attention budget growth.** Routing every action through one AP pool reduces *resource*
bookkeeping as Pillar 1 intends, but the number of distinct *sub-rules* competing for that pool has grown
past the prototype: `soft_move_cap`/`tiles_moved_this_turn`, line-of-fire blocking, cover, deploy-tile
choice, two build-placement constraints, research targeting. `unit-system.md` itself warns that >6-7 stat
dimensions "risks the spreadsheet the fantasy forbids." The load-bearing mitigation — the pre-commit
action menu (#9, Not Started) — isn't designed yet.

⚠️ **Boom endstate may break the "never quite enough" fantasy.** `ap-economy.md`'s own experiential AC
already flags that a boomed, researched player at the new ~32 ceiling may read as "solved"/unstoppable
rather than tension-under-budget. Overlaps the dominant-strategy finding above; carried as an open
playtest risk in that document already.

### Clean

✅ **Progression loop hierarchy** — economy/army are the intended primary axes; Research explicitly
self-frames as a "second-order spend... rarely a correct *first* pick." No player-confusion risk between
competing "what is the game about" loops.

✅ **No anti-pillar violations** — `build_time`/`research_time` are time gates, not hidden second
currencies (AP is still spent up-front in full); structure hp isn't a player-spendable resource;
`production_cap`/`units_produced_this_turn`/`has_attacked` are per-turn gates, not banked tracks; Economy
Tech correctly routes its bonus through the single AP pool.

✅ **Player Fantasy coherence** — every system presents a consistent "tempo-duel commander under budget
pressure" identity. Base & Production's "patient boom investment" and AP Economy's "never quite enough"
tension reconcile rather than conflict: booming is the bet that spending now compounds, and the player
remains AP-short throughout — they chose to invest rather than fight.

---

## Cross-System Scenario Issues

Scenarios walked: 5
1. Start-of-turn cascade — multiple Economy Outposts + a Research Lab (with Economy Tech) completing the
   same start-of-turn
2. Combat destroys an enemy's Completed Economy Outpost mid-turn
3. Economy Tech completing while other outposts are simultaneously under construction
4. Combat destroys an enemy's Research Lab mid-research
5. Defensive Structure counter vs. cover-immunity / the researched mirror floor-lock

### Warnings

⚠️ **Start-of-turn cascade — correct outcome, unsound stated rationale.** `game-state-turn-manager.md`'s
canonical sequence (start-of-turn effects, including both build-timer and research-timer advances, before
the income snapshot) means same-turn completions of both an Economy Outpost and Economy Tech correctly
feed that turn's `ap_income`. But `research-tech.md` justifies not ordering the two advances relative to
each other by claiming they "touch disjoint state (income vs. unit buff)" — **false for Economy Tech**,
which directly feeds `ap_income`. The outcome is right because step 4 strictly follows step 3 regardless
of intra-step-3 order, but the stated reasoning could mislead a future implementer.
→ Suggested fix: replace the disjoint-state claim with an explicit citation of the step-3-before-step-4
guarantee.

⚠️ **Research Lab destroyed mid-research — undefined trigger path.** Research's rule (AP lost, no refund,
tech reverts to Not Started) is stated and has an Integration AC asserting it, but no document — not
Combat, not Base & Production, not Research itself — defines the *mechanism* that observes a Research
Lab's destruction (a generic Combat hp-removal event) and triggers Research's state revert. The rule and
its test exist; the wiring between systems that would make it true does not.
→ Needs an explicit hook (e.g. Research subscribes to structure-destroyed events, or a post-combat sweep
in `apply_action` checks for orphaned research) — a candidate for a future ADR.

### Info

ℹ️ **Economy Tech + under-construction outposts** — clean. Both the base tiered term and the tech term
read the identical `completed_outpost_count` query at one snapshot instant; no double-count or stale-read
race exists. (Shares the same step-3/step-4 ordering dependency flagged above.)

ℹ️ **Defensive Structure counter / mirror floor-lock** — no new finding; already documented and owned in
research-tech.md's Open Questions with a pre-committed fallback. Structures are cover-immune (Combat Rule
6), so the "unbeatable turtle" variant is defused at the structure level — the residual risk is the
unit-level Cover+Defense-Tech floor-lock covered above.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| base-production.md | Missing Research/Tech as Hard downstream dependent; stale "Provisional/undesigned" tag | Consistency | Blocking |
| ap-economy.md | Payback figure mismatch vs. base-production.md; shares ownership of the dominant-strategy composition risk | Consistency + Design Theory | Warning / Blocking (shared) |
| research-tech.md | False "disjoint-state" ordering rationale; Lab-destruction tech-revert trigger undefined; shares ownership of the dominant-strategy composition risk | Scenario + Design Theory | Warning / Blocking (shared) |
| unit-system.md | Stale "Movement In Revision" references (2 spots) | Consistency | Warning |
| combat-resolution.md | Shares ownership of the undefined Lab-destruction revert trigger | Scenario | Warning |

---

## Verdict: FAIL

One blocking consistency issue (mechanical, low-risk fix) and one blocking design-theory issue (a genuine
design judgment call spanning three documents — not resolved unilaterally here) keep this from a clean
PASS.

### Required actions before re-running
1. Add Research/Tech as a Hard downstream dependent in `base-production.md`; reword the stale Provisional
   tag.
2. Decide how to address the Economy-Tech+boom+large-map composition risk — candidate options: pin the
   Vertical Slice to one map size; make rush timing/economy a function of board size; or name the composed
   risk explicitly in one cross-linked location (e.g. a new shared Open-Question entry in all three
   implicated docs) and defer numeric resolution to the already-planned vertical-slice economy spike.
