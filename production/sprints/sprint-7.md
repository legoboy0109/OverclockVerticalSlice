# Sprint 7 — 2026-08-25 to 2026-09-08 (Harden what exists)

## Sprint Goal

**Make the thing that has never been built, build — and make the defects that only appear
there impossible to reintroduce.** No new mechanics, no new content, no design calls.

> ★ **Written after S7-01…S7-04 had already shipped**, which is deliberate rather than sloppy:
> Sprint 6's retro action #1 says *re-plan rather than silently extend*, and the export work
> found two ship-blocking defects within its first hour. This plan records what was found and
> scopes what is left, instead of letting the sprint run unplanned the way Sprint 6 did.

## Context — why this sprint exists

Sprint 6's retrospective produced eight action items. Three of them pointed at the same hole:

- **#4** grep for production symbols whose only definition lives under `tests/`
- **#5** run an export build — *nothing in six sprints ever has*
- **#7** fix or retire the two smoke checks that can only ever return "not measured"

★ **Item #5 was the load-bearing one, and it was the cheapest.** The project had no
`export_presets.cfg` at all, so there was nothing to be wrong — which is exactly why six
sprints passed without noticing that **the game could not be packaged.**

## ⛔ What the first export found

Two defects, both fatal, both invisible to a 1,233-test green suite.

### S7-01 — `Research` was declared under `tests/`

`class_name Research` lived in `tests/helpers/stubs/research_stub.gd` while production called it
in three places, one of them **unconditionally on every turn of every match**
(`GameState.start_turn` step 3), the other two being `Unit.effective_attack` and
`Unit.effective_defense` — the core combat path.

★ **The second instance of this exact defect in two days**, after `Structure` was found during
the Sprint 6 close-out. GDScript's `class_name` is project-global and the editor registers it
from anywhere, so both resolved in-editor and headless and neither ever failed a test.

### S7-02 — a parse-time cycle between an autoload and the Resource it loads

The first export did not boot:

```
SCRIPT ERROR: Parse Error: Could not resolve external class member "units".
          at: GDScript::reload (res://src/core/unit/unit_config.gd:40)
ERROR: Failed to load script "res://src/core/unit/unit_config.gd"
```

`UnitConfig.surcharge_for()` read `UnitBalance.units.soft_move_penalty_x10`, while the
`UnitBalance` autoload holds `var units: UnitConfig = preload(...unit_config.tres)`. GDScript must
resolve an autoload's script type to typecheck a member access on it, so **each needed the other
resolved first.**

★ The editor tolerates the cycle (populated global class cache, incremental re-parse). A packaged
build resolves each script once in dependency order, and a cycle has no valid order.
★ The five sibling configs never reference their autoloads — `unit_config.gd` was the sole
exception, so the fix was to make it match its siblings, not to invent a pattern.

> ### ★★ The shape both defects share, and the reason this sprint matters
> **Invisible in every build a developer runs; fatal in the build a player runs.** No behavioural
> test can see either — a green suite is not evidence against them. That is why S7-03's guards
> are structural rather than behavioural, and why they are verified by *re-introducing the defect*
> rather than by watching them pass.

## Tasks

### Done

| ID | Task | Est. | Result |
|----|------|-----:|--------|
| **S7-01** ✅ | Promote `Research` out of `tests/` into `src/core/research/` | 0.5 | Suite 1235/1235 after the move. Header rewritten to describe an honest forward declaration rather than a "test stub" |
| **S7-02** ✅ | Break the `UnitBalance`/`UnitConfig` parse cycle | 0.5 | `surcharge_for` moves onto the autoload; the pure injectable `surcharge_with_penalty` stays on the config, unchanged. One production caller updated |
| **S7-03** ✅ | `export_presets.cfg` + `tests/unit/export_safety_test.gd` | 1.0 | Two structural guards, both verified by re-introducing the defect. ★ Doing so caught a **false negative in my own guard** — see below |
| **S7-04** ✅ | Delete the pre-rename structure art duplicates; fix the pipeline that regenerates them | 0.5 | 14 PNGs + 14 sidecars, byte-identical twins verified by checksum. Pack **6.46 MB → 5.37 MB (−17%)** |

> ### ★★ The most instructive moment: a guard that could not fail
> S7-03's guard 1 first flagged `"Research complete"` — a **display string** in the action log,
> prose that happens to contain a class name. Blanking string literals fixed it and **silently
> broke guard 2**: blanking removed the `"res://..."` inside `preload()`, so the preload scan
> found nothing and the cycle check passed *with the cycle present.*
>
> ⇒ **A check that cannot fail is worse than no check** — it converts an open question into a
> false assurance. Caught only because each guard was tested by re-introducing the defect it
> exists to catch. **Verify a new test by watching it fail, never by watching it pass.**

### Remaining

| ID | Task | Owner | Est. | Notes |
|----|------|-------|-----:|-------|
| **S7-05** | **Full export, not just a pack** — download export templates (~1 GB), produce a runnable Linux binary, boot it | devops-engineer | 0.5 | ★ Everything so far is verified via `--export-pack` + `--main-pack`, which proves resource packaging and script resolution but **runs on the editor binary**. A template build is what proves the *shipping* binary works |
| **S7-06** | **Retire the dead economy read surface** — `completed_outpost_count()` has been dead product code since S6-01 (income no longer calls it, nothing in `src/` does); 6 tests still name it as their subject | gameplay-programmer | 0.5 | Deliberately not bundled into S6-03 so the gate-critical change stayed reviewable alone. Also: `MapDefinition.deploy_tiles` is `@export`ed, empty everywhere, and never consulted by `legal_deploy_tiles` |
| **S7-07** | **Independent `/ux-review` of the action menu** | ux-designer + accessibility-specialist | 1.0 | ⚠ The existing review was a **self-audit by the spec's own author**, and 4 of its 6 blocking findings were *the spec describing something the build does not do* — the class an author reliably misses. Needs genuinely separate eyes to be worth more than the first pass |
| **S7-08** | **Fix or retire smoke checks 16/17** (performance) | technical-director | 0.5 | ⛔ **Blocked on a direction call**: `technical-preferences.md` still reads `[TO BE CONFIGURED]` for the memory ceiling, and no target hardware is named. A check that can only ever return "not measured" is noise in the gate — but choosing the target is the user's call, not a technical one |

## ★ Explicitly NOT in this sprint

| Item | Why not |
|---|---|
| **The one-unit cliff** | ★ The most important open question on the project, and a **design call that is the user's**. It shapes what wave 2 is *for*. Not a hardening item |
| **S5-03's naive-observer session · S5-04's Analyses A/C/D** | Need a human at a display. ★ **Analysis D is the two-budget pivot's core hypothesis** and has never been tested |
| **Any wave-2 content** | Blocked behind the cliff question by the retro's own reasoning: the game does not lack decisions, it lacks a recoverable middle, and more unit variety will not create one |

## Definition of Done

- [x] ✅ An export preset exists and the project packages
- [x] ✅ The packaged build boots — main menu **and** the full match scene, exit 0, zero errors
- [x] ✅ Both export-only defect classes have a structural guard, each verified by re-introducing the defect
- [x] ✅ Full suite green — **1236/1236, 107 suites, 0 orphans**
- [ ] A runnable exported **binary** (not just a `.pck`) boots — S7-05
- [ ] No unplanned work absorbed without a recorded trade — ★ the rule Sprint 6 broke; this file existing at all is the fix

## Risks

| Risk | P | Impact | Mitigation |
|---|---|---|---|
| ★ **More export-only defects behind the two already found** | Medium | High | The two guards cover the two known classes, not the category. S7-05's real binary is the next-cheapest net |
| **Export templates are a ~1 GB download that may not match Redot 26.2** | Medium | Medium | Redot is a Godot hard-fork with its own template releases; if the fetch fails, the `--main-pack` verification already covers script resolution and packaging, and the gap is narrow and stated |
| **Hardening crowds out the cliff decision** | Low | ★ High | This sprint is deliberately small. **The cliff is the project's most valuable open question and none of this touches it** |
