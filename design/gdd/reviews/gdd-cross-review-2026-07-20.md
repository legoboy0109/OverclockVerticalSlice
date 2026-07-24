# Cross-GDD Review Report

**Date:** 2026-07-20
**Skill:** `/review-all-gdds` (full)
**GDDs Reviewed:** 5 designed (of 12 Vertical-Slice systems)
**Systems Covered:** Grid & Terrain (#1), Game State & Turn Manager (#2), AP Economy (#3), Unit System (#4), Movement System (#5)
**Branch:** `design/initial-gdd-corpus`
**Registry baseline:** `design/registry/entities.yaml` (4 units, 3 formulas, 8 constants)

> **Scope caveat (dominant finding — read first):** only **5 of 12** VS systems are authored.
> **Combat (#6), Base & Production (#7), and Research (#8) are Not Started** — and the three
> highest-risk *cross-system* interactions (kiting, economic snowball, endgame closeout drag)
> all resolve inside those undesigned systems. This is therefore a **partial** cross-review:
> the designed 5 are internally very consistent; the marquee risks are flagged but **cannot be
> fully evaluated until Combat + Base & Production exist.**

---

## Consistency Issues

### Blocking
None.

### Warnings

**⚠️ C1 — Stale "Movement owes the surcharge formula" references (and stale Movement status).**
Three places still describe Movement as *owing* the soft-cap surcharge formula, but **Movement
already contains it** (its Formulas section defines `move_path_cost` + depth-dependent `reachable`):
- `unit-system.md` Dependencies: *"owes the new soft-cap surcharge formula — the Movement GDD is
  **Approved** and must be revised to add it; run `/propagate-design-change`."*
- `unit-system.md` Open Questions: same "must be revised to add it" handoff.
- `entities.yaml` `SOFT_MOVE_PENALTY` note: *"Surcharge summation formula owned by
  movement-system.md (owed — … must be revised)."*

Doubly stale: those references also call Movement **"Approved,"** but Movement's actual status is
**"In Revision."** Correct current state: Movement *has* the formula; what remains is a
`/design-review` of it — not "must add it." → Update Unit's two references and the registry note
to "added 2026-07-20, pending `/design-review`."
**Resolution (2026-07-20):** applied — see "Fixes Applied" below.

**⚠️ C2 — Dependency asymmetry: Unit ↔ AP Economy.**
`unit-system.md` lists AP Economy as a **Hard upstream** dependency ("`spend()` for
move/produce/surcharge costs"). But AP Economy's **Downstream** list enumerates *"Movement, Combat,
Base & Production, Research, Command & Action Interface, Game HUD, and the turn manager"* — **Unit
is omitted.** And `systems-index.md` Dependency-Map prose says *"Unit System — depends on: Grid,
Game State"* (omits AP Economy), while its own systems table (row 4) *includes* AP Economy. Three
docs, two stories. → Reconciled toward Unit's stated Hard dependency (Unit owns the cost values AP
charges): AP Economy's downstream list and the index prose now both include Unit System.
**Resolution (2026-07-20):** applied — see "Fixes Applied" below.

**⚠️ C3 (minor) — AP Economy writer-contract undercounts its own write paths.**
Rule 7 asserts `current_ap` is written by *"exactly two paths — the start-of-turn reset (Turn
Manager) and `spend()`."* But Rule 1 (and AC) define **end-of-turn discard as `current_ap := 0`** —
a third, distinct Turn-Manager write. Reword to "two *writers*, three *writes*" (reset, discard,
spend). Internal-precision nit on the Turn-Manager/AP-Economy ownership seam. *Not auto-fixed —
left for the AP Economy owner.*

**⚠️ C4 (minor) — Registry `referenced_by` lists incomplete.** `manhattan_distance` is
`referenced_by` only grid + game-state though its note says Movement and Combat use it. Housekeeping.

---

## Game Design Issues

### Blocking
None.

### Warnings

**⚠️ D1 — Sniper / ranged-kiting potential dominant strategy (Unit + Movement + Combat).**
The Sniper has the roster's best attack-per-AP + longest range (3) on a glass chassis. With
Movement's **no zone-of-control + unrestricted move→attack→move + multi-move-per-turn** and Combat's
first-blocker targeting (undesigned), a Sniper can fire from outside every other unit's counter-range
then step back under its own cap indefinitely — with **no piece that both reaches it and survives the
trade.** Unit System names this as a structural spike hypothesis and notes the soft-cap surcharge does
**not** tax a 1–2 tile standoff kite. Single biggest design risk in the corpus. Acknowledged and
spike-gated; Combat not yet authored → Warning, not Blocking. Design the ranged-combat spike to
measure **outcome variance (bimodal), not just mean win-rate**; reserve the ZoC / move-then-attack-cost
/ friendly-fire-blocking levers.

**⚠️ D2 — Economic snowball has only half its brakes designed (AP Economy + Base & Production).**
AP Economy's tiered-diminishing income (+2 → +1 past 4 outposts) is present and correct but is the
*only* snowball brake in a designed doc. The complementary levers — **hard outpost cap, build-time,
cost-scaling, rubber-band/catch-up** — are all owed by **Base & Production (#7), Not Started.** Until
it exists, the economy is an unbounded-ish positive-feedback loop (payback ≈2.5 turns, flat outpost
cost, no formula ceiling, no catch-up). Base & Production **must** state a hard max outpost count and
a catch-up stance.

**⚠️ D3 — Endgame closeout-drag remains unowned-in-practice (Base & Production + Game State + Combat).**
The prototype's named #1 problem — a losing player spam-produces from the fixed corner HQ and drags
decided games — has a *lever* in Game State (`MAX_ROUNDS` + tiebreak, off by default) and a
designated *owner* in Base & Production (production cap / rising cost / forward-deploy / attrition),
but the owner is **undesigned**, so no actual solution exists yet. Blocking for Base & Production's
own design-review; a Warning for the corpus today.

**⚠️ D4 (advisory) — Cognitive-load / analysis-paralysis of the unified pool.** Five spend targets
under one budget is by design *one* triage; the concept names the mitigations (building-momentum
pacing, readable board, pre-commit menu). Logged as a known managed risk to re-check in the
vertical-slice playtest. No action.

**No pillar drift, no anti-pillar violations.** All 5 designed systems map cleanly to Pillars 1–3
(Pillar 4/Factions correctly deferred). Grid's seeded procedural generation is correctly reasoned as
*not* violating the no-random-combat anti-pillar (pre-match, one-time, seeded). The soft-cap surcharge
prices over-extension **in AP**, reinforcing rather than violating Pillar 1. Player-fantasy across all
systems is coherent ("commander mastering tempo").

---

## Cross-System Scenario Issues

**Scenarios walked:** (1) Scout move-through-friendly + over-cap surcharge in one turn ·
(2) Heavy produced turn-1 tries to act · (3) Sniper move→shoot→retreat kite · (4) 5th outpost
completes → income tier crossing · (5) decided-but-dragging corner-spam endgame.

### Blockers
None.

### Warnings
- **Scenario 3 (Sniper kite)** — Unit + Movement + Combat → see **D1**. The move→attack→move loop is
  confirmed *enabled* by current rules (movement never gated by `has_attacked`; no ZoC; soft cap
  doesn't reach a 1-tile kite).
- **Scenario 4 (outpost snowball)** and **Scenario 5 (closeout drag)** → see **D2 / D3**. Both bottom
  out in undesigned Base & Production.

### Info
- **Scenarios 1 & 2 validate cleanly.** Soft-cap math is fully coherent across Unit ⨯ Movement ⨯ AP:
  a Scout moving 6 tiles = `4×1 + 2×ceil(1×2.0) = 8 AP` computes identically from Unit's Edge-Case
  worked example and Movement's `move_path_cost`. Heavy's turn-1 `7+3+2=12 > 10` "turn-2 investment"
  is documented and self-consistent (guarded by a regression AC). No data-flow break.
- **One claim for the pending Movement `/design-review` to verify:** the depth-dependent `reachable`
  (Dijkstra) has **path-dependent edge cost** (a tile's marginal cost depends on
  `tiles_moved_this_turn` + steps-so-far). The GDD's "cost only rises with depth → monotonic →
  Dijkstra valid" reasoning is essentially right (min-cost path = min-length path here), but it's the
  one genuinely non-obvious formal claim in the revised formula — worth an explicit check.

---

## GDDs Flagged for Revision

| GDD / file | Reason | Type | Priority | Status |
|-----------|--------|------|----------|--------|
| `unit-system.md` | Stale "Movement owes / Movement is Approved" surcharge references (C1) | Consistency | Warning | Fixed 2026-07-20 |
| `unit-system.md` | AP-Economy dependency asymmetry (C2) | Consistency | Warning | Fixed 2026-07-20 |
| `entities.yaml` | Stale `SOFT_MOVE_PENALTY` "owed" note + incomplete `referenced_by` (C1/C4) | Consistency | Warning | Fixed 2026-07-20 |
| `systems-index.md` | Dependency-Map prose omits AP Economy from Unit's deps (C2) | Consistency | Warning | Fixed 2026-07-20 |
| `movement-system.md` | Already **In Revision** — added `move_path_cost` + reachability need `/design-review` | Process | Warning | Pending review |
| `ap-economy.md` | Writer-contract "exactly two paths" wording (C3) | Consistency | Minor | Not fixed (owner call) |

---

## Fixes Applied (2026-07-20)

- **C1** — `unit-system.md`: both "Movement owes / is Approved and must add" references rewritten to
  "Movement has added the formula (2026-07-20); it is In Revision pending `/design-review`."
  `entities.yaml`: `SOFT_MOVE_PENALTY` note updated (formula added, pending review) + `referenced_by`
  clarified.
- **C2** — `ap-economy.md`: Unit System added to the Downstream dependents list.
  `systems-index.md`: Dependency-Map prose for Unit System now lists AP Economy (matching its own
  systems table and the Unit GDD).
- **C3, C4** — left for the owning-doc author (C3 is an AP Economy wording call; C4 folded into the
  registry note).

---

## Verdict: CONCERNS

No blocking issues. The five designed GDDs are internally consistent and cross-consistent to a high
standard — the only true consistency defects are **stale cross-references that lag a completed
revision** (Movement already owns the formula the others say it "owes"), all cheap edits (now
applied). The design-theory warnings (kiting, snowball, drag) are **real, cross-system, and already
tracked/spike-gated** — but they resolve inside **Combat and Base & Production, which are not yet
authored**, so this review is necessarily partial and those risks stay open by design.

**Not a FAIL** (no contradiction breaks the designed systems). **Not a PASS** (the review cannot yet
cover 7/12 systems).

### Recommended before re-running
1. ✅ Apply the C1/C2 stale-reference cleanups (done 2026-07-20).
2. Complete `/design-review` on Movement's revised `move_path_cost` + reachability.
3. Author Combat (#6) + Base & Production (#7), then re-run `/review-all-gdds` to evaluate the
   kiting / snowball / drag interactions for real.
