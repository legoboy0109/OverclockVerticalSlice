# Change Impact — `command-action-interface.md` CR-4, structural vs. situational

| | |
|---|---|
| **Date** | 2026-08-26 |
| **Trigger** | S8-10 playtest fix, implemented and recorded in `design/ux/action-menu.md`; GDD had not caught up |
| **Skill** | `/propagate-design-change` (lean mode — `TD-CHANGE-IMPACT` gate skipped per review mode) |
| **ADRs affected** | **0** of 18 |
| **TRs affected** | **0** of 24 `TR-cmdui-*` (200 total) |
| **Verdict** | **COMPLETE** — GDD clarified; no architectural decision moved |

## ⚠ This ran backwards, and that is the finding

`/propagate-design-change` normally diffs a revised GDD against its committed version and asks what
broke downstream. **The GDD had not been touched** — `command-action-interface.md`'s last commit is
`69e05fe` (S6-09, the naming sweep). The decision moved in the UX spec and in the code, and the GDD
was the thing lagging. This pass therefore ran with the implementation as the source of truth,
checking what upstream needed to catch up.

That inversion is itself worth recording: **a design decision reached during implementation can sit
correctly in a UX spec, correctly in code, correctly under test, and still leave the GDD stating
something else.** Nothing in the pipeline notices, because no TR encoded the rule.

## ★ CR-4 was far less "narrowed" than the S8-10 note claimed

The S8-10 session note says the change *"narrows CR-4"*. Read strictly, CR-4 already gated
structurally and the implementation never contradicted it:

- **Produce** — *"(producers only, …)"*
- **Cancel Build** — *"(under-construction structures only)"*
- and the disabled-not-hidden clause is scoped to *"a verb the entity **has** but cannot use right
  now"* — a non-producer does not *have* Produce.

What CR-4 never did was **state the rule**. It gated structurally in passing parentheticals and then
made a loud, universal-sounding promise about disabled rows. That gap is precisely how a dead
*"Produce — not a producer"* row shipped on every ordinary unit and survived a full art sprint plus
two spec reviews — until someone played the game.

⇒ The correct action was a **clarification promoting an implied rule to an explicit one**, not a
reversal of design intent. Recorded here because performing the larger change the note implied
would have been the easier and wronger move.

## Impact analysis

### ADR-0015 — Command & Action Interface FSM — ✅ **Still Valid**

**What the ADR specifies:**
> `## PURE: the CR-4 contextual menu for a selected entity — the list of {verb, enabled, reason}.`
> `static func menu_model(state: GameState, entity: EntityState) -> Array[VerbEntry]`

**What the implementation does:** `menu_model` still returns an entry — with its `Reason` — for
**every** verb, including structurally inapplicable ones. The filter lives in the *view*
(`ActionMenu._is_inapplicable`, `src/ui/command_action_interface/action_menu.gd:624`, applied at
`:498`).

**Assessment:** the ADR's contract is untouched, and the split is architecturally correct rather
than incidental. The model still knows Produce is inapplicable **and why**, so tests, the AI and any
future consumer still see the full picture; only presentation drops the row. Had the filter been
pushed into `menu_model`, this ADR *would* have needed revising and the model would have lost
information it is the model's job to hold.

★ Pinned from both sides: `command_fsm_test.gd:708` asserts `menu_model` still reports
`NOT_A_PRODUCER`; `action_menu_test.gd:312` asserts the row does not render.

**Action: keep as-is.**

### ADR-0016 — Game HUD — ✅ **Still Valid**

**What the ADR specifies** (TR-hud-015, lines 408 and 589): the Build button is *"dimmed, never
hidden, when no type is affordable on both pools."*

**Assessment:** affordability is **situational** by definition — the player can bank Credits or free
up AP. The clarified rule **confirms** this requirement rather than contradicting it. A superficial
read of "structural verbs are now hidden" would flag `"dimmed, never hidden"` as a conflict; it is
not one, and the distinction is exactly what the clarification exists to make legible.

**Action: keep as-is.**

### ADR-0013, ADR-0014 — ✅ Not affected

Both reference `command-action-interface.md` for iso hit-testing and focus architecture. Neither has
any CR-4 dependency.

### TR registry — 0 of 24 affected

All 24 `TR-cmdui-*` requirements were read. They encode the FSM, the four query tiers, the
Pass-Through Invariant, iso overlay re-derivation, cursor/focus, and input gating. **None encodes
the disabled-vs-hidden rule.** It existed only as GDD prose.

⚠ **That is the root cause of the whole episode.** A rule with no TR has nothing to trace, nothing to
review against, and nothing to fail. It is not proposed as a new TR here — it is a presentation rule
with no architectural consequence, and the registry is a map of decisions that constrain code, not
of everything a GDD says. But the failure mode is worth naming: **the rules most likely to rot
quietly are the ones no artifact downstream depends on.**

## Resolution

| Document | Action |
|---|---|
| `design/gdd/command-action-interface.md` | ✅ CR-4 clarified — the structural/situational rule stated explicitly, with the Disband exception named. New **AC-9b** covers both branches |
| `design/ux/action-menu.md` | No change — already correct; it is where the decision was recorded |
| ADR-0015, ADR-0016, ADR-0013, ADR-0014 | No change — all Still Valid |
| `tr-registry.yaml` | **TR-cmdui-021** `revised: 2026-08-26` — its residual at-impl dual-focus check was closed the same day by S8-09. Unrelated to CR-4; folded in because this pass read all 24 `TR-cmdui-*` entries and found it still open. ⚠ **TR-hud-022 deliberately NOT stamped**: it requires HUD controls to carry a distinct focus/hover StyleBox, and S8-09 measured **action-menu rows**, not HUD controls. The theme-level fact is shared (focus and hover resolve to different StyleBox resources), but the rows are `flat = true`, which suppresses the hover box — whether HUD controls are flat was not checked, so the requirement is not evidenced |
| `traceability-index.md` | Superseded Requirements section annotated — no TR superseded, and the reason recorded |

### ⛔ The Disband exception — user decision, 2026-08-26

`Disband` is hidden on `NOTHING_BLOCKED`, a **situational** reason the rule would otherwise keep.
The user chose to **name it as a stated exception** rather than log it as a defect (which would
re-create the dead-row problem the playtest had just fixed) or widen the rule to fit it (which would
also license hiding "no targets in range").

The exception carries its cost in the GDD text: a player with nothing blocked never learns Disband
exists, and first meets it in a turn where something has already gone wrong. `unit-upkeep.md`'s
`Upkeep.validate_disband` still *accepts* a disband from a player with nothing blocked — this hides
an affordance, it does not forbid an action, and a test pins that distinction so a UI-level gate can
never harden into a rule.

## Follow-up

**None required.** No ADR was marked Superseded, so no replacement ADR is owed and
`/architecture-review` does not need re-running — the traceability matrix is unchanged at 200/200.
