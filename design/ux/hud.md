# HUD Design

> **Status**: Reviewed — APPROVED (`/ux-review` 2026-07-29, 0 blocking — S4-10 chrome finalization + slice-overlay fold; prior APPROVED 2026-07-27).
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-29 (S4-10)
> **Template**: HUD Design
> **Scope**: Vertical Slice (S2-05). VS AP verbs = **Move · Attack · Produce**.
> Build-outpost, research, and faction readouts are OUT of this slice; audio is
> representative/non-gating (game-hud story 008 trimmed per `production/vertical-slice/scope.md` §4).
> **Sources**: `design/gdd/game-hud.md` (primary; defers pixel-layout here in its Visual/Audio §B),
> in-slice GDD UI Requirements (ap-economy, movement, combat, base-production, command-action-interface,
> game-state-turn-manager), `design/ux/interaction-patterns.md`, `design/accessibility-requirements.md`
> (tier: **Standard**), `design/art/art-bible.md` (Neon Retro-Future, Non-Hue Semantic Layer §4).

---

## HUD Philosophy

**Information-dense, but the board interior is sacred.** OVERCLOCK is a perfect-information
turn-based tactics game (no fog), so every decision-relevant number is *always visible* —
this is the StarCraft II / Diablo end of the HUD spectrum, not the Dark Souls minimal end.
But Pillar 3 (*Readable Board, Deep Decisions*) means that density lives in the **screen
corners and edges**, never over the grid. The one-line rule:

> **The board interior is never covered by HUD chrome. All persistent readouts and controls
> dock to the top-center spine, the fixed control corner, and the log edge. The only marks
> inside board space are minimal per-tile readouts (hp, has-acted) that serve legibility
> itself.**

Three constraints inherited from the design canon, non-negotiable for this spec:

1. **Screen-space, zero diegetic** (art-bible §7.1). The AP counter and cost previews render
   at fixed size, contrast, and position regardless of board state or camera. Only the
   board-*overlay* layer (reachable/target/deploy tiles) is in-world, and that layer is owned
   by the Command & Action Interface, not the HUD.
2. **The AP counter dominates the frame.** The unified AP pool is the game's flagship number
   (Pillar 1). It is the single largest neon element on screen and owns the turn-start moment
   (fill flourish + YOUR-TURN banner fire off the same transition). This spec commits a concrete
   dominance floor — see Accessibility / §"AP counter dominance."
3. **Know vs. act split with the Command & Action Interface (#9).** The HUD *displays state*
   and hosts two persistent controls; the CAI *drives board interaction* (selection, previews,
   overlays, commit). The seam is specified per-element in **HUD Elements** and summarized in
   **Platform & Input Variants → Coordination boundary**. The HUD is a presentation leaf: it
   subscribes to CAI/GameState signals, and nothing downstream depends on it.

---

## Information Architecture

### Full Information Inventory

Every item the HUD may communicate, tagged with its source system, category, and VS status.
Aggregated from the game-hud GDD and the in-slice systems' UI Requirements.

| # | Information | Source | Category | VS status |
|---|-------------|--------|----------|-----------|
| 1 | **AP counter — committed remaining** | game-hud CR-3; ap-economy | **Must-Show** | In |
| 2 | **AP counter — preview echo** (`current → projected`) | game-hud CR-3; CAI | **Must-Show** (while a CAI preview is active) | In — all three verbs drive it |
| 3 | **Opponent AP** (`SHOW_OPPONENT_AP`, `OPPONENT` label) | game-hud CR-3b | **Must-Show** (during opponent turn) | In |
| 4 | **Turn / round indicator** (`active_player`, `round_number`) | game-hud CR-4; game-state | **Must-Show** | In |
| 5 | **YOUR TURN / ENEMY TURN banner** | game-hud CR-4 | **Must-Show**, transient | In |
| 6 | **End Turn control** | game-hud CR-2/CR-8/CR-10; CAI | **Must-Show** (persistent) | In |
| 7 | **Produce control** | game-hud story 007; base-production | **Must-Show** (persistent) | In (new VS surface) |
| 8 | **Action log** (one line per committed action) | game-hud CR-2/CR-7 | **Must-Show** | In |
| 9 | **Victory / defeat screen** (HQ-destroyed path) | game-hud CR-9 | **Must-Show** (event, full-screen) | In (HQ-destroyed only; MAX_ROUNDS/TIEBREAK N/A) |
| 10 | **Detail / inspection panel** (entity stats) | game-hud CR-6; CAI | **Contextual** (follows CAI selection/inspection) | In (VS-trimmed fields — see HUD Elements) |
| 11 | **Production capacity remaining** (`production_cap`, `units_produced_this_turn`) | base-production; game-hud | **Contextual** (detail panel, producer selected) | In — core produce-triage info |
| 12 | **On-board hp** (pips or numeric) | game-hud CR-5; combat, base-production | **Must-Show** (on-board) | In (units → pips; HQ hp ≥ `PIP_MAX_HP` → numeric) |
| 13 | **On-board has-acted marker** | game-hud CR-5 | **Must-Show** (on-board) | In |
| 14 | **Income breakdown** (`BASE_INCOME` + outpost + econ-tech terms) | game-hud CR-3, Formulas | **On-Demand** (hover/toggle) | In — but shows `BASE_INCOME(10)` only; other terms are 0 in VS |
| 15 | **Unspent-AP reminder** (`UNSPENT_AP_REMINDER`) | CAI | **Contextual** (near End Turn) | In (verb-agnostic nudge) |
| 16 | **Selected command readout** (armed verb · name · effective cost · affordability) | CAI; base-production/ap-economy | **Contextual** (while an action is armed) | In (S4-10 fold, Element 10a) |
| 17 | **No-op feedback toast** (why the last input did nothing) | CAI | **Contextual** (transient, after a no-op) | In (S4-10 fold, Element 10b) |
| 18 | **Input hint bar** (keyboard/gamepad control legend) | CAI / slice scaffolding | **On-Demand** (VS-persistent, collapsible) | In (VS onboarding; migrates to help/pause in full game — Element 10c) |
| — | Build button / legal-build-tile overlay | base-production | — | **Out** (build-outpost deferred) |
| — | Per-unit tech / research-in-progress marker | game-hud CR-5 | — | **Out** (research deferred) |
| — | Non-HQ structure hp, under-construction turns-remaining badge | game-hud CR-5; base-production | — | **Out** (no buildable structures in VS) |
| — | Cancel / refund affordance | base-production Rule 10 | — | **Out** — build-only; Produce is instant-commit (base-production Rule 7), no cancel window |

**On-board overlays that are NOT HUD chrome** (CAI/board-overlay layer — listed for boundary
clarity, specified in the CAI spec not here): reachable-tile + path/cost preview (movement),
attack-target + blocked-shot states (combat), legal-deploy-tile highlight (produce). The HUD's
only responsibility toward these is the **entry control** (the Produce button) and the
**production_cap readout**; the placement overlay itself is CAI-owned.

### Categorization

| Category | Items | Principle |
|----------|-------|-----------|
| **Must-Show** (always visible) | AP counter (1), turn/round (4), End Turn (6), Produce (7), action log (8), on-board hp (12), has-acted (13); opponent AP (3) during opponent turn; preview echo (2) while previewing; banner (5) & victory/defeat (9) as transients | Needed for the core per-turn triage or the "always know the state" promise (Pillar 3) |
| **Contextual** (visible when relevant) | Detail panel (10), production_cap (11), unspent-AP reminder (15), selected command readout (16), no-op toast (17) | Selection/state-dependent; shown only when they carry meaning |
| **On-Demand** (player-queried) | Income breakdown (14), input hint bar (18 — VS-persistent, collapsible) | Explanatory depth, not glance info — progressive disclosure |
| **Hidden** (world/audio, no chrome) | — (audio cues exist but are non-gating & always paired with a required visual; no HUD info is audio-only) | Non-Hue / accessibility: nothing gameplay-critical is a hidden channel |

> **Conflict check** — the Must-Show list is long (7 persistent items), which suits an
> information-dense strategy HUD, but it must not creep over the board. It doesn't: every
> Must-Show item docks to a corner/edge/spine or is a minimal per-tile mark. The board
> interior stays clear. ✔

---

## Layout Zones

Five fixed zones. Rationale: strategy players scan the **corners and top spine** for state
while their attention and cursor live on the **board center**, so state docks to the periphery
and the center stays playable.

| Zone | Location | Hosts | Movement rule |
|------|----------|-------|---------------|
| **A · Top-center spine** | top edge, horizontally centered | AP counter (dominant), turn/round indicator, opponent-AP display, YOUR/ENEMY-TURN banner (transient, self-clearing) | Fixed. Primary sightline. Never occluded. |
| **B · Fixed control corner** | one bottom corner (default bottom-right) | **Produce** button, **End Turn** button, unspent-AP reminder (adjacent to End Turn) | Fixed. Mirrors the CAI's own fixed End-Turn corner so the two never fight for the slot. ★ **2026-08-24**: also the anchor for the CAI's transient **Build type picker**, which opens from the Build control and grows up-and-left out of this corner — see the note under this table. |
| **C · Log edge** | opposite vertical edge (default left), collapsible | action log (newest-on-top, scrollable) | Docked; may collapse. Never floats over board. |
| **D · Detail panel** | edge-docked (default bottom-left, opposite the control corner) | detail/inspection panel + production_cap readout | **Edge-docked, NOT board-floating** — deliberately distinct from the CAI's on-board floating contextual menu so the two never collide (one on-board, one off-board). |
| **E · On-board per-tile** | inside board space, fixed sub-positions per tile | hp pips/numeric, has-acted glyph | Minimal only. **hp legibility wins any per-tile layout conflict.** |

**Board interior:** clear of **HUD** chrome. No panel, log, banner, or overlay owned by this
document renders over the grid interior. The YOUR/ENEMY-TURN banner is this document's single
deliberate transient exception — it flashes across the upper board and self-clears before input is
expected.

★ **2026-08-24 — the rule needed one word ("HUD") and one cross-reference.** The Command & Action
Interface's **contextual action menu** also draws over the board interior, by design and by GDD
mandate (`command-action-interface.md`: "floats near the selected entity"). That is not a violation
of the rule above, because the rule is about HUD-owned chrome — but as written it read as absolute,
and Zone D's "one on-board, one off-board" phrasing reinforced that reading. Both are now qualified:

- **Zone D's separation is about the detail panel specifically** — the inspection panel is
  edge-docked so it cannot collide with the CAI's floating menu. It was never a blanket rule that
  every CAI surface floats and every HUD surface docks.
- **The CAI's Build type picker is anchored in Zone B**, not on the board, because Build is a
  player-level command with no entity to float beside (CR-5). It is a transient popover belonging
  to the Build control that summons it, present only while that choice is open — not persistent
  chrome competing for the slot. See `design/ux/action-menu.md` → *Placement — the Build picker is
  the exception*.

Neither surface is HUD-owned; both are recorded here so this document's layout rules stay true of
the screen a player actually sees.

### ASCII Wireframe (1080p landscape, fixed camera)

```
 ┌───────────────────────────────────────────────────────────────────────┐
 │                        ╔══════════════════╗                            │
 │                        ║   AP  7 → 3      ║   ROUND 4 · YOUR TURN       │  Zone A (spine)
 │                        ╚══════════════════╝   [OPPONENT AP 5]          │
 │                                                                         │
 │        · · · · · · · · · · · · · · · · · · · · · · · · · ·              │
 │        · · · ▲Scout· · · · · · · · · · · · · · · · · · · ·              │
 │  ┌──────────┐  ●●●○○ ✓          (board interior — clear)                │
 │  │ DETAIL   │· · · · · · · · · · · ■HQ · · · · · · · · · ·              │  Zone E (on-tile:
 │  │ Trooper  │· · · · · · · · · · · [32/40]· · · · · · · ·              │  hp pips / numeric
 │  │ hp ●●●○   │· · · · · · · · · · · · · · · · · · · · · · ·             │  + ✓ has-acted)
 │  │ atk 3     │· · · · · · · · · · · · · · · · · · · · · · ·             │
 │  │ move 2AP  │                                                         │  Zone D (detail,
 │  │ ▣ acted   │                                                         │  edge-docked)
 │  └──────────┘                                                          │
 │  ┌──────────┐                                        ┌──────────────┐  │
 │  │ ACTION   │                                        │  ▶ PRODUCE   │  │  Zone B (control
 │  │ LOG      │                                        │  ■ END TURN  │  │  corner)
 │  │ ·move    │                                        │  (2 AP unspent)│ │
 │  │ ·attack  │                                        └──────────────┘  │
 │  └──────────┘                                                          │
 └───────────────────────────────────────────────────────────────────────┘
   Zone C (log edge, collapsible)
```

### Chrome Finalization (S4-10) — provisional widget offsets → pinned zone anchors

`src/ui/game_hud/game_hud.gd::assemble()` positions its seven widgets at a *functional but
provisional* arrangement (its own class doc flags the final anchoring as this `/ux-design`
sign-off). This table pins each to a documented zone anchor + safe-zone margin; it supersedes the
raw `Vector2` offsets in code (which become the *implementation* of these anchors, not the source
of truth).

| Widget | Zone | Anchor | Safe-zone margin | Notes |
|--------|------|--------|------------------|-------|
| AP counter (local) | A | top-left of the spine cluster | ≥16 px / ≥3 % of the shorter axis | Dominant numeral (Element 1); never occluded. |
| Opponent AP | A | top-right | ≥16 px / ≥3 % | Muted `OPPONENT` treatment. |
| Turn / round + banner | A | center-top | ≥12 px top | Banner is the one sanctioned transient board-crosser. |
| Income breakdown | A | docked under the local AP counter | aligns to the AP left edge | On-demand (Element 9). |
| Action log | C | bottom-left, collapsible | ≥16 px / ≥3 % | Never floats over the board. |
| Command readout + Produce/End-Turn | B | bottom-right stack (readout top → Produce → End-Turn) | ≥16 px / ≥3 % | Element 10a docks onto the existing control corner. |
| Detail panel | D | center-right, edge-docked | ≥16 px right | Distinct from the CAI on-board menu (D vs on-board). |
| Input hint bar (10c) | letterbox | center-bottom band | inside the reserved band | Collapsible; never over the board. |

**Acceptance (screenshot-verifiable — resolves the `game_hud.gd` sign-off):** at **1080p and 1440p**,
(a) no widget's bounding rect overlaps another's; (b) the board interior (the tile grid) carries
**no** HUD chrome except the transient turn banner and the Zone-E per-tile marks; (c) every HUD text
run renders at ≥ the Element-1 minimum and clears the safe-zone margins. Captured as
`production/qa/evidence/hud-chrome-layout-evidence.md` (the advisory Visual/Feel sign-off, S4-07).

---

## HUD Elements

Element-by-element. Interaction patterns are referenced by name from
`design/ux/interaction-patterns.md` rather than re-specified.

### 1. AP Counter (Zone A) — Must-Show, the dominant element
- **Content:** committed remaining AP; during a CAI preview, `current → projected` echo
  (pattern: **AP Counter Current→Projected Echo**). During the opponent's turn, shows the
  opponent's AP with a persistent `OPPONENT` label + muted/desaturated treatment (CR-3b).
- **Form:** the largest neon numeral on screen (see dominance floor in Accessibility).
- **FSM (4 states, story 003):**

  | State | Trigger | Behavior |
  |-------|---------|----------|
  | Committed (rest) | default | static |
  | Fill flourish | start-of-turn AP reset | one-shot, `AP_FILL_FLOURISH_MS` (400ms) |
  | Tick-down | a real `apply_action` commit spends N AP | discrete/chunky, `AP_TICK_DURATION_MS` (120ms), never smooth |
  | Preview echo | CAI preview active | live `current → projected`; **snaps** on open/change/close (pattern: **Snap, Never Tween**) |

- **Transition rules:** fill-flourish and preview-echo are mutually exclusive by construction;
  on `PlayerTurn`/`EndTurn` the echo is force-cleared synchronously *before* fill evaluates;
  a commit that triggers `GameOver` snaps any in-flight tick instantly (the one exception:
  the hp-pip drain from that same commit plays out fully — see element 6).
- **Accessible channel:** the `→` arrow + explicit numerals carry the committed-vs-projected
  meaning; the dim/desaturate echo styling is decorative only. Cost/damage numbers are
  **exempt from value-dimming** — always full brightness (art-bible §7.6).

### 2. Turn / Round Indicator (Zone A) — Must-Show
- **Content:** `active_player` identity + `round_number`. Persistent (CR-2).
- **Form:** compact text label beside the AP counter; event-driven update on turn change.

### 3. YOUR TURN / ENEMY TURN Banner (Zone A) — Must-Show, transient
- **Content:** whose turn just began. **Form:** large transient flash across the upper board,
  self-clearing before input is expected. Fires off the same `PlayerTurn` transition as the
  AP fill flourish. **Victory/defeat overlay takes precedence** over any in-flight banner.

### 4. Produce Control (Zone B) — Must-Show, persistent, interactive
- **Content:** a persistent button (default hotkey; see Platform variants). Composed from
  **Standard Button** (default / hover / keyboard-focus / pressed / inert states).
- **Behavior (know-vs-act seam):** the HUD owns the **entry button + hotkey + affordability
  dimming**; on press it hands off to the CAI, which owns the producible-type choice, the
  legal-deploy-tile overlay, tile selection, and the atomic commit. Produce is **instant-commit**
  (base-production Rule 7): pick unit type → pick an adjacent empty passable tile → AP spent
  immediately, unit appears Active. **No cancel/refund** affordance (that is build-only).
- **Dimming:** when the player has no producer selected/available or can't afford any producible
  unit, the button dims (pattern: **Affordability Dimming**) — never hidden, never red.
- **VS content note:** the control is generic over the selected producer's `producible_types`.
  Which producers/types exist in the VS (HQ = Scout-only per base-production, vs. a pre-placed
  Production Outpost or a full-roster HQ) is a VS-content question tracked in Open Questions —
  the control's design is unaffected.

### 5. End Turn Control (Zone B) — Must-Show, persistent, interactive
- Always-present, always-legal (CR-2). **Standard Button.** HUD owns placement + style; the CAI
  / turn manager owns the routing. The **unspent-AP reminder** (`UNSPENT_AP_REMINDER`) renders
  adjacent as a non-blocking nudge when the player ends a turn with AP unspent.

### 6. On-Board Glyph Layer (Zone E) — Must-Show
- **hp** (pattern: **Pip-vs-Numeric Display Branch**): entities with `max_hp < PIP_MAX_HP`
  (default 10) show chunky pips that drain **one at a time, no tween**, in neutral white/grey
  (**never** faction hue). Entities with `max_hp ≥ PIP_MAX_HP` (the HQ, hp 40) show numeric
  `current/max`. hp legibility wins any per-tile conflict.
- **has-acted marker** (accessibility resolution, this spec): an acted unit is **desaturated
  (brightness drop, not hue-shift) AND stamped with a small ✓ glyph in a fixed tile corner** —
  two redundant non-hue channels. Resolves the open has-acted accessibility question.
- Fixed per-tile sub-positions (hp along one edge, has-acted ✓ in a corner) so marks never
  occlude each other.

### 7. Detail / Inspection Panel (Zone D) — Contextual
- **Content follows the CAI's selection/inspection target** (HUD owns chrome only). Two visual
  states, distinguished by a **non-hue** channel: **pinned/selected** = solid accent edge;
  **peek/inspecting** = dashed/dimmed edge. Empty state when nothing is selected.
- **VS-trimmed field list** (the full GDD field set is mostly out-of-slice):
  - **Unit:** type · hp · effective attack · move AP cost · has-acted.
  - **HQ (structure):** hp · `production_cap` remaining this turn (`production_cap − units_produced_this_turn`).
  - **Excluded in VS:** tech markers, research status, buffs, build timers, non-HQ structures.

### 8. Action Log (Zone C) — Must-Show
- **Pattern: Scroll List** (read-only, append-driven, newest-on-top, oldest drops at capacity).
  One line per committed action: icon + short text. `ACTION_LOG_LENGTH` cap (default 20,
  range 8–50). Collapsible. Log entries are deliberately silent (no audio).

### 9. Income Breakdown (on Zone A) — On-Demand
- Revealed by hover or an explicit toggle (keyboard-accessible). Shows the `ap_income` terms.
  In the VS this is `BASE_INCOME(10)` only — the outpost and econ-tech terms are structurally 0
  (no outposts, no research). The breakdown UI exists and is correct; it simply has one live term.

### 10. Command Readout & Input Hints (Zone B + letterbox band) — Must-Show [S4-10 fold]

Folds the vertical slice's provisional screen-space status/legend overlay
(`vertical_slice_root.gd` `_build_status_overlay`/`_refresh_status` — a raw `CanvasLayer`+`Label`)
into proper, zone-docked HUD controls. The overlay's *turn-indicator* line is **dropped** — it
duplicates Element 2 (Turn/Round) + Element 3 (Turn Banner). The remaining three payloads become:

**10a · Selected Command Readout** — *Zone B (control corner), docked directly above the
Produce/End-Turn stack.*
- **Content:** the action the player is currently armed to commit, one line:
  `‹VERB› ‹display_name› · ‹effective AP cost› · ‹affordable | too expensive›` (e.g.
  `PRODUCE Trooper · 3 AP · affordable`, `BUILD Economy Outpost · 4 AP · too expensive`). Covers
  both the Build-arm and Produce-arm the CAI exposes.
- **Data source / owner:** `GameStateReader.can_afford_build`/`can_afford_produce` +
  `BaseProduction.effective_build_cost` / `Unit.effective_produce_cost` (read-only facade,
  ADR-0016 §1). Owner = BaseProduction / Unit — **never the HUD** (UI-code rule: display only).
- **Update trigger:** on arm/cycle change (the CAI selection/cycle) **and** on each
  `action_applied` commit (effective cost + affordability shift as shared AP is spent).
- **Affordability (dual-channel, Standard tier):** the word `too expensive` **and** the §4 non-hue
  **Affordability Dimming** treatment (brightness clamp) — never color-only, never red.
- **Empty state:** nothing armed → the readout is **absent** (not a blank row), so the corner stays
  quiet until the player is mid-decision.
- Supersedes the overlay's `Build [B]` / `Produce [P]` lines; the cycle-key affordances ([C]/[V])
  migrate to 10c.

**10b · Transient No-Op Feedback** — *Zone B-adjacent toast, screen-space, NEVER board-floating.*
- **Content:** one line stating why the **last input did nothing** — e.g. `Not enough AP`,
  `Nothing to act on there`. Appears only after a genuine no-op; a successful commit shows nothing
  (the action log + AP tick are the success feedback).
- **Queue / priority:** single slot — the latest no-op reason **replaces** any prior one (no stack).
- **Dismiss:** self-clears on the **next cursor move**, the **next successful commit**, or after
  `NOOP_FEEDBACK_MS` (Tuning Knob, default 2500 ms) — whichever comes first.
- **Data source / owner:** the CAI / slice command result (the no-op reason string). Owner = CAI.
- The proper home for the overlay's transient `_flash`. Pattern: **Toast** (single-slot variant) —
  a **new pattern**, not currently in `interaction-patterns.md`; flagged for addition there (with
  the single-slot/latest-replaces queue rule and the auto-dismiss timing).

**10c · Input Hint Bar** — *the camera's reserved bottom **letterbox band** (below the board;
Pillar 3 — never over the board interior), a styled collapsible control (not a raw Label).*
- **Content:** the current control legend — `[Arrows] cursor · [Enter] select · [M] move/attack ·
  [B]/[C] build/cycle · [P]/[V] produce/cycle · [Tab] end turn`. **ASCII-safe glyphs only** (the
  fallback font tofus bullets/arrows — see S4-09); localized (UI-code rule), reflow + reserve
  **+40 %** for translation expansion.
- **Behavior:** **default-visible for the Vertical Slice** — it is the naive-tester onboarding
  affordance the **S4-04 iso-legibility playtest depends on** (a silent-observer session needs the
  controls surfaced) — with a keyboard-accessible **collapse toggle**. In the full game the complete
  legend migrates to the pause/help overlay and this bar shows only contextual, just-in-time hints
  for the armed verb.
- **Gamepad variant:** key glyphs swap for button prompts in the same slots (partial-gamepad scope;
  full parity is a Production item, not a VS gate).
- **Visibility rule (Pillar 3):** anchored `PRESET_CENTER_BOTTOM` inside the letterbox band, so even
  at its tallest it never crosses the board interior; collapses to a single `[?] Controls` chip.
- **Pattern:** the collapse toggle composes **Standard Button**; the bar itself is a new
  **Contextual Hint Bar** element flagged for addition to `interaction-patterns.md`.

**Priority / visual budget:** 10a and 10b are **contextual** (present only mid-decision / right after
a no-op) so they add **0** to the resting simultaneous-element count; 10c is one persistent element in
the otherwise-empty letterbox band. None occupy Zone A (the sacred spine) or the board interior.

---

## Dynamic Behaviors

- **Redraw coalescing:** all event-driven readouts (AP counter, hp, has-acted, turn/round,
  banners) coalesce to **≤1 redraw per frame**. The HUD keys its AP-tick animation off the
  shared `action_applied` commit signal and relies on the CAI's `INPUT_LOCK_MS ≥
  AP_TICK_DURATION_MS` serialization guarantee — it must **not** reimplement that lock.
- **Game-over precedence:** the victory/defeat overlay appears within **one frame** of
  `GameOver` and wins over any pending/in-flight turn banner or tick. Exception: the hp-pip
  drain from the killing commit plays out fully (it *is* the feedback for the lethal blow).
- **Opponent turn:** all readouts stay live-displaying (perfect information); the two
  interactive controls (Produce, End Turn) go **inert (not hidden)**; the AP counter shows
  the opponent's AP with the `OPPONENT` label + muted treatment.
- **Turn-start beat:** AP fill flourish + YOUR-TURN banner fire off the same `PlayerTurn`
  transition; the preview echo is force-cleared first.
- **Reduced motion:** every flourish (fill, tick, banner) is reinforcement layered on top of an
  instant **Snap, Never Tween** state change, so a reduced-motion toggle strips flourishes with
  **zero information loss**.

---

## Platform & Input Variants

- **Input methods** (from technical-preferences): **Keyboard/Mouse primary**, **Gamepad
  partial**, **Touch none**, PC (Steam/Epic), readable at 1080p and 1440p.
- **Interactive/focusable HUD elements = exactly four:** Produce, End Turn, income-breakdown
  toggle, action-log scroll. Everything else is read-only and never focusable/clickable.
- **Focus traversal order (this spec's call): Controls → spine → log.** Keyboard/gamepad focus
  enters HUD chrome on the actionable controls first (Produce, End Turn), then the spine
  readouts/toggle, then the log — doing before reading, appropriate for a tactics game. The
  **board holds primary focus** via dual-focus; HUD chrome is entered on demand.
- **Dual focus** (confirmed present in Redot 26.2): each interactive element needs a
  **keyboard-focus indicator distinct from the mouse-hover state** (distinct `focus`/`hover`
  StyleBox slots; `grab_focus()` vs `grab_click_focus()`). Cross-references pattern
  **Three-State Focus Indicator** at the board boundary.
- **No touch layout** (out of platform scope). **Gamepad**: the four interactive elements are
  reachable in the focus order above; full gamepad parity is a Production hardening item, not a
  VS gate (CAI story 009 keyboard/dual-focus nav is trimmed from the slice).

### Coordination boundary with the Command & Action Interface (#9)

| Seam | HUD owns | CAI owns |
|------|----------|----------|
| Detail panel | Chrome, layout, style, presence | *Which* entity, *what* data (selection/inspection target) |
| Inline projected AP | The AP counter + its rendering | The `projected_remaining_ap` number |
| Produce entry | The persistent button + hotkey + affordability dimming | Post-press: type choice, deploy-tile overlay, atomic commit |
| End Turn | Placement + style | Interaction/routing (shared with turn manager) |
| Commit feedback | The AP-tick visual (subscribes to `action_applied`) | The commit-flash (also subscribes); **single audio owner**, never double-triggered |

The HUD **subscribes outward-in** to the CAI's selection/inspection signal (expected name:
`selection_changed` — see Open Questions; the CAI must never call into an HUD node directly).

---

## Accessibility

Target tier: **Standard** (WCAG 2.1 AA + AbleGamers CVAA). Comprehensive-tier items (screen
reader, HUD repositioning, mono audio) are explicitly out of scope for the VS.

- **Non-Hue Semantic Layer (structural):** no gameplay-critical HUD signal is ever color-only.
  Confirmed for every element here — hp uses pips/numerals (not a red-green bar), has-acted uses
  desaturation + a ✓ glyph, ownership uses hue *plus* silhouette/position, committed-vs-projected
  uses the `→` arrow + numerals (not the decorative dim). There is no separate "colorblind mode"
  to build; the default presentation passes. (Coblis verification still owed — non-blocking.)
- **Text:** critical readouts ≥ **20px at 1080p** (the AP counter far exceeds this by design);
  body contrast ≥ **4.5:1**, large text ≥ **3:1**.
- **AP counter dominance floor:** the AP counter's numeral height is **≥ 1.8× the next-largest
  HUD numeral** (turn/round, detail-panel stats) whenever it is on the local player's spine —
  satisfying the GDD's "must dominate the turn-start moment" mandate with a testable ratio
  rather than an intention. *(Provisional value — confirm with art-director against the shipping
  camera; flagged in Open Questions.)*
- **Reduced motion:** a toggle strips all flourishes (fill, tick, banner) with zero information
  loss (Snap-Never-Tween base). Covers photosensitivity for the AP flare/decay.
- **Timing:** no timed input that can't be extended/toggled. The only hold-timed interaction
  (Hold-to-Confirm Refund) is a build/cancel affordance and is **out of the VS** — but the
  accessibility commitment (toggle-to-confirm alternative) is inherited for when it lands.
- **Focus indicators:** all four interactive elements show a keyboard-focus indicator distinct
  from hover (dual-focus).
- **Hit-target minimum:** interactive controls (Produce, End Turn, income toggle, log-scroll
  affordance) present a click/activation target of **≥ 44×44 px at 1080p** so mouse and partial-
  gamepad-cursor users can reliably acquire them.

---

## Acceptance Criteria

Testable pass/fail for `/story-done` and `/ux-review`:

- [ ] The AP counter is the largest neon numeral on the local player's spine — its numeral
      height is ≥ 1.8× the next-largest HUD numeral at 1080p and 1440p.
- [ ] No HUD panel, log, banner, or control ever renders over the board interior (only the
      transient turn banner crosses board space, and it self-clears before input).
- [ ] During a move/attack/produce preview, the AP counter shows `current → projected`, snaps
      (no tween) on open/change/close, and reverts on cancel.
- [ ] Committing an action ticks the AP counter down discretely (chunky, ≤ `AP_TICK_DURATION_MS`)
      and appends exactly one line to the action log (no double-entry).
- [ ] Units with `max_hp < 10` show pips (drain one at a time, neutral grey/white); the HQ
      (hp 40) shows numeric `current/max`.
- [ ] An acted unit is both desaturated **and** shows a ✓ corner glyph (both channels present,
      neither color-dependent).
- [ ] The victory/defeat screen appears within one frame of an HQ being destroyed and overrides
      any in-flight turn banner.
- [ ] During the opponent's turn, the AP counter shows opponent AP with an `OPPONENT` label, and
      the Produce/End-Turn controls are visibly inert (not hidden).
- [ ] The Produce button dims (not hidden, not red) when no affordable/available production
      exists; pressing it hands off to the CAI deploy-tile flow.
- [ ] Keyboard/gamepad focus enters HUD chrome in the order Controls → spine → log, and every
      interactive element shows a focus indicator distinct from mouse-hover.
- [ ] With reduced-motion enabled, all flourishes are removed and no information is lost.
- [ ] The armed Build/Produce readout (Element 10a) shows `‹verb› ‹name› · ‹effective AP› ·
      ‹affordable|too expensive›`, updates on arm/cycle **and** on each commit, and is absent when
      nothing is armed — affordability shown by text **and** dimming, never color alone.
- [ ] A no-op input (e.g. insufficient AP) surfaces exactly one Element-10b toast that self-clears on
      the next cursor move, commit, or `NOOP_FEEDBACK_MS`; a successful commit surfaces no toast.
- [ ] The Input Hint Bar (10c) sits entirely within the bottom letterbox band (never over the tile
      grid) at 1080p and 1440p, is collapsible, and its strings route through localization.
- [ ] Every committed HUD widget sits at its Chrome-Finalization zone anchor with no bounding-rect
      overlap and clears the safe-zone margins at 1080p and 1440p (screenshot evidence).

---

## Open Questions

1. ~~**Player journey absent**~~ — ✅ **RESOLVED 2026-07-27 (S2-08):** `design/player-journey.md`
   now exists and its alignment check confirms this HUD's mid-match/focused/self-paced arrival
   assumption is consistent with the journey's Orientation/First-Mastery phases (no rework needed).
2. **`selection_changed` emit seam** (scope.md §8a) — the detail panel (element 7) consumes a
   CAI selection signal forward-declared by ADR-0016 §6 with no dedicated emit-story. This spec
   names the expected signal (`selection_changed`) as the target for the CAI addendum. Build-time
   seam, not a design gap.
3. **VS produce roster / producer content** — ✅ **RESOLVED 2026-07-27 (S2-07):** the VS
   **pre-places a Production Outpost per side**, so the HQ produces Scout (`producible_types =
   {Scout}`) and the Production Outpost produces Trooper/Heavy — the full scope §5 roster is
   producible with **no build verb**, base-production rules intact. Recorded in
   `design/assets/entity-inventory.md` and `scope.md` §5. The Produce control design was
   unaffected either way (generic over the selected producer's `producible_types`).
4. **AP-counter dominance ratio (1.8×)** — provisional; confirm with art-director against the
   shipping isometric camera during the iso-legibility playtest.
5. **Camera model (OQ-8)** — spec assumes a **fixed camera** (near-certain; Grid & Terrain's
   call) so on-board glyphs can be cached from `map_to_local()`. Cheap to correct if the camera
   becomes movable.
6. **MAX_ROUNDS / TIEBREAK_METRIC victory presentation** (game-hud OQ-2, AC-22) — no VS coverage
   (the VS has no round cap); the victory/defeat screen is designed HQ-destroyed-only but should
   remain extensible to a tiebreak result later.
7. **Audio (representative/non-gating)** — the AP-fill arpeggio, tick, turn stinger, and
   victory/defeat cues are designed to pair with the required visuals but are trimmed from the
   VS gate (game-hud story 008). Every cue already has a visual twin, so their absence loses no
   information.
8. **HUD chrome finalization + slice-overlay fold** — ✅ **RESOLVED 2026-07-29 (S4-10):** the
   provisional `game_hud.gd` widget offsets are pinned to zone anchors (Layout Zones → *Chrome
   Finalization*), and the slice's provisional status/legend overlay is folded into **Element 10**
   (Command Readout + No-Op Toast + Input Hint Bar). The design is of record here; the code fold
   (a proper control replacing `vertical_slice_root.gd`'s `_build_status_overlay`, retiring the raw
   `CanvasLayer`+`Label`) is a follow-up **dev story**, not part of S4-10 (whose AC is spec +
   `/ux-review` APPROVED). The windowed screenshot sign-off rides S4-07.
