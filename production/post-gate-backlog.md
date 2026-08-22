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
- **cai-005 InputMap wiring** — letter keys are read by keycode rather than through
  rebindable actions.
