# Story 008: Unit State Transforms — §8.5 Move Lean, Attack Lunge, Hit Recoil, Destroyed Beat

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation *(+ one Foundation-layer event, see Out of Scope)*
> **Type**: Visual/Feel *(secondary: Logic — the DamageEvent contract and the death-echo node lifetime are both automatable and are covered as blocking gates)*
> **Estimate**: M (1 day)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-20 (implemented)

## Context

**GDD**: `design/art/art-bible.md` §8.5 (animation frame standards), §2.2 (flare vocabulary)
**Requirement**: sprint story **S5-06** (Sprint 5, Should Have)
**ADR Governing Implementation**: ADR-0004 (event/signal architecture — the `DamageEvent` this
story finally builds is named in its own planned-event table), ADR-0013 (board rendering; no child
sets `z_index`), ADR-0002 (verb detail rides in events, never in a per-verb result type)

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW — `Tween` on `Sprite2D`, no new
engine surface. The one non-obvious constraint is that the shipped glow shader writes `COLOR`
directly and therefore ignores `modulate`, so the destroyed light fade drives `pulse_base` rather
than a node alpha.

**The states are transforms, not art.** §8.5 lists Move, Attack and Hit as animation states, but
the shipped assets are single-frame per state (`idle_01` / `destroyed_01` only, per
`assets/art/README.md`); no move or attack sheets exist and none are planned at vertical-slice
scope. Destroyed is the only state with real art, and it is the only one here that touches
`Sprite2D.texture`.

## Acceptance Criteria

1. **Move lean** — a moving actor tips into its direction of travel and settles back. Small enough
   to survive repetition (§8.5: "the most-seen animation").
2. **Attack lunge** — the attacker shoves toward its target and returns, snappy, on the same frame
   as its §2.2 glow flare so light and body spike together.
3. **Hit recoil** — the struck actor rocks away from its attacker: smaller, faster out and slower
   back than the lunge ("plating absorbs impact", not knockback).
4. **Destroyed cross-fade** — `idle_01` fades into `destroyed_01` with the glow driven to 0 over
   §8.5's **locked 2–4 frame beat**. Reads as a power-down, never an explosion (no gibs).
5. **A destroyed actor survives long enough to play its beat** — the node outlives the sync that
   drops it, and is freed cleanly afterwards with no orphan.
6. **A dying actor is not an occupant** — it holds no tile and cannot be picked, selected or
   targeted while its afterimage is on screen.
7. **A counterattack animates correctly** with no special case at the call site.
8. Motion never fights the board: a transform in flight is not stomped by an entity sync, and a
   sync does not cancel a transform.

## Implementation Notes

- **Offsets compose; they do not assign.** `_refresh_entity` rewrites every sprite's position on
  every sync, and a sync fires after every applied action — including actions that land mid-tween,
  since the AI commits on a pacing timer. Position is therefore `grid_to_screen(tile) + offset`,
  with sync owning the tile term and the tween owning the offset term. A tween writing `position`
  directly would be stomped roughly half the time. (AC-8.)
- **The lean is a rotation, not a slide.** Sprites are anchored at their ground-contact point, so
  rotation pivots at the feet and the actor genuinely tips. Rotating a bbox-centred sprite would
  drag the feet through the floor — this is the payoff of S5-01's pivot rule.
- **`self_modulate`, never `modulate`,** on the destroyed fade: `modulate` is inherited by children
  and would drag the glow overlay down on the body's curve, when the light is meant to lead.
- **The glow fade drives `pulse_base`, not node alpha.** `glow.gdshader` writes `COLOR` directly
  and ignores the incoming modulate, so fading the node would do nothing. Driving the uniform is
  also literally what AC-4 asks for.
- One tween per actor at most; a new motion kills the one in flight, so a rapid move-then-attack
  cannot leave two writers on the same offset.

## The death echo — why this story needed a core-layer event and a node-lifetime hold

Two things had to change before §8.5's destroyed and attack states could exist at all.

**1. A destroyed actor was gone before it could be drawn.** `GameState.destroy_entity` erases an
entity from `entities_by_id` in the same frame its hp hits zero, so a destroyed actor never appears
in a feed snapshot — it simply vanishes mid-board. §8.5 locks a 2–4 frame power-down that had, by
construction, nothing on screen to play on. Story 006 flagged this as owed (see
`EntitySpriteCatalog.STATE_DESTROYED`: *"nothing puts it on screen until S5-06 adds the death-echo
hold"*), and this story is that hold: `EntitySpriteFeed.power_down` marks the id dying, which
exempts its node from `_free_departed` and from `pick_regions`, and the node is freed when the beat
ends. **The 20+ destroyed PNGs shipped by S4-02 had never once been drawn until this story.**

**2. Combat announced deaths but not hits.** Story 007 recorded that the attack flare had to be
derived from a `has_attacked` edge because *"no event carries an attacker id — ADR-0004's schema has
no attack event at all, and adding one is a core-layer change well outside this story."* The lunge
and the recoil need exactly that pairing, and re-deriving it from an hp diff is the structural-diff
anti-pattern ADR-0004 forbids. So `DamageEvent` is built here — the event ADR-0004's own planned-event
table named (`damage_event.gd (Combat): target_id, amount, is_crit`) and that was never
implemented. Recorded deviations from that sketch: `is_crit` is **dropped** (there is no crit system
in `Combat`, and a permanently-false field is dead weight) and `attacker_id` is **added** (it is the
half the renderer cannot get anywhere else).

**Ordering is load-bearing** and is documented at `vertical_slice_root._on_action_applied`: deaths
are dispatched *before* the sync (or the node is already gone), motion *after* it (or the lean is
measured from the old tile).

**Both flare paths are kept.** The event path is the only one that catches a **counterattack** — a
counter is free and never sets `has_attacked`, so Story 007's state-derived detector is blind to it.
The state path is the only one that survives a board rebuilt from state with no events to replay.
They agree on every ordinary attack and the call is idempotent within a frame.

## Out of Scope

- **Multi-frame animation.** No move/attack/hit sheets exist; if playtest ever wants real frames,
  that is an art-production story, not this one.
- **Structure `damaged` tier** (→ S5-10). This story cross-fades idle→destroyed; the mid tier does
  not exist yet for any structure.
- **Retuning the flare decay.** `FLARE_DECAY_SEC` was left unpinned by Story 007 specifically so it
  could be tuned *with* this lunge. Both are feel values for the S5-03 / S5-07 sessions to judge.

## QA Test Cases

**Test files**:
- `tests/unit/combat/damage_event_test.gd` — Logic, **blocking**
- `tests/unit/board-renderer/entity_transforms_test.gd` — Logic, **blocking**
- `tests/integration/board-renderer/entity_death_echo_test.gd` — Integration, **blocking**

Covered:
- a survived hit emits one `DamageEvent` naming attacker, target and amount (the case that produced
  no events at all before this story)
- a lethal hit's `DamageEvent` precedes the destruction event it causes (ADR-0004 ordering)
- a counterattack emits a second `DamageEvent` with the roles swapped (AC-7)
- a structure defender is named like any other target; overkill reports damage dealt, not hp delta
- `lean_angle` sign follows screen-x and purely vertical travel does not lean
- `nudge` direction, magnitude-independent-of-separation, reversibility, coincident-zero
- §8.5 value relationships: recoil < lunge, strike faster than return, death beat inside the locked
  0.2–0.4s window
- a `power_down`'d id survives the sync that drops it, where an ordinary departure does not (AC-5)
- a dying actor is excluded from `pick_regions` (AC-6)
- the destroyed *art* is what fades in — a child sprite carrying the `*_destroyed_01` texture,
  transparent at start, bottom-centre anchored (**closes Story 006 AC-10**)
- the beat ends leaving no node, no dying mark and no orphan
- an id recycled mid-beat rebuilds clean rather than inheriting the corpse's fade

**Edge cases**: killing blow → power-down wins over the recoil it would otherwise trigger · actor
with no destroyed art → fades out rather than cutting · coincident attacker/target → no nudge
rather than a guessed direction · move with no horizontal component → no lean rather than a
tie-break flicker.

*Not automatable: whether the motion **reads** on screen — AC-1/2/3/4's feel half. That is S5-07
windowed evidence.*

## Test Evidence

**Automated** — 22 new tests across the three files, all passing. Full suite **936/936, 0 failures,
0 orphans** (was 914/914 before this story). Slice scene boots clean, exit 0.

**Windowed** — owed under **S5-07**, which is the sprint's Visual/Feel sign-off pass and needs a
windowed session the headless dummy rasteriser cannot provide. The specific checks the QA plan
already lists for this story:
- move lean / attack lunge / hit recoil read as intended and survive repetition
- destroyed cross-fade reads as a power-down, not an explosion (§8.5 "no gibs")

## Dependencies

- **Blocked by**: S5-02 (the glow the lunge syncs to, and the `pulse_base` the death beat drives)
- **Blocks**: nothing on the critical path. Feeds S5-03 (the legibility gate now judges a board with
  motion) and S5-07 (its windowed sign-off).

## Completion Notes

**All 8 acceptance criteria met**, with the feel half of 1–4 owed to S5-07's windowed pass.

### Shipped
- `src/core/event/damage_event.gd` — the event ADR-0004 named and never built.
- `src/core/combat/combat.gd` — emits it for the primary hit and the counter, each before any death
  it causes.
- `src/ui/board_renderer/entity_transforms.gd` — the single source of truth for the motion numbers,
  the way `entity_glow.gd` is for the glow numbers. Every value is a feel value; retune from the
  sessions, not from taste.
- `src/ui/board_renderer/entity_sprite_feed.gd` — `lean` / `lunge` / `recoil` / `power_down` /
  `is_dying`, the composed-offset position rule, and the death-echo lifetime.
- `src/game/vertical_slice_root.gd` — the ordered event dispatch.

### Follow-up worth scheduling after the gate
`FLARE_DECAY_SEC` (0.45, Story 007) and every constant in `entity_transforms.gd` are unpinned feel
values that should be tuned **together** — the flare and the lunge are one beat, and tuning either
alone is guesswork. Best done off the S5-07 recording rather than in isolation.
