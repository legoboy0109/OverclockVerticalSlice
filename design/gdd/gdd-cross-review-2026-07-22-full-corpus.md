# Cross-GDD Review Report — OVERCLOCK (Full Corpus)

**Date:** 2026-07-22
**Mode:** `/review-all-gdds full` (Consistency + Design Holism + Cross-System Scenario Walkthrough)
**GDDs Reviewed:** 12 system GDDs + entity registry + systems index + game concept
**Systems Covered:** Grid & Terrain, Game State & Turn Manager, AP Economy, Unit System, Movement, Combat Resolution, Base & Production, Research/Tech, Command & Action Interface, Game HUD, AI Opponent, Faction Identity

> Supersedes `design/gdd/gdd-cross-review-2026-07-22.md` (that report predated the approval of Command & Action Interface #9, Game HUD #10, AI Opponent #11, and Faction Identity #12, and the 14×16 board decision). This is the first full-corpus pass with all 12 VS systems Approved.

**Method:** Three parallel analytical passes over the full corpus (consistency 2a–2f; design holism 3a–3g; cross-system scenario walkthrough), each cross-checked against the entity registry as the authoritative conflict baseline. Both scenario-pass BLOCKER claims were independently verified against the GDD source text and re-graded.

---

## Verdict: CONCERNS

No blocking cross-document contradictions, and no defect that forces an arbitrary choice at architecture time. The shared-fact layer (unit/structure stats, `ap_income` incl. the Economy-Tech cap, `damage_formula`, every named constant) is **fully consistent** across owner and referencing docs — the previously-blocking `ap_income` mismatch is confirmed resolved everywhere.

CONCERNS (not PASS) because two substantive **design decisions** are owed — both self-identified in the corpus's own review history and logged as open questions rather than decisions — plus a cluster of cheap documentation-freshness and FSM-parity cleanups. None blocks `/create-architecture`; the two design decisions affect parameterized tuning and a design stance that the vertical slice is meant to validate.

---

## Consistency Issues

### Blocking
None. Every registered shared value agrees across all referencing GDDs. (Coverage evidence below.)

### Warnings

**⚠️ C-1 — Stale board-size references survive the 14×16 pin (registry + grid-terrain + base-production)**
- Registry `manhattan_distance.output_range: [0, 46]  # 24x24 ceiling` and `notes: "...46 is the 24x24 ceiling."` — on the pinned 14×16 board the real ceiling is `13+15 = 28`.
- `grid-terrain.md` Formulas table cell `GRID_WIDTH, GRID_HEIGHT | int | 8–24 (VS)` contradicts the same doc's Core Rule 1 pin (`14 × 16`, "corner-to-corner Manhattan = 28").
- `base-production.md` still instructs "re-validate boom-vs-rush **at 8×8 and 24×24** whenever a structure cost moves" (lines ~524, ~768) and its shared closeout fixture **CF-1 uses an "8×8 map"** (line ~740); the closeout-drag math also caveats "validate the exchange holds **at 24×24**" (line ~417).
- *Why:* `46`/`8–24`/`8×8`/`24×24` are safe historical over-approximations, not live bugs, but they mislead architecture/perf sizing (AI + movement search cost, board-read budgets are all sized off board dimension) and point QA at board sizes the VS no longer ships. **Also flags a design gap (see D-4): the closeout-drag brake has never been re-validated against the *now-pinned* 14×16 geometry.**
- *Fix:* update the registry note + grid-terrain Formulas cell to state the VS-pinned 14×16 (Manhattan ceiling 28) while retaining 8–24 as the *engine* range; re-anchor base-production's CF-1 fixture and re-validation guidance to 14×16.

**⚠️ C-2 — `ap-economy.md` quotes an illustrative "research 6" cost that no longer exists**
- `ap-economy.md` Formulas note lists "…outpost 4, **research 6**, move per-tile 1/2/3…"; actual research costs are Attack 10 / Defense 10 / Economy 7 (research-tech.md + registry). No research action costs 6.
- *Why:* stale shorthand from before Research became three separate techs. Softened to WARNING because ap-economy.md explicitly labels the whole list "illustrative and non-authoritative — the owning GDD wins," but the number is simply wrong now.
- *Fix:* correct to `7/10/10` or drop the research figure from the illustrative list.

**⚠️ C-3 — `ap-economy.md` status tags describe downstream systems as unwritten/In-Revision that are now Approved**
- ap-economy.md Interactions table: `Research / Tech (In Revision 2026-07-21)` and `Command & Action Interface / Game HUD (undesigned)`; Dependencies lists Research under "Provisional (undesigned dependencies)."
- Reality: Research #8, C&A #9, Game HUD #10 are all Approved and actively reference `ap_income`.
- *Why:* same stale-status-cross-reference class already fixed in unit-system / combat / base-production headers. Misrepresents the dependency graph's maturity.
- *Fix:* refresh AP Economy's Interactions/Dependencies status tags.

**⚠️ C-4 — AI Opponent GDD header ("In Design") contradicts the systems index ("Approved")**
- `ai-opponent.md` header: `Status: In Design`. `systems-index.md` (#11, and the roster counts) says **Approved**.
- systems-index is also internally inconsistent: line 160 prose ("9 Approved, 1 Designed-pending-review") lags the per-row statuses (which now show #11 and #12 Approved).
- *Why:* documentation-state contradiction a `/gate-check` reader would trip on. No shared value affected.
- *Fix (design/PM call):* promote the ai-opponent header to Approved (matching the index) and refresh the systems-index roster-count prose to match the per-row statuses.

**⚠️ C-5 — Faction Identity (#12) → 5 upstream systems reciprocity gap**
- faction-identity.md declares Hard upstream deps on AP Economy, Unit, Base & Production, Research, Game State and self-flags (OQ-6) that 4 of those 5 do **not** list Faction Identity as a downstream dependent (Base & Production already does; Combat is already reciprocal).
- *Why:* violates the project "dependencies must be bidirectional" rule. Explicitly deferred as a no-op under the Neutral default the VS ships → WARNING.
- *Fix:* close via `/propagate-design-change` (adds Faction Identity as a downstream dependent + the additive `effective_X` contract note in the 4 upstream GDDs). Deferrable but owed before epics.

**ℹ️ C-6 (noted, no action required) — `CANCEL_REFUND_RATE` row in ai-opponent.md's knob table**
- Listed with an explicit "Owned by Base & Production… listed here only because `cancel_build_value` reads it" disclaimer. Not a true ownership conflict; flagged only because knob-table rows are where duplicate-ownership bugs hide. Keep the value pinned to B&P.

### Verified Consistent (coverage evidence)
Every registered fact was grepped against all 12 GDDs and agrees across owner + referencing docs: **unit stats** (scout 3/2/1/1/2, trooper 6/3/2/2/4, heavy 10/5/2/3/**7**, sniper 3/6/3/2/5; all def0/DIRECT/min1/no-counter); **structures** (hq 40/def2/cap2, econ-outpost 8/4/1, prod-outpost 14/9/2/cap4, def-structure 10/6/1/atk4/rng2/def1/counter-TRUE/immobile, research-lab 12/8/2/cap0); **`ap_income`** 4-term capped form (BASE 10, TIER_THRESHOLD 4, TIER1 2, TIER2 1, ECON_BONUS 1, ECON_THRESHOLD 6, range [10,32]) — quoted identically in ap-economy (owner), faction-identity (verbatim), research-tech, game-hud, ai-opponent; **`effective_attack`/`effective_defense`** two-flag split + bonuses 1/1; **`damage_formula`** + MIN_DAMAGE 1 + COVER_DR 1 + structure cover-immunity; **attack_cost 2 / DEFENSIVE_ATTACK_COST 1 / free counters**; **CANCEL_REFUND_RATE 0.5**; **MAX_OUTPOST_COUNT 10 disabled**; **board 14×16 / Manhattan 28**; **ap_reset_policy + canonical start-of-turn sequence**; **win_condition**; **research costs 10/10/7 + times 3/4/3**; **ECONOMY_TECH_DISCOUNT correctly deprecated everywhere** (with a regression-guard AC in base-production); **reciprocal query contracts** `is_surcharged` + `legal_targets(unit, from_tile)`. No stale heavy-cost-6, cover-−1-as-current, or free-counters-as-default leaked into live rules.

---

## Game Design Issues

### Blocking (for the *design*) → treated as owed DECISIONS (not architecture blockers)

**🟠 D-1 — Economy Tech is likely a dominant "which tech" pick for any boomed player**
- Attack/Defense Tech (10 AP / 3–4 t) give a *flat, non-compounding* +1. Economy Tech (7 AP / 3 t) at n=6 outposts gives +6 AP/turn forever, break-even ~2 turns from completion, and that AP is itself reinvestable — a **second-order compounding** return. Any player with ≥3 completed outposts should essentially always prefer it; a rush player with no outposts gets zero value from it. The "3-way tech choice" collapses into two disjoint archetype-gated 1-tech picks.
- *Status:* the corpus **already found this** (ap-economy.md OQ + research-tech.md) and logged it explicitly non-blocking/playtest-routed per the creative-director synthesis. The `ECONOMY_TECH_TIER_THRESHOLD=6` cap reduces but does not close the gap.
- *Why it's a decision, not an architecture blocker:* tech effects are data-driven; the fix is a tuning/framing choice, validatable in the slice.
- *Options:* (a) cap Economy Tech's cumulative lifetime value toward flat-buff parity; (b) make Attack/Defense scale too (all three second-order); (c) **accept it as archetype identity** (Economy = boom tech, Atk/Def = rush techs) and walk back research-tech.md's "real 3-way tempo decision" Player-Fantasy language; (d) leave as-is but revise the overclaiming framing.

**🟠 D-2 — No comeback mechanic exists anywhere in the corpus; every documented lever reinforces the leader**
- Traced every feedback loop: outpost→income→more outposts (uncapped in count); board control makes the winner's re-destroy exchange cheaper than the loser's rebuild (base-production's own closeout math admits this); Research is explicitly "the reward for winning, not an equal-opportunity power-up… it widens a lead." The only backstop is `MAX_ROUNDS` + tiebreak — a timeout scored *for* the leader, not a rubber-band.
- *Tension:* game-concept.md promises the "*Zero Hour* — clawing it back" swing-moment, and AC-CLOSEOUT-A/B only test that a *decided* game *closes*, never that a *close* game can *flip*.
- *Why it's a decision, not an architecture blocker:* this is a legitimate design stance (Into the Breach / SC2 lack rubber-banding too). Architecture can proceed; the swing-back is a slice playtest question.
- *Options:* (a) add a required VS acceptance criterion that explicitly playtests "swing-back from behind," not just closeout-from-ahead; (b) add a mild Pillar-2-safe comeback lever (small AP floor boost / cost relief when significantly behind) — cautiously, to avoid rewarding losing; (c) **accept the stance explicitly** and revise the concept doc's "clawing it back" framing to match the mechanics.

### Warnings

**⚠️ D-3 — 5 concurrent active decision-systems mid-game vs the stated 3–4 attention budget**
- Turn 5+ a player actively juggles: AP triage + Movement (with soft-cap surcharge math) + Combat (cover/blocked-shot states) + Base & Production (build/produce + timers + `production_cap`) + Research (which tech + Lab timers). The Command & Action Interface's own Visual/Audio section admits the "9-class non-hue overlay taxonomy is a heavy parse load" and mandates a **required legibility playtest**.
- *Fix:* treat that flagged legibility playtest (greyscale/colorblind-sim, timed board-reads) as a **hard VS gate**, reported against this 5-system count — not advisory.

**⚠️ D-4 — Closeout-drag brake never re-validated against the pinned 14×16 board**
- Base & Production's closeout answer was validated map-agnostically (CF-1 fixture, plus "validate at 24×24" caveats). AP Economy pinned the board to 14×16 to fix a *different* problem (rush/boom bimodality). The two good fixes were validated against different assumptions and never jointly re-checked at 14×16's actual geometry (corner-to-corner Manhattan 28). *(Pairs with C-1.)*
- *Fix:* re-run AC-CLOSEOUT-A/B against the pinned 14×16 board with real HQ placement geometry.

**⚠️ D-5 — Sniper's structural no-counter risk is flagged in 3 GDDs with a diffuse fix-owner and no pre-committed fallback**
- Unit/Movement/Combat all independently flag that the Sniper (range 3, best atk/AP, no counters roster-wide, no ZoC, move-then-attack-then-move) may have no unit that can both reach it and survive. Unlike the analogous Defense-Tech floor-lock (which has a pre-committed reserve lever: `max(defense, cover)` instead of additive), the Sniper risk leaves the lever choice open across three docs mid-spike — and ranged combat was never in the (melee-only) prototype.
- *Fix:* pre-commit one fallback lever before the combat spike (e.g., a Movement-owned partial-ZoC scoped to tiles adjacent to a Sniper), the way Defense Tech got one.

**⚠️ D-6 — Research functions as a leader-multiplier ("second-order spend"), thinning the concept's "co-equal tempo axes" claim**
- research-tech.md honestly states Research is "rarely a correct first pick… a second-order spend by a player who has already secured board presence." Combined with D-1, the live per-turn triage most players feel is **2-axis (army vs economy)**, with Research a rare third axis only the leader engages.
- *Fix:* either accept + document ("research is the reward, not the tool," revise concept framing) or give Research a genuine cheap early-game use case so all players engage the third axis.

### Info
- **ℹ️ D-7 (methodology gap):** each brake (income tiers, flat tech, AP-gated unit count) is *locally* validated, but no document runs a **combined 20-round joint-curve simulation** (income + tech + army-size together) for perfect-boom vs perfect-rush vs 50/50 lines. Recommend one spreadsheet/script model to surface any decided-by-turn-N inflection. (Same root as D-1/D-2, restated as a curve-shape/methodology observation.)
- **ℹ️ D-8 (positive finding):** **No anti-pillar violations.** No hidden RNG (seeded map-gen correctly distinguished from combat variance); no parallel resource (Faction's CR-3 is the strongest anti-pattern guard in the corpus); nothing real-time. Every GDD's claimed pillar holds on inspection. Genuine design discipline (e.g., structures-are-cover-immune exists specifically to close a Pillar-3 legibility trap).
- **ℹ️ D-9 (fantasy coherence):** all 12 Player Fantasy sections converge on "tempo commander with perfect information." One minor seam: AI Opponent honestly scopes to "credible, not masterful," slightly under the concept's "built for competitive strategists" promise — optionally add a one-line scope caveat to game-concept.md that the Competitor appeal is fully realized only post-VS (stronger AI / PvP).

---

## Cross-System Scenario Issues

Scenarios walked: 7 (income-snapshot vs mid-turn destruction; last-AP lethal blow vs win-check; frozen-income vs live-recompute; produce-then-kill-producer; deploy-tile race; Lab-destroyed-mid-loop; AI scoring during siege). The scenario pass was rigorously self-correcting and confirmed **most intra-turn races are impossible by construction** (single-verb atomic `apply_action`, no self-damage, start-of-turn-only research/build completion, AI re-clones every iteration).

### Blockers
None survived verification. (The two originally-rated blockers were both re-graded to warnings against the GDD source — see S-1/S-2.)

### Warnings

**⚠️ S-1 — `GameOver` terminal transition is explicit for the human active-committer but only *implied* for the two symmetric FSMs**  *(consolidates scenario Findings 2 + 6 — one shared fix)*
- The active player's Command Interface handles a self-caused `GameOver` explicitly (CR-11, States row `*(any state above)*`, AC-34). **Not** made explicit for: (a) the **passive opponent's** Command Interface instance (covered de facto — it's already inert during the opponent's turn per CR-11/AC-21, and Game HUD globally freezes input on `match_status=GameOver` per CR-9); and (b) the **AI's own** evaluate→commit loop — `COMMITTING → EVALUATING` is unconditional (line 55) and CR-6/AC-9 never name `GameOver` as a termination trigger, so post-lethal-blow the AI relies on the *unstated* guarantee that action-enumeration returns empty against a terminal state (Turn Manager's `apply_action` rejection backstops it, so worst case is one wasted loop — not broken play).
- *Why not blocking:* the experience is coherent in both cases (HUD freezes input + shows victory/defeat; Turn Manager rejects all further actions). But both rely on inference where the human path got an explicit rule.
- *Fix (one clause resolves both):* add "**any state/iteration, on observing `match_status == GameOver` (regardless of who committed), → terminal state, no further input/evaluation**" to both the Command Interface States table (passive instance) and the AI Opponent States table (COMMITTING→TURN_END when the commit's win-check set GameOver). Brings both to parity with the already-explicit human handling.

**⚠️ S-2 — `ap_income` breakdown temporal semantics (frozen snapshot vs live query) undocumented**
- `ap-economy.md` freezes `income_this_turn` at start-of-turn (unaffected by a mid-turn outpost destruction until next reset), but exposes a live-looking `income(player)` and Game HUD's on-demand income breakdown cites "`ap_income`'s own decomposition" without saying whether that's the **frozen snapshot** or a **fresh live** computation. After a mid-turn outpost kill the two can disagree (breakdown "3 outposts / 16" vs a pool topped to 18), reading as a bug.
- *Fix:* document the breakdown's temporal semantics — either it's the frozen `income_this_turn` decomposition (accurate to what funds the pool) or an explicitly-labeled "what your income *would be if reset now*" hypothetical. (The breakdown's *shape* is already owed to `/architecture-decision`; this adds its *temporal* meaning as a design question.)

**⚠️ S-3 — `produce()` commit-time re-validation doesn't explicitly cover producer survival**
- Base & Production's `produce()` Edge Cases + ACs test "under-construction producer → rejected" and "occupied deploy tile → rejected" but never state "producer destroyed/no-longer-Completed between preview and commit → rejected." Currently **impossible** (no verb self-damages a structure; `apply_action` is single-verb atomic) — a documentation gap, not a live race, but the door should be closed before any future verb (Faction ability, Alpha AoE) could open it.
- *Fix:* add an explicit Edge Case + AC mirroring the existing tile-occupancy re-validation: `produce()` re-checks the producer's existence/Completed status at commit.

### Info
- **ℹ️ S-4 — `clone()` clonable-surface completeness:** neither ai-opponent.md nor research-tech.md states that per-Lab research state (`current_research_target`, `research_turns_remaining`) + per-player tech flags are part of the deep-copy contract `clone()` guarantees for AI lookahead. Unit `duplicate()` and Grid/Entity state are explicit; Research's per-Lab/per-tech state isn't. *Fix:* add the guarantee to research-tech.md Dependencies or Game State's `clone()` contract.
- **ℹ️ S-5 — `SHOW_OPPONENT_AP=off` is a human-only handicap:** the AI reads authoritative `current_ap(any player)` (legitimate per CR-4's unfogged-state framing), so hiding opponent AP from the human HUD is never mirrored to the AI. Not necessarily wrong; just make the asymmetry explicit in the knob description.

---

## GDDs Flagged for Revision

| GDD | Item(s) | Type | Priority |
|-----|---------|------|----------|
| `ap-economy.md` | C-2 stale "research 6"; C-3 stale Interactions/Dependencies status tags; S-2 breakdown temporal semantics | Consistency + Scenario | Warning |
| `grid-terrain.md` | C-1 Formulas cell `8–24 (VS)` contradicts own 14×16 pin | Consistency | Warning |
| `base-production.md` | C-1 CF-1 "8×8" fixture + "re-validate at 8×8/24×24" guidance; D-4 re-run closeout at 14×16; S-3 `produce()` producer-survival edge case | Consistency + Design + Scenario | Warning |
| `ai-opponent.md` | C-4 header "In Design" vs index "Approved"; S-1 explicit GameOver terminal transition; S-4 clone research-state note | Consistency + Scenario | Warning |
| `command-action-interface.md` | S-1 explicit passive-opponent GameOver transition | Scenario | Warning |
| `research-tech.md` | D-1 Economy Tech dominance (decision); D-6 leader-multiplier framing | Design Theory | Decision owed |
| `faction-identity.md` | C-5 reciprocity gap (via `/propagate-design-change`) | Consistency | Warning (deferred) |
| `game-concept.md` | D-2 "clawing it back" framing vs mechanics; D-9 Competitor-appeal scope caveat | Design Theory | Decision owed |
| `entities.yaml` (registry) | C-1 `manhattan_distance` output_range note (28 vs 46) | Consistency | Warning |
| `systems-index.md` | C-4 roster-count prose lags per-row statuses | Consistency | Warning |

None is a blocking revision. All warnings are documentation-freshness, bidirectionality, or FSM-parity cleanups; the two "Decision owed" rows are design calls (D-1, D-2) that don't block architecture.

---

## Required actions before `/create-architecture`
Strictly, **none are blocking**. Recommended before or alongside architecture:
1. **Make the two design decisions (D-1 Economy Tech dominance; D-2 comeback stance)** — cheapest is to *accept + document* both explicitly and revise the overclaiming concept/research-tech framing, since architecture is data-driven and both are slice-validatable.
2. **Batch the cheap cleanups** (C-1…C-4, S-1…S-4) — mostly one-line edits; S-1 is a single shared FSM clause across two GDDs.
3. **Close the Faction reciprocity gap (C-5)** via `/propagate-design-change` before epics.

---

## Resolution (applied same session, 2026-07-22)

**Design decisions (user):**
- **D-1 — accepted Economy Tech as archetype identity** + reframed research-tech.md's "which tech" language (Overview + Player Fantasy) away from a "live 3-way toss-up"; added a **pre-committed lifetime-cap reserve lever** to research-tech.md Open Questions, gated on a combined 20-round joint-curve simulation (D-7) — held in reserve, not shipped. Handoff note reconciled.
- **D-2 — accepted the no-comeback stance** + reframed game-concept.md's "clawing it back / Zero Hour" language to *stabilizing a close game before it's decided*; added a VS validation requirement to playtest **swing-back-from-behind (close, not decided)**. Added the **D-9** Competitor-appeal post-VS scope caveat.

**Cleanups applied:**
- **C-1** — grid-terrain Formulas cell (`8–24 engine; VS pinned 14×16`), base-production re-validation guidance + CF-1 fixture re-anchored to 14×16, registry `manhattan_distance` note (28 VS / 46 engine).
- **C-2** — ap-economy "research 6" → "research 7/10/10 (Economy/Attack/Defense)".
- **C-3** — ap-economy Interactions/Dependencies status tags refreshed (Research/Command/HUD → Approved, "no longer provisional").
- **C-4** — ai-opponent.md header flipped to Approved (was "In Design") to match the index; systems-index Progress Tracker counts reconciled to 12/12 Approved (no per-row Status changed).
- **D-4** — base-production closeout brake flagged for re-validation against pinned 14×16 geometry.
- **S-1** — explicit `GameOver` terminal transition added to both the AI Opponent FSM (COMMITTING→TURN_END + CR-6 + new AC) and the passive-instance Command Interface (CR-11 + new AC-35).
- **S-2** — ap-economy Rule 5 + game-hud CR-3 now state the income breakdown decomposes the **frozen** `income_this_turn` snapshot, not a live re-compute.
- **S-3** — base-production `produce()` producer-survival commit re-validation edge case + AC added.
- **S-4** — research-tech marks per-Lab research state clonable in the Game State Hard-dependency row.

**C-5 — CLOSED 2026-07-22.** Faction Identity reciprocity wired into all upstreams: Game State, AP Economy, Unit System now list Faction Identity (#12) as a downstream dependent with the additive `effective_X`/income-delta contract (no-op under Neutral); Research, Base & Production, and Combat already reciprocated. (`/propagate-design-change` found no ADRs and a new/untracked GDD — no architectural propagation applicable pre-architecture — so the reciprocity edits were applied directly as the substance of the fix.)

**Still owed (not applied here):**
- **D-7** — the combined joint-curve simulation that gates D-1's reserve lever.
- **D-3 / D-4 / D-5** — VS playtest gates (interface legibility; closeout at 14×16; Sniper no-counter fallback) — validated in the slice, not editable now.
