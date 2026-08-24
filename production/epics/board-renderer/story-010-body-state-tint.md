# Story 010: Body State Tint — Making Spent and Destroyed Actually Read

> **Epic**: Board Renderer
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Visual/Feel *(secondary: Logic — the tint mapping and the palette floor are automatable and are covered as blocking gates)*
> **Estimate**: S (0.5 day)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-08-21 (implemented)

## Context

**GDD**: `design/art/art-bible.md` §2.6 (AP-spent state), §8.5 (destroyed beat), §3.5/P3
(units are lighter than the stage), §1 (identifiable by outline alone)
**Requirement**: the two findings from the **S5-07 windowed pass** —
`production/qa/evidence/s5-07-windowed/README.md`
**Origin**: not planned. Surfaced by S5-07's captures, then authorised by the user as a
mid-sprint fix. The trade against the design freeze is recorded in `sprint-5.md`.

**Engine**: Redot 26.2 | **Risk**: LOW — one `self_modulate` write per actor. No shader,
no new material, no batching impact.

## The problem this fixes

S5-07 rendered the real presentation stack and measured two states that did not read:

- **Pillar 1 — "can this actor still act?"** AP-available vs AP-spent measured
  **12.5/255** on the neon trim at the breathe *peak* and **3.3/255** at the *trough*,
  across **0.67% of the frame**. Since breathe cycles every 3 seconds, whether a player
  could tell a spent unit from a live one depended on *when they happened to look*.
- **§8.5's destroyed "power-down"** dimmed the actor by **8.9/255 — 3.5%**. The
  cross-fade worked; the shutdown did not read.

**One root cause.** The emission shader only ever *adds* light on top of already-bright
accent art. Ceasing to emit cannot make an actor look spent or dead while its base
sprite stays fully painted, so the entire available signal was the emission range —
small, and confined to a thin rim. `BREATHE_MIN`, `SPENT_CLAMP` and `FLARE_DECAY_SEC`
could all be retuned without moving that ceiling.

## Acceptance Criteria

1. **The actor's body multiplies down when it can no longer act**, and back up when it
   can — the signal lives on the whole silhouette, not on a 2% rim.
2. **A destroyed actor darkens over the beat**, ending clearly below the spent level.
   The wreck fades in already dark, never at live brightness even for a frame.
3. **★ The spent tint never breaks §3.5/P3.** A dimmed unit stays clearly lighter than
   the *brightest* stage tile, so §1's identifiable-by-outline-alone rule holds.
4. **Ownership does not dim with the actor** — faction hue and the ownership decal stay
   readable in every state.
5. **The glow keeps its own state role**; the body tint supplements it, never replaces it.
6. **Alpha is preserved** — the death-echo cross-fade and the state tint share
   `self_modulate` and must not clobber one another.
7. Applied to every actor, including those with no authored emission mask.

## Implementation Notes

- **`self_modulate`, never `modulate`.** `modulate` is inherited by children, so it would
  drag the glow overlay and the wreck down with the body. The glow already carries its
  own state via `pulse_base`; dimming it twice would double-count.
- **RGB and alpha are separate channels with separate owners.** RGB is the state tint,
  alpha is the death cross-fade. `_set_body_tint` preserves alpha explicitly rather than
  assigning a whole `Color`, because assigning one resets whichever channel the caller
  was not thinking about.
- **Applied in `_refresh_entity`, not `_refresh_glow`.** The latter early-returns for any
  actor with no authored mask, and is additionally gated behind an unchanged-state check
  (AC-6 of Story 007). Either would have silently skipped the tint.
- **A no-op while dying**: `power_down` owns the tint from that point and is tweening it,
  so an ordinary sync must not stamp over it.
- **Snapped, not tweened, for the spent transition.** It coincides with an action commit,
  which already carries the attack flare and the §8.5 motion; adding a third animation
  would fight the single-slot per-entity tween. Destroyed *is* tweened — that one is the
  beat.

## ★ Why 0.72 is a floor, not a preference

Art bible §3.5/P3 makes units deliberately **lighter than the stage**: armour `#6E7C99`
(luma 123) against a max-elevation tile `#33405A` (luma 63). Multiplying past ~0.72
collapses that margin below ~25 and units begin sinking into the terrain — which is
precisely the *"units vanish into the board"* defect the S4-02 art pass already had to
diagnose and fix once (it specced unit armour at the exact value of the plain terrain
tile).

`body_state_tint_test.gd` asserts this floor against the locked palette values, restated
in the test rather than imported, so the suite fails loudly if the palette moves under it
instead of quietly validating against a stale number.

`DESTROYED_BODY_TINT` (0.50) is deliberately below the floor: a destroyed actor is
leaving the board, and nothing downstream needs to pick its silhouette out of the terrain.

## Out of Scope

- **Desaturation.** Considered and rejected: removing chroma would degrade the faction-hue
  ownership read, which must survive every state (§1 P2). A grey multiply preserves hue.
- **Retuning `BREATHE_MIN` / `SPENT_CLAMP` / `FLARE_DECAY_SEC`.** Still unpinned feel
  values, and still best tuned together off a recording rather than in isolation.
- **The army-wide vs per-unit actionability question** — see below. That is a design call.

## QA Test Cases

**Test file**: `tests/unit/board-renderer/body_state_tint_test.gd` — Logic, **blocking**

Covered: the three states map to three distinct tints · a live actor is drawn as authored
· death outranks actionability (mirroring `mode_for`'s precedence) · **the spent tint
keeps a >20 luma margin above the brightest stage tile** · >30 above terrain base · the
spent change is >25 luma (not a token gesture that would reproduce the original defect) ·
destroyed may go darker than spent · no tint is ever 0 (a black silhouette reads as a hole
in the board, not an actor).

*Not automatable: whether it reads at playing distance. That is S5-03 / S5-07 sign-off.*

## Test Evidence

**Automated** — 8 new tests, all passing. Full suite **963/963, 0 failures, 0 orphans**
(was 955).

**Rendered and re-measured** in the real rasteriser (`s5-07-windowed/`):

| | before | after | |
|---|---:|---:|---|
| Pillar-1, breathe peak | 12.5/255 | **24.4/255** | on the actors, not a 2% rim |
| Pillar-1, breathe trough | 3.3/255 | **20.1/255** | **6.1×** |
| Pixels carrying the signal | 4,904 | **18,709** | 3.8× the area |
| Destroyed dimming | 8.9/255 (3.5%) | **40.2/255 (35%)** | 4.5× |

**The headline is not the peak number — it is that the signal stopped depending on
breathe phase.** It swung 12.5 → 3.3 across every cycle before; it is 24.4 → 20.1 now.

Verified visually as well: silhouettes still read against the terrain, faction hue still
reads, and the ownership decals stay at full brightness (they live on their own layer, so
ownership does not dim with the actor).

## Dependencies

- **Blocked by**: S5-07's captures (this story exists because of what they measured)
- **Blocks**: nothing. Feeds S5-03 and the S5-07 sign-off.

## Completion Notes

**All 7 acceptance criteria met**, with the "does it read at playing distance" half owed
to S5-03 / S5-07 sign-off like every other Visual/Feel item.

### ✅ The open question below was answered the same day — per-unit actionability
The user chose **per-unit**. Implemented in `VerticalSliceRoot._is_entity_actionable`
and covered by `tests/integration/vertical-slice/per_unit_actionability_test.gd`
(8 tests). Units dim by affordability (−30.7/255 measured); non-combat structures never
dim, even at 0 AP, so the board keeps its anchors. Original framing retained below.

### ★ This fix gave an old open question real teeth
Story 007 flagged that breathe-vs-clamp follows the **owning player's AP pool**
(spec-literal per §8.5/§2.6), dimming that player's whole army at once, versus **per-unit
actionability**, where a unit that has already acted dims while its squadmates stay live.
With the old 3–12/255 signal the choice barely mattered.

**It matters now.** At 20–24/255 across every actor, running a player out of AP visibly
darkens their entire army *and both structures* in one step — a dramatic whole-board
change at every end of turn. That may read as excellent turn-boundary feedback or as the
board going flat. One line either way (`EntitySpriteFeed.actionable_predicate`), and a
human call.

Worth deciding separately whether **structures** should dim at all: a structure is not
"spent" in the sense a unit is.
