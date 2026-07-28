# Gate Check: Pre-Production → Production

**Date**: 2026-07-26
**Checked by**: gate-check skill
**Review mode**: lean (full director panel)
**Verdict**: **CONCERNS — do not advance the stage yet**
**Stage after gate**: `Pre-Production` (unchanged — not a PASS)

---

## Summary

The Foundation milestone is complete and high-quality: Sprint 1 delivered all 7 Must-Have Foundation stories (GameState core, apply_action pipeline, Turn FSM, win-check, full AP economy), 177/177 headless tests, smoke PASS, QA sign-off APPROVED, zero bugs, and all 18 ADRs Accepted. But the **Pre-Production → Production** gate asks whether the project is ready to commit the full team to feature development against a planned backlog with fun validated — and two defining prerequisites are absent: a **Core-layer backlog** (epics/stories) and a **validated Vertical Slice**. This is a sequencing gap of days-to-weeks, not a health or architecture problem.

---

## Required Artifacts: ~9/13 present

| Artifact | Status |
|----------|--------|
| First sprint plan | ✅ `production/sprints/sprint-1.md` |
| Master architecture doc | ✅ `docs/architecture/architecture.md` |
| ≥3 Foundation ADRs, all Accepted | ✅ 18 ADRs, **all Accepted** |
| Control manifest | ✅ `docs/architecture/control-manifest.md` |
| All MVP-tier GDDs complete | ✅ 12 VS-tier systems, all Approved |
| Traceability index | ✅ `docs/architecture/traceability-index.md` (200 TRs, zero orphans) |
| Accessibility requirements + interaction patterns | ✅ both present |
| Art bible (9 sections) | ⚠️ 9 sections present, **AD-ART-BIBLE sign-off not recorded** (skipped, lean mode) |
| Foundation **AND Core** layer epics | ❌ Only Foundation epics (grid, game-state, ap-economy). 9 Core systems have Accepted ADRs but **zero epics/stories** |
| UX specs — main menu / core HUD / pause | ❌ Only `design/ux/interaction-patterns.md`; no `design/ux/hud.md` or screen specs |
| Vertical Slice build + REPORT + playtest | ❌ Only per-ADR technical spikes; `production/playtests/` absent |
| Entity inventory | ❌ absent (recommended) |

## Quality Checks: partial

- ✅ All ADRs Accepted; sprint references real story paths; accessibility tier defined; Foundation traceability complete; **Foundation proven** (177/177, QA APPROVED)
- ❌ Core-loop fun validated by the **concept prototype only** (verdict PROCEED), not a Vertical Slice
- ❌ Two of four pillars — **faction asymmetry** and **board readability** — remain unvalidated by play; no visual/rendering/input surface exists yet
- ❌ Core-layer work unplanned; UX screen specs absent

---

## Director Panel Assessment

**Creative Director: CONCERNS** — Design foundation is vision-sound and the core loop's soul is validated by the concept prototype. But two of four pillars are unplayed: Pillar 4 (faction asymmetry — the concept doc names a required follow-up asymmetry prototype that hasn't happened) and Pillar 3 (board readability — the isometric legibility playtest is a "hard gate" and there is no board to look at). The closeout-drag endgame risk is also unvalidated. Build and playtest the vertical slice the design docs already prescribe before committing to Production.

**Technical Director: CONCERNS** — Architecture is complete and coherent (18 ADRs Accepted, clean acyclic layering, both HIGH-risk engine unknowns retired), and Foundation is proven not just designed. Advancing the stage is architecturally appropriate, but with named gate-exit conditions: (1) resolve the unguarded per-player-index read-surface ruling **now**, before 9 Core epics build on it; (2) sequence the QQ-05/QQ-06 perf spikes ahead of committing the movement (ADR-0009) and AI (ADR-0011) epics; (3) treat the first Presentation epic as a de-risking vertical slice for the custom iso projection (capability-verified ≠ implementation-verified).

**Producer: CONCERNS (leaning NOT READY to flip)** — "Production" is a commitment to full-team development against a planned backlog with fun proven. Two of three readiness prerequisites are absent: no Core backlog (9 systems, zero epics/stories/estimates) and no fun-validation (no VS, no playtest). Advancing now inverts the dependency (first Production sprint would open with "what do we build?"). Recommended sequence: break Core into epics/stories → build + playtest a Vertical Slice (the true gate) → then flip. UX specs, AD sign-off, entity inventory proceed in parallel (non-blocking).

**Art Director: CONCERNS** — Art bible has all 9 sections and is substantive (forward-specs even the deferred vehicle/mech tier), but three art-side artifacts must close before asset production ramps: record the AD-ART-BIBLE sign-off verdict, create the entity inventory (`design/assets/entity-inventory.md`), and produce a HUD layout spec (`design/ux/hud.md`). No visual work has begun (headless core only).

**Panel outcome**: Unanimous CONCERNS. No director cleared it; none flagged a defect — every concern is planning or validation, not health.

---

## Blockers to a clean PASS (minimal path)

1. **Break the 9 Core systems into epics + stories** — `/create-epics layer:core` then `/create-stories [epic]`. Priority: the vertical-slice systems (movement → command-interface → combat → HUD → minimal AI).
2. **Build + playtest a Vertical Slice** — one playable turn of tactical combat, rendered on the board, with the isometric-legibility and swing-back playtests the concept doc mandates. Log in `production/playtests/`. **This is the true Pre-Prod → Production gate.**
3. **Resolve the per-player-index guard ruling** (TD gate-exit condition) — one ADR addendum or control-manifest guardrail — before Core epics build on the Foundation read surface.
4. **Sequence QQ-05/QQ-06 perf spikes** ahead of the movement (ADR-0009) and AI (ADR-0011) epics.
5. **Parallel, non-blocking**: UX specs for main menu / core HUD / pause; record AD-ART-BIBLE sign-off; start the entity inventory.

---

## Chain-of-Verification

5 challenge questions checked; 3 re-verified via tools:
- [TOOL] Core-layer epics absent — confirmed: `production/epics/` holds only grid-terrain, game-state-turn-manager, ap-economy; index lists no Core-layer epic.
- [TOOL] Vertical slice + playtests absent — confirmed: `production/playtests/` does not exist; `prototypes/` holds only per-ADR spikes, no vertical-slice REPORT.
- [TOOL] UX screen specs absent — confirmed: only `design/ux/interaction-patterns.md`; no hud/menu/pause specs.
- Verdict softening check: the skill's own rule ("Vertical Slice not built → downgrade to CONCERNS, not FAIL") and the unanimous director CONCERNS (none NOT READY) place the floor at CONCERNS, not FAIL — not a softened FAIL.
- Compounding check: the gaps are pre-conditions, so the verdict is explicitly "do not advance yet," not "advance and fix later."

**Verdict unchanged: CONCERNS.**

---

## Recommended Next Steps

Stay in Pre-Production and execute the vertical-slice loop the design already prescribes:

1. **Sprint 2 (Pre-Production planning)**: Core epic/story breakdown (`/create-epics layer:core`, `/create-stories`) + vertical-slice scoping + the TD's index-guard ruling.
2. **Sprint 3 (+4 if needed)**: Vertical Slice build + first playtest → `/playtest-report`.
3. **Re-run `/gate-check`** once the VS is built and playtested — expected to PASS and flip the stage to Production.
