# Vertical Slice — Scope Definition — OVERCLOCK "One Close Skirmish"

**Task:** Sprint 2 · S2-04 (Vertical Slice scope definition)
**Owners:** creative-director + producer
**Date:** 2026-07-27
**Status:** Scoping complete — **gates the Sprint 3 VS build**. This is a scope doc, not the build.
**Depends on:** S2-01 (Core + Presentation + AI epics/stories — Complete 2026-07-27)
**Source canon:** `design/gdd/game-concept.md`, `production/gate-checks/2026-07-26-pre-production-to-production.md`, `production/epics/index.md`

> **What this document is.** A falsifiable scope for the OVERCLOCK vertical slice: the
> exact systems and stories in-slice, the two mandated playtests, the art/audio quality
> bar, the build seams to close, and PROCEED/PIVOT/KILL criteria. The build itself runs
> in Sprint 3 (`/vertical-slice` build path) and writes its REPORT + playtest logs
> alongside this file.

---

## 1. Validation Question (falsifiable)

> **Does a player, from a cold start with no guidance, complete one full *close* skirmish —
> reading a neon-isometric board at a glance while triaging a single AP pool across
> move, attack, and produce to out-tempo a minimal AI to a win/loss — and can the team
> build that loop at representative Neon Retro-Future quality within Sprint 3
> (+ Sprint 4 contingency)?**

Both halves must hold: the **player experience** (the tempo fantasy is legible and felt)
AND the **build feasibility** (this quality of loop is producible on schedule).

Two pillar sub-questions this slice exists to answer (the two unplayed pillars from the
2026-07-26 gate):

- **Pillar 3 — Readable Board, Deep Decisions:** Is the board readable at a glance under
  the *shipping* isometric camera? (Hard gate — `game-concept.md:219`.)
- **Tempo fantasy / MVP req #6 — Swing-back:** Can a *close, undecided* game be flipped
  through skilled stabilization, while a *decided* game stays decided?
  (`game-concept.md:370`.)

---

## 2. The Core Loop Cycle

**Atomic loop** (the "one playable turn" the S2-04 AC names):

```
select unit/structure
  → preview move range · valid targets · exact AP cost   (pre-commit affordance)
  → spend AP:  move  ·  attack  ·  produce                (unified AP pool)
  → resolve   (deterministic combat / production)
  → win-check (terminal? → GAME_OVER)
  → minimal AI reply (AI takes its whole turn)
```

**The slice** = this atomic loop repeated to a terminal state — a **complete short match**
played start → win/loss. One turn alone cannot exercise the win-check or the swing-back
arc, so the playable artifact is a full close skirmish, not a single-round demo.

**[start]** cold boot into a seeded small map, both sides at parity →
**[challenge]** several turns of AP triage (grow via produce vs. push via move+attack)
against a minimal AI that plays a credible tempo game →
**[resolution]** one HQ destroyed → GAME_OVER → win/loss screen.

---

## 3. Systems In-Slice

The slice's **logic is already built and headless-tested**. The slice work is almost
entirely the Presentation layer + a minimal AI — putting a playable face on a proven core.

| Layer | System | New work for the slice |
|---|---|---|
| Foundation | Game State & Turn Manager, AP Economy, Grid & Terrain | **None** — Complete (Sprint 1, 177/177 tests, QA APPROVED) |
| Core | Unit System, Movement, Combat Resolution, Base & Production | **None** — all Complete; Produce verb logic already exists |
| Presentation | **Board Renderer, Command & Action Interface, Game HUD** | **All new** — the slice *is* this work |
| Feature | **AI Opponent** (minimal VS heuristic) | **New** — the "minimal AI reply" |

Because **Base & Production is already Complete in Core**, adding the *Produce* verb to the
slice costs only presentation surface (a produce control + AI produce-scoring) — no new
engine work. This is why Move+Attack+**Produce** was chosen over Move+Attack-only: it makes
the unified-AP triage — the game's actual hook — real, at near-zero Core cost.

### AP verbs in-slice
`move` (Movement) · `attack` (Combat Resolution) · `produce` (Base & Production).

**Deferred verbs:** `build-outpost`, `research`. See §7 for the consequence (no compounding
economy lever) and the PIVOT implication.

---

## 4. Stories In-Slice (26) vs. Trimmed (4)

All in-slice stories are new Presentation/AI work. **Zero new Foundation/Core stories** —
that layer is Complete.

### Board Renderer — 5 of 5 (all in)
`001` grid↔screen transform · `002` y-sort depth scene skeleton · `003` overlay
TileMapLayer API · `004` pick-at (occupant priority) · `005` glyph-anchoring convention.
*Rationale:* the rendered board + picking + overlays + on-board glyphs are the shared
substrate of **both** mandated playtests. Sequence this epic first (it is the root the
CAI picking/overlays and the HUD glyph layer consume).

### Command & Action Interface — 8 of 9
**In:** `001` command-FSM core · `002` four-tier recompute (cost preview) · `003`
dependency-consumption contracts (`projected_remaining_ap` etc.) · `004` cancel-build
gesture (produce is in-slice) · `005` board-cursor input substrate · `006` iso-picking /
overlay integration · `007` commit-dispatch / input-lock / shared `action_applied` signal ·
`008` post-commit reselection + GAME_OVER convergence (surfaces the win-check).
**Trim → should-have:** `009` dual-focus / keyboard reachability menu-nav — the playtests
are mouse-driven; keyboard nav is a Production-hardening + accessibility follow-up, not a
gate for this slice.

### Game HUD — 7 of 8
**In:** `001` game-state reader facade · `002` HUD-config cross-config guard · `003`
AP-counter FSM · `004` AP-counter widget · `005` on-board glyph layer (HP pips / unit
state — critical to iso-legibility) · `006` detail-panel + game-over precedence (surfaces
the win-check) · `007` action-log + income + **produce/build controls** (this is where the
Produce affordance and income readout live).
**Trim → should-have:** `008` HUD audio dispatcher — representative SFX is nice-to-have,
non-gating, and trimming it dodges the un-spiked ≥2-`AudioStreamPlayer` ducking risk.

### AI Opponent — 6 of 8
**In:** `001` config knobs + invariant · `002` query-facade enumeration order · `003`
combat + production scoring · `004` economy + positional scoring (research enumeration
stays STUBBED — Research deferred) · `005` tiebreak comparator · `006` AI turn-driver loop
(the actual "AI reply"; adds `PlayerState.is_ai_controlled`).
**Trim → should-have:** `007` diff-harness fuzz corpus + `008` perf-budget assertion —
test-hardening. QQ-06 already measured PASS (~3.7ms p95); these are Production regression
insurance, not needed to *play* the slice.

### Deferred entirely (out of slice)
Build-outpost verb · Research/Tech (no epic/stories exist) · Faction asymmetry (Pillar 4 —
its own future prototype) · persistence / linked missions · full narrative/campaign · the
4 trimmed should-have stories above.

> **Traceability note:** the concept doc's *full* Vertical-Slice requirement list
> (`game-concept.md:363`) is larger (persistence across 2–3 missions, two asymmetric
> factions, campaign beats). This slice is deliberately the **minimal pillar-validating
> subset** the 2026-07-26 gate prescribed ("one playable turn of tactical combat, rendered
> on the board, with the isometric-legibility and swing-back playtests"). Faction asymmetry
> and persistence remain Pre-Production → Production exit work but are **not** what this
> first slice proves.

---

## 5. Content Scope

- **1 hand-crafted map**, small (target ~10×10–12×12 logical grid), authored in
  representative Neon Retro-Future terrain with at least one cover terrain type
  (cover −1, per the concept prototype baseline).
- **Two sides at parity** (symmetric — faction asymmetry is out of slice). Each side:
  1 HQ (sole producer) + a small starting roster.
- **Producible roster** (concept-prototype baseline AP costs): Scout 2 · Trooper 4 ·
  Heavy 6. Attack 2 AP. Deterministic combat, free counterattacks.
- **Economy:** base income 10 AP/turn, unspent AP lost. **Flat 10/turn** both sides
  (no outposts in slice — see §7).
- **Win condition:** destroy the enemy HQ → GAME_OVER (win-check logic exists from
  Sprint 1). Draw/timeout handling per existing turn-manager rules.

---

## 6. Quality Bar

- **Art: representative Neon Retro-Future — REQUIRED, not placeholder.** The iso-legibility
  test is only valid against the shipping-quality camera angle + silhouette-first units +
  faction-hue coding (art bible). A placeholder-art slice cannot validate Pillar 3.
- **Audio: representative-preferred, non-gating.** HUD-008 (audio dispatcher) is trimmed;
  crisp AP-spend SFX would serve the Sensation aesthetic but does not gate either playtest.
- **Code:** follows `docs/architecture/control-manifest.md` layers and
  `.claude/docs/technical-preferences.md` naming; no hardcoded gameplay values (config/
  `.tres`); basic error handling on the commit path. VS code is reference-only — never
  refactored into Production, never imported by Production code.

---

## 7. Known Limitations (documented, deliberate)

1. **No compounding economy lever.** With build-outpost deferred, income is a flat 10/turn
   for both sides. The slice therefore tests **allocation-triage swing-back** — how a player
   sequences a *fixed* budget across move/attack/produce under pressure — **not**
   **economic-snowball swing-back** (compounding an income lead). This is a real and
   sufficient test of the stabilization skill, but it under-tests the "compounds hardest"
   half of the tempo fantasy.
   **→ If swing-back feels flat in playtest, adding the build-outpost verb is the
   designated first PIVOT lever** (it is one already-Complete Core system + a CAI/HUD
   affordance away).
   **A flat/muted swing-back result is a PIVOT-to-build-outpost signal, never a KILL
   signal** — this slice cannot *falsify* economic-snowball swing-back because it
   deliberately does not build the lever. KILL applies only to build-feasibility failure
   or the total absence of any emotional high point (§10). *(CD amendment A, 2026-07-27:
   protects the concept from being killed on a test it was scoped not to run.)*

2. **Closeout-drag watch.** Produce + HQ-as-sole-corner-producer is exactly the named
   endgame-drag risk (`game-concept.md:292`). This is **not** a third gate, but a flagged
   observation: watch whether a losing player spam-produces from the corner and drags a
   decided game. If it manifests, it feeds the base-building/combat closeout answer — it
   does not by itself fail the slice.

3. **AI is "credible, not masterful"** by design (`ai-opponent` GDD, minimal VS scope).
   The Killers/Competitors appeal is only fully realized post-slice; the swing-back test
   uses this AI or a human opponent, and reads *whether the arc is possible*, not whether
   the AI is a worthy rival.

---

## 8. Build-Time Seams to Close

Flagged during the S2-01 story breakdowns; must be resolved **within** the Sprint 3 build,
not discovered during it:

- **(a) `selection_changed` emit** — HUD-006 (detail panel) consumes
  `CommandInterface.selection_changed(target)`, forward-declared by ADR-0016 §6 but with no
  dedicated emit-story in the CAI epic. → small CAI addendum during the build.
- **(b) Occupant clickable-region authoring owner** — BR-004 (`pick_at`) mocks per-sprite
  pick regions; the real authoring owner (likely a unit-scene story) must be assigned.
- **(c) Live `GameState.entities()` → BoardRenderer feed** — BR-002 stubs occupants; the
  live feed owner must be assigned so the board shows real state.

De-risked by trimming: **(d)** audio ducking ≥2-`AudioStreamPlayer` spike is moot while
HUD-008 is out of slice. **(e)** Research epic is not needed (AI-004 research enumeration
stays STUBBED).

---

## 9. Build Plan & Time Box

- **Time box:** Sprint 3 build; **Sprint 4 as contingency** (matches the 2026-07-26 gate's
  "Sprint 3 (+4 if needed)"). Total per `/vertical-slice`: 1–3 weeks. If it exceeds the box,
  the scope was wrong — **cut content, not quality.**
- **Day-3 sunk-cost checkpoint:** if the full loop cycle is not demonstrable by build-day 3,
  stop and surface the blocker (scope too large or an architecture assumption wrong).
- **Sequence:** Board Renderer (root) → CAI picking/commit spine → HUD binding →
  minimal AI (fully headless, parallelizable) → wire the produce affordance → playtest.
- **Playtests:** at minimum 1 documented session each for iso-legibility and swing-back;
  logged to `production/playtests/`. Prefer a naive tester (silent observation for feel;
  think-aloud for the onboarding/UI clarity read).
- **Swing-back sample floor** *(CD amendment C)*: observe **at least 3 close/undecided and
  3 decided games** (exact count at producer discretion within the box, but the floor must
  be named — one game is not evidence, and an unquantified "a sample" is not falsifiable).
- **Closeout-drag data capture** *(CD amendment B)*: in the decided games, record whether
  the losing player spam-produces from the corner HQ and drags the endgame (the exact
  Produce + sole-corner-HQ trigger of the named risk, §7.2). Not a gate — feeds the
  base-building/combat closeout GDD.

---

## 10. Success Criteria — PROCEED / PIVOT / KILL

### PROCEED (advance Pre-Production → Production)
- Player completes the full loop **unguided**, cold start → win-check.
- **Iso-legibility PASS:** board readable at a glance under the shipping isometric camera;
  unit silhouettes distinguishable in grayscale; ownership clear by hue.
- **Swing-back PASS:** over the sample floor (≥3 close/undecided + ≥3 decided games, §9),
  in the *close/undecided* set ≥1 flips via stabilization, AND in the *decided* set
  **none** reverse. (Also log the closeout-drag observation, §9 — not a gate.)
- Loop built within the time box at representative quality.
- The tempo fantasy is **felt** (not "kind of") — a specific moment where allocation
  decided the turn.

### PIVOT (revise, re-slice)
- Loop builds but a pillar fails:
  - **Board unreadable** → revise iso art / depth cues, or cut depth (Pillar 3 design test),
    then re-run the legibility playtest.
  - **Swing-back absent/muted, or a decided game DID reverse** → revisit economy tuning; the
    first lever is **adding build-outpost** (see §7.1). Revise the base-building/combat GDD
    via `/design-system`, adjust the relevant ADR, re-slice. **A muted swing-back routes here
    (PIVOT), never to KILL** (§7.1, CD amendment A).
- Capture a `PIVOT-NOTE.md` (what worked at slice quality, what failed, what the next slice
  must prove differently) before routing back.

### KILL (abandon the concept)
- Loop cannot be built at representative quality within the box, OR no emotional high point
  in any session, OR >50% of what was built needs architectural rebuild.
- **Low probability** — Foundation + Core are proven (177/177, QA APPROVED) and both HIGH
  engine risks (iso picking, dual-focus) were retired 2026-07-25.

---

## 11. Sign-off

| Role | Verdict | Date |
|---|---|---|
| Producer (scope authored) | Scope APPROVED — ready for Sprint 3 build | 2026-07-27 |
| Creative Director | **CONFIRM WITH AMENDMENTS** (A/B/C applied) — pillar-faithful, falsifiable, ready for Sprint 3 build | 2026-07-27 |

> **CD sign-off summary (2026-07-27):** Scope is creatively sound and disciplined. Pillar 3
> (readability) correctly in-slice and hard-gated; Pillar 4 (faction asymmetry) deferral is
> *correct experimental design* (it has its own follow-up prototype per `game-concept.md:322`,
> and is downstream of the shared AP-triage loop — bundling would confound results).
> Move+Attack+Produce is the right minimum to make Pillar 1 real; flat-income/no-outpost
> reduction accepted (stabilization swing-back is the half the gate flagged, and it is fully
> testable with a fixed budget). Three amendments applied: **A** — muted swing-back is a
> PIVOT-to-outpost signal, never KILL (§7.1, §10); **B** — capture closeout-drag data in the
> decided-game playtests (§9, §10); **C** — name a swing-back sample floor so the criterion is
> falsifiable (§9, §10). Endorsed specifically: the decided-game-must-not-reverse clause
> (enforces the anti-comeback stance, Pillar 2) and the "felt, not kind-of" qualitative bar.

> Next: run `/vertical-slice` (build path) in Sprint 3 against this scope. On a PROCEED
> verdict, re-run `/gate-check pre-production` — expected to flip the stage to Production.
