# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-07-25
**Checked by**: gate-check skill
**Review mode**: lean (all four PHASE-GATE directors run)
**Verdict**: **CONCERNS** (advisory — no director returned NOT READY)

---

## Required Artifacts: 12/13 present

- [x] Engine chosen — Redot 26.2 (Godot 4.6-compatible) in CLAUDE.md; not `[CHOOSE]`.
- [x] Technical preferences configured — `.claude/docs/technical-preferences.md` populated (naming conventions, performance budgets, engine specialists).
- [x] Art bible — `design/art/art-bible.md`, all 9 sections complete.
- [x] ≥3 ADRs covering Foundation-layer systems — 18 ADRs (`adr-0001`…`adr-0018`), 8 Foundation.
- [x] Engine reference docs — `docs/engine-reference/godot/` (VERSION, breaking-changes, deprecated-apis, best-practices, modules).
- [x] Test framework directories — `tests/unit/`, `tests/integration/` exist.
- [x] CI/CD test workflow — `.github/workflows/tests.yml` (GdUnit4 action, Godot 4.6 stand-in).
- [ ] **At least one example test file — MISSING.** `tests/unit/` and `tests/integration/` hold only `.gdignore_placeholder`. **GdUnit4 addon not installed** and **no `project.godot` exists**, so the runner/CI cannot execute. This is the one genuinely-absent required artifact.
- [x] Master architecture document — `docs/architecture/architecture.md`.
- [~] Architecture traceability index — present as `docs/architecture/traceability-index.md` (gate text names `requirements-traceability.md`; the `/architecture-review` skill produces `traceability-index.md`). Content satisfies intent; **filename divergence only, not a blocker.**
- [x] `/architecture-review` has been run — three reports; latest `architecture-review-2026-07-25.md` verdict **PASS** (200/200 covered, 0 gaps).
- [x] `design/accessibility-requirements.md` — Standard tier committed.
- [x] `design/ux/interaction-patterns.md` — 14-pattern library, `/ux-review` APPROVED.

## Quality Checks: strong, with two soft gaps

- [x] Architecture covers core systems — rendering (ADR-0013), input (ADR-0014), state management (ADR-0001).
- [x] Technical preferences have naming conventions and performance budgets set.
- [x] Accessibility tier defined and documented (Standard).
- [~] **At least one screen's UX spec started** — only the interaction-pattern library exists; no screen-level `ux-spec` or `design/ux/hud.md`. Advisory at this gate (HUD screen spec is a Pre-Production→Production requirement).
- [x] All 18 ADRs carry Engine Compatibility sections stamped with the engine version.
- [x] All ADRs have GDD Requirements Addressed linkage (200/200 traced).
- [x] No ADR references deprecated APIs (per `/architecture-review` engine audit).
- [x] All HIGH-RISK engine domains addressed — ADR-0013 iso rendering (bans `local_to_map` per GH#89423), ADR-0014 dual-focus input; both carry pre-Accept engine spikes.
- [x] Traceability matrix has zero Foundation-layer gaps (200/200 covered).
- [x] ADR dependency graph acyclic (linear 0001→0018); no circular dependency.
- [x] All ADRs agree on the same engine version (Redot 26.2 / Godot 4.6).
- [~] **Corpus coherence debt** — `design/gdd/game-concept.md` (lines 10/107/232) and `design/gdd/systems-index.md` still say "top-down" while the art bible commits to isometric. `/propagate-design-change` was run for the **architecture** side (`docs/architecture/change-impact-2026-07-23-isometric-projection.md`) but not the design docs.

## Director Panel Assessment

| Director | Verdict | Summary |
|---|---|---|
| Creative Director | **CONCERNS** | Vision disciplined and coherent (12 Player Fantasy sections converge; anti-pillar audit clean). But the isometric shift is un-reconciled with the concept + GDD corpus, and Pillar 3 "readable board" was validated against top-down geometry, never re-validated against iso. D-2/D-3 stances now owe a playtest, not just reframed prose. |
| Technical Director | **CONCERNS** | Blueprint strong enough to build against; all-ADRs-Proposed is expected here. Conditions: front-load ADR-0013/0014 engine spikes + QQ-05/06 perf spikes as the slice's first tasks; the non-functional test harness must land before the first slice story (coding standards mandate test-first; CI is a blocking gate). |
| Producer | **CONCERNS** | Org and sequencing sound (fun-validation correctly precedes epic/story machinery). Make "spikes resolved + example test green + fun validated" the explicit exit criteria for the slice, gating `/create-epics`. All 18 ADRs Proposed → checkpoint their Accept before `/create-stories`. |
| Art Director | **READY** | Art bible complete and unambiguous; Non-Hue Semantic Layer resolves the earlier colorblind gap; known gaps (entity inventory, concept art) correctly Production-stage; slice can run on placeholder art without thrash. |

Escalation: three CONCERNS → overall verdict minimum CONCERNS. No director returned NOT READY.

## Blockers / Conditions to close before the first slice story

1. **Unproven test framework** — no `project.godot`, no `addons/gdUnit4/`, no example test. Initialize the Redot project + install GdUnit4 + commit one passing example test proving runner + CI go green. Hours-scale; unanimous director read is "first-slice task, not a redesign."
2. **Four unrun spikes** — ADR-0014 dual-focus, ADR-0013 iso picking, QQ-05 `reachable()`, QQ-06 AI loop. Sequence as the slice's first tasks with Accept/pivot decision points; gate `/create-epics` on resolution.
3. **Reconcile isometric across the corpus** — run the design-doc side of `/propagate-design-change` (concept + systems-index), and treat board legibility under iso as a hard slice playtest gate.

## Chain-of-Verification

5 questions checked — 2 tool-backed: confirmed zero `*_test.gd` files + GdUnit4 addon absent + no `project.godot` (Glob/ls); confirmed "top-down" persists in `game-concept.md` + `systems-index.md` while the art bible commits isometric (grep). Tested whether the missing test artifact should elevate to FAIL — rejected: it is hours-scale, is the first slice task per unanimous director read, and does not block the Pre-Production sequence. No FAIL condition softened. **Verdict unchanged (CONCERNS).**

## Verdict: CONCERNS

Every required design/architecture artifact is present and passing. Verdict is CONCERNS (not PASS) because three directors returned CONCERNS and one required artifact (example test file) is absent — but all four directors said proceed, and the gap is closeable at the very start of Pre-Production. Note: all 18 ADRs remaining `Proposed` is **not** counted against this gate (Accepted-status is a Pre-Production→Production requirement).

`production/stage.txt` NOT advanced pending closure of the test-harness gap (user chose to close it first).

## Next Steps (Pre-Production)

1. **Close the test-harness gap** (user-selected next action): initialize `project.godot`, vendor GdUnit4, fix `tests/gdunit4_runner.gd`, add one passing example test, prove green.
2. `/create-control-manifest` — extract layer rules from ADRs (required before epics).
3. `/vertical-slice` — build FIRST; scope its first tasks as the four open spikes; exit criteria = spikes resolved + test green + fun & legibility validated by playtest.
4. `/propagate-design-change` (design side) — reconcile the isometric decision into concept + systems-index.
5. `/ux-design` screens (main menu, core HUD) → then `/create-epics` layer:foundation / layer:core → `/create-stories` → `/sprint-plan`.

---

## Post-Gate Update — 2026-07-25: test-harness blocker RESOLVED

The one missing *required artifact* (example test file / functional framework) is closed and proven green. Changeset (user-approved "vendor + prove green"):

- **`project.godot`** created — initializes the Redot 4.6 project (Forward+), enables the GdUnit4 plugin. (Repo had no `project.godot` before; the framework literally could not run.)
- **`addons/gdUnit4/`** — GdUnit4 **v6.1.3** vendored (264 files), Godot-4.6-compatible, downloaded from `godot-gdunit-labs/gdUnit4` (repo moved from `MikeSchulze`).
- **`tests/gdunit4_runner.gd`** rewritten — the prior version referenced a non-existent `addons/gdunit4/GdUnitRunner.gd`. Now delegates to GdUnit4's shipped CI runner, defaults to scanning `tests/unit/` + `tests/integration/`, and passes `--ignoreHeadlessMode` (required — GdUnit4 blocks headless by default). Fixed two integration bugs found by running it: engine flags must be excluded from the parser's arg list, and the parser discards tokens until one contains the tool name (needs a sentinel program-name token).
- **`tests/unit/framework_smoke_test.gd`** — one example suite, 3 tests, implementation-free (no `src/` exists yet), demonstrating the arrange/act/assert + integer-determinism conventions.
- **`.gitignore`** — added `reports/` (GdUnit4 generated output; `.godot/` already ignored).

**Proof (verification-driven):**
- Green: `./redot --headless --script tests/gdunit4_runner.gd` → `Executed test cases: (3/3)`, all PASSED, **exit code 0**.
- Red: a temporary failing assertion → **exit code 100** (non-zero) — confirms CI actually blocks on failure. Temp test removed.

**Verdict impact:** the single absent required artifact is now present and functional. Remaining CONCERNS are Pre-Production activities (four engine/perf spikes, all-18-ADRs-Proposed Accept checkpoint).

**Isometric corpus reconciliation — DONE (2026-07-25):** `/propagate-design-change` (design side) applied — `game-concept.md` + `systems-index.md` now self-describe "2D isometric", carry projection notes, and Pillar 3 now makes the vertical-slice legibility playtest a hard gate (closes the CD concern). Advance Wars competitor line kept (accurately top-down).

**Stage advanced → Pre-Production (2026-07-25)** on user approval, both pre-advance items closed. `production/stage.txt` = `Pre-Production`. Next: `/create-control-manifest` → `/vertical-slice` (front-load the four spikes as first tasks).
