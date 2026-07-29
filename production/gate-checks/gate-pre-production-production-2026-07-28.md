# Gate Check: Pre-Production → Production

**Date**: 2026-07-28
**Checked by**: `/gate-check` skill
**Review mode**: lean
**Current stage**: Pre-Production (unchanged — HOLD)
**Verdict**: **CONCERNS**

---

## Summary

The **build half** of the Pre-Production → Production gate is complete and green: a
playable, regression-hardened Vertical Slice with every design, architecture, and
planning artifact present and approved. The gap is the **validation half** — the
iso-legibility and swing-back playtests and the PROCEED/PIVOT/KILL REPORT verdict
have not run. These are the sanctioned Sprint-4 rollover (`production/vertical-slice/scope.md`
§9; `production/retrospectives/retro-sprint-3-2026-07-28.md`). Per the gate
definition these playtest items are "recommended, not blocking → surface as CONCERNS."

**Decision (user, 2026-07-28): HOLD in Pre-Production.** Run the playtests + write
the `/vertical-slice` REPORT verdict as the Sprint-4 opener, then re-gate.

---

## Required Artifacts — 11/13 present

| Status | Artifact |
|--------|----------|
| ✅ | Vertical Slice build exists **and is playable** — `scenes/vertical_slice.tscn`, confirmed end-to-end on a windowed build 2026-07-28 |
| ✅ | Sprint plans — `production/sprints/` (sprint-1/2/3) |
| ✅ | Art bible complete (9/9 sections) + **AD-ART-BIBLE ✅ APPROVE** recorded (2026-07-27) |
| ✅ | Entity inventory — `design/assets/entity-inventory.md` (150 lines) |
| ✅ | All MVP-tier GDDs complete; master architecture doc `docs/architecture/architecture.md` (462 lines) |
| ✅ | 18 ADRs in `docs/architecture/`, **all Accepted** (0 Proposed) |
| ✅ | Control manifest — `docs/architecture/control-manifest.md` (510 lines) |
| ✅ | Epics for all layers — `production/epics/` (12 epics: Foundation → Core → Feature) |
| ✅ | UX specs — main-menu, HUD, pause + interaction patterns (`design/ux/`); `/ux-review` APPROVED |
| ✅ | Test framework + CI (`.github/workflows/tests.yml`) + **smoke PASS** (826/826, `production/qa/smoke-2026-07-28.md`) |
| ❌ | **VS REPORT.md** with PROCEED/PIVOT/KILL verdict — MISSING (story S3-11, backlog) |
| ❌ | **Playtests** — `production/playtests/` empty; 0 documented sessions (stories S3-09/10, backlog) |
| ⚠️ | `docs/architecture/requirements-traceability.md` absent — traceability embedded in the architecture doc + QA plan; a Technical-Setup-tier item, not a Pre-Prod→Production blocker |

## Quality Checks

- ✅ **VS is COMPLETE, not just scoped** — the full core loop runs end-to-end: select → move/attack → produce → build → end turn → AI reply → win-check (developer-confirmed, windowed).
- ✅ **No critical fun-blocker bugs** — the windowed pass surfaced and fixed several (AI turn freeze, non-Scout movement, produce readiness, camera/overlay legibility), each with a regression test.
- ❓ **Core-loop fun validated** — NOT yet. No naive / silent-observer playtest; the developer has played it, but no independent player has.
- ❓ **Game communicates what to do within 2 minutes** — unvalidated by a fresh player (on-screen controls legend + move/attack range highlights help, but a real test is owed).

## Director Panel

Skipped this run — the verdict is artifact-determined (the only open items are the
two playtest/verdict artifacts, which no director assessment changes). Available on
request (CD/TD/PR/AD phase-gate panel) before an eventual Production commit.

## Chain-of-Verification

5 questions checked — ADR acceptance re-grepped (18 Accepted), art-bible sections +
AD sign-off re-read, `production/playtests/` re-listed (empty), smoke result
re-confirmed (826/826). **Verdict unchanged (CONCERNS).** Noted tension: a strict
reading of the skill's "slice built AND a validation item is NO → FAIL" rule could
argue FAIL, but the slice is demonstrably playable and not known-unfun, and the
playtest rollover is explicitly sanctioned — so CONCERNS is the honest call.

## Path to PASS (re-gate criteria)

1. Run the **iso-legibility playtest** (Pillar-3 hard gate) — ≥1 documented session, naive/silent-observer preferred → `production/playtests/`.
2. Run the **swing-back playtest** sampling (≥3 close + ≥3 decided, or the Sprint-3 DoD floor of ≥1 documented session) → `production/playtests/`.
3. Write the **`/vertical-slice` REPORT** with the PROCEED / PIVOT / KILL verdict → `REPORT.md`.
4. Re-run `/gate-check pre-production`.

> Verdict guidance carried from the scope doc: a muted/absent swing-back result is a
> **PIVOT-to-build-outpost signal, not a KILL**; a board that reads poorly is a
> **PIVOT** (revise iso art/depth cues); a *decided* game reversing in the swing-back
> sample is the one hard "must not happen" observation.
