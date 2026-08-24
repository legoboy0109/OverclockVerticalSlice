# Post-Gate Backlog

Where design work goes while the **PROCEED / PIVOT / KILL** verdict is frozen.

Sprint 5's process commitments (retro action 3) say new design changes are routed here
rather than absorbed mid-sprint. That rule was written in `sprint-5.md` and referenced
twice, but **this file did not exist until 2026-08-21** — so the mechanism had no
destination for most of the sprint. Created when the first item was actually deferred to
it.

**Nothing here is scheduled.** Items are recorded with enough context to be picked up
cold, and with whatever would have to be re-checked or propagated alongside them.

---

## 1. Per-unit `attack_cost` — deferred 2026-08-21

**Decision: defer. User's call, same day it was raised.**

**What:** replace the flat `attack_cost = 2` with a per-`UnitTypeDef` value.
**Chosen spread, for when it happens:** **Scout 1 · Trooper 2 · Sniper 2 · Heavy 3**
(keeps the roster mean at 2, so total attacks-per-turn is unchanged).

**Why it was deferred rather than built.** `combat-resolution.md` already records this
question as **decided**, with an explicit revisit trigger:

> *"Decided flat 2 (keeps legibility; Unit's per-AP audit assumes a constant 2-AP
> denominator). **Revisit only if playtest shows a specific unit's attack is
> over/under-valued at 2.**"*

That trigger has not fired — **S5-04 has not run.** The idea surfaced from a *rendering*
side-effect (per-unit actionability differentiates more weakly than expected because a
flat cost-2 floors every fresh unit's cheapest option at 2), which is not the evidence the
decision asks for. Changing a core tempo lever immediately before the tempo playtest would
also mean S5-04 measures a combat economy different from everything analysed to date.

**What must be re-checked or propagated when it is picked up:**
- `design/gdd/combat-resolution.md` — the tuning table (range 1–3 with failure modes at
  each end) and the decided-flat-2 entry itself.
- `design/gdd/unit-system.md` — **the per-AP value audit assumes a constant 2-AP
  denominator** and works the Heavy calculation from it. Varying the cost invalidates it.
- `design/gdd/ai-opponent.md` — `ap_equivalent_cost` documents `attack_cost = 2` in its
  worked model. The **code adapts** (it reads the config through
  `Combat.attack_cost_for`), but the validated thresholds and worked analysis go stale —
  the same recompute the `RESEARCH_AP_COST` 2→1 change required.
- **`COVER_DR` interaction.** `combat-resolution.md` warns that at `COVER_DR = 2` with
  `attack_cost = 2`, more of the roster floor-locks into Cover. Per-unit costs could
  floor-lock *specific* units — check each value against it.
- **★ Scout-at-1 degenerate risk.** The tuning table's failure mode at cost 1 is
  "combat-spam swamps the one-pool tension", and Scout is exactly the min-1-damage-into-
  Cover case. Cheap repeated chip attacks are the thing to watch in playtest.

**Where the schema would go:** `attack_cost` onto `UnitTypeDef` (values in
`data/units/*.tres`), read by `Combat.attack_cost_for()`, which already dispatches on
entity kind and is the single call site everything else routes through
(`command_interface`, `command_fsm`, the AI, and the actionability predicate all use it).

---

## 1b. Round-cap tiebreak — metric and seat skew (raised 2026-08-21)

`max_rounds` was armed at 30 (`VerticalSliceRoot.VS_MAX_ROUNDS`), which fixed the fact
that matches could not end at all. Verification immediately surfaced two things that
were **not** fixed and are design calls:

- ~~**`TiebreakMetric.UNIT_COUNT` counts every entity, not units.**~~ **FIXED 2026-08-21.**
  `TOTAL_HQ_HP` implemented and made the default, as `game-state-turn-manager.md` always
  specified; `UNIT_COUNT` now counts units. The boom exploit is closed and unit-tested.
  `TILES_CONTROLLED` remains unimplemented — nothing defines what "controlled" means for
  a tile, and choosing a definition is a design decision, not a gap to fill.
- **★ NEW: should an exact tie cascade, or fall to the seat?** Two untouched HQs tie
  exactly, and the tie rule hands the game to `1 - active_player`. In AI-vs-AI that is
  100% of games, so the seat decides deterministically. A cascade — HQ hp, then unit
  count, then seat — would break most ties on play rather than position. Not implemented:
  the GDD lists the three metrics as alternatives, not a cascade, so building one is a
  design addition rather than a correction.
- **Capped games skew ~95–100% to player 1** — ★ *root cause now isolated: the AI's
  missing siege drive (below), NOT the metric.* Correcting the metric did not move the
  numbers at all, which is what proved it.
  Original observation: (18 of 19 AI-vs-AI games, including every game
  where player 0 started up to three Troopers ahead). Two identical deterministic agents
  on a mirrored map should not do that. Candidate causes: turn order, the
  `1 - active_player` tie rule, or the entity-count metric itself. **`LOCAL_PLAYER = 0`,
  so the human is on the losing side of the skew.** Needs diagnosing before a capped
  result can be read as a game outcome rather than a seat outcome.

### ★★ 1c. Bound the economy — the actual root cause (raised 2026-08-21)

A siege drive **was** added to the AI and **provably works** (7 tests; probed moving a
unit from 4 tiles to 2 from the enemy HQ, and spending leftover turn AP on siege moves).
**It changed nothing in a real match** — 0 HQ damage across 1,260 turn-rows.

Measured why: sweeping the siege weight against a Credit-rich position, the AI keeps
choosing `BUILD` until the weight hits **2.0–4.0, i.e. 12–20× the positional rate of
0.16.** Economy actions outscore manoeuvring by an order of magnitude, and with Credits
unbounded they are always affordable — so AP never reaches movement.

**Fix the economy, not the weight.** A Credit sink or cap bounds the accumulation, which
lets the existing siege term surface. Raising the siege weight into 2.0–4.0 instead would
make the AI abandon its economy entirely — trading one degenerate behaviour for another.

Everything else in the appendix hangs off this: unbounded Credits → economy always wins
scoring → no manoeuvre → no HQ damage → no decisive win → every game caps → tiebreak →
exact tie → decided by seat.

Also still open from the same pass: **there is no victory/defeat presentation for any win
path** —
`game-hud.md` CR-9 / AC-17 / AC-22 are all unimplemented. The slice now prints a one-line
status message on match end as a stopgap, which is explicitly not CR-9's screen.

---

## 2. Feel-value tuning pass — from Stories 007 / 008 / 010

`FLARE_DECAY_SEC` (0.45) and every constant in `entity_transforms.gd` are unpinned feel
values. **They must be tuned together, not individually** — the attack flare and the body
lunge are one beat, and tuning either alone is guesswork. Best done off an S5-07 recording
rather than in isolation.

Also unpinned and in the same family: `BREATHE_PERIOD_SEC` (3.0), `BREATHE_MIN`/`MAX`,
`SPENT_CLAMP`. Note `SPENT_BODY_TINT` is **not** free — it is a palette floor (see
`story-010`), so it does not belong in a taste-based pass.

---

## 3. Non-hue ownership markers, roster-wide — from S5-08

S5-08 shipped the ownership decal at `STRUCTURES_ONLY`. Accepted consequence: **a
unit-only read is hue-carried and does not survive full desaturation.** `marker_policy =
ALL` restores the board-wide channel at the cost of clutter under every unit.

Related and larger: **§5.2's Mass Distribution Bias silhouettes were never built** — all
26 Rush/Boom sprite pairs are pixel-identical. The art bible now records this honestly and
scopes it to Full Vision. Any faction beyond Rush/Boom, any Neutral-vs-Neutral mirror, or
any monochromacy claim re-opens it.

---

## 4. Accessibility re-audit — three rows still unchecked

`accessibility-requirements.md` schedules a re-audit of its Color-as-Only-Indicator table
against the *implemented* UI. S5-08 did the **faction-identity** row and found real drift.
The other three — **Board Overlay Taxonomy, Affordability Dimming, hp display** — are
still un-re-audited and should be checked the same way before any Standard-tier
accessibility claim is made publicly.

---

## 5. Deferred sprint items

- **S5-09** wear-variant placement pass · **S5-10** structure `damaged` tier. Both
  recommended for descope under the 2026-08-19 mid-sprint trade; neither gates the
  verdict. S5-10 **grew** — five structures owe a damaged tier now, not two.
- **Unit occlusion at board density** — S5-07 observed adjacent units substantially
  overlapping. Not a defect against any stated criterion; a legibility question for S5-03
  to judge, and a possible spacing/scale item after it.
- **`pass_threshold` unenforced in `choose_action`** — latent, carried since Sprint 4.
- ~~**cai-005 InputMap wiring**~~ — ✅ **done 2026-08-24 (S6-17).** The six board verbs
  (move-attack, build, produce, both cycles, end turn) were raw `event.keycode` matches
  and are now named actions carrying a keyboard key *and* a pad button. This is the
  precondition the rebinding UI needed — see item 6.

---

## 6. ~~Control-binding UI~~ — ✅ DONE 2026-08-24 (S6-24)

> **Shipped in `src/ui/settings/settings_screen.gd`**, reachable from the main menu and the pause
> overlay. Rebinding for all 9 board actions across keyboard and gamepad independently, with
> conflict warnings, persisted to `user://settings.cfg` via the new `GameSettings` store — the
> project's first settings persistence of any kind.
>
> ★ **It immediately found a real defect.** End Turn had been bound to keycode `16777218` — Godot
> 3's `KEY_TAB`; Godot 4's is `4194306`. The binding was not Tab, it was not anything, and nothing
> caught it: the InputMap accepted the value and the tests asserted the on-screen legend text rather
> than the binding. It took rendering a bindings table to see "Ctrl+" where "Tab" belonged. A
> regression guard now asserts every shipped keycode resolves to a real key name.
>
> **Also delivered from the same commitments:** UI scale 75–150%, and reduced motion — wired to
> `EntitySpriteFeed.glow_paused`, so it genuinely stops the slice's one ambient animation rather
> than storing an inert preference.
>
> **Still open, and moved out of this item:** `InputConfig.menu_keyboard_nav_enabled` (ADR-0014 §6 —
> there is still no `InputConfig` instance, and the ADR flags `FOCUS_CLICK` as its one unverified
> engine claim); a pad binding for `board_cursor_cycle`, which still has none; and **the Settings
> screen has no UX spec** — it was built from `accessibility-requirements.md` because
> `main-menu.md` OQ-3 was never authored.

### Original entry, kept for context

**Decision: not built until the main menu exists.** Recorded here rather than attempted,
because there is nowhere to put it — a rebinding screen with no menu to reach it from is a
screen the player cannot open.

### Why it is now worth building at all

Before 2026-08-24 there was nothing to rebind: the board verbs were raw `event.keycode`
matches in `VerticalSliceRoot._unhandled_input`, so a binding was a `match` arm rather than
data. S6-17/S6-20 converted all seven to named InputMap actions, each carrying a keyboard
key and a gamepad button:

| Action | Key | Pad |
|---|---|---|
| `board_act` | M | X |
| `board_build` | B | Y |
| `board_build_cycle` | C | LB |
| `board_produce` | P | B |
| `board_produce_cycle` | V | RB |
| `board_end_turn` | Tab | Start |
| `board_menu_focus` | ` | Back/Select |

Plus `board_cursor_cycle` ( `[` / `]` , **no pad binding assigned** — ADR-0014's own Risks
section left the shoulder-button choice open, and LB/RB went to the two cycle verbs) and
the engine defaults `ui_up/down/left/right` + `ui_accept`. **These are the rows a rebinding
screen would edit.**

### Where it belongs

`design/ux/main-menu.md` is **Approved** (`/ux-review` 2026-07-27) and already routes to a
**Settings** screen — "*Opens the settings screen (separate spec — see Data Requirements /
Open Questions)*". That settings screen has **no spec of its own yet**. Control bindings
belong under it; writing the rebinding UI first would mean inventing its host.

### Carried along with it, same home

- **`InputConfig.menu_keyboard_nav_enabled`** — ADR-0014 §6 names this accessibility toggle
  (keyboard/gamepad traversal off, mouse click still live, via `FOCUS_CLICK`). It does not
  exist, and neither does any `input_config.tres` instance — there is no config plumbing for
  `InputConfig` at all today. ⚠ The ADR flags `FOCUS_CLICK`'s traversal-suppression as **its
  one unverified engine claim**; verify against Redot 26.2 before building on it.
- **A pad binding for `board_cursor_cycle`**, which has none.

### What to re-check when picking it up

- Whether the seven actions above are still the full set — any verb added between now and
  then must be a named action, or it silently becomes unrebindable *and* keyboard-only.
- `accessibility-requirements.md`'s committed tier: remapping is a common Standard-tier
  expectation, so the settings spec should state whether this is required or optional there.
