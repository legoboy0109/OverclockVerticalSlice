# Story 008: Perf-Budget Assertion for the Evaluate→Commit Loop

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S (2h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary — QQ-06 spike result, Performance Implications)
**ADR Decision Summary**: The evaluate→commit loop meets its perf budget with ~2 orders of magnitude headroom (QQ-06 PASS); this story ports that already-cleared measurement into a repeatable regression test against the real classes.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: QQ-06 perf gate already cleared PASS 2026-07-25 (~3.7ms p95 @ N≤24 on 14×16; bench `prototypes/spikes/qq06_ai_loop_bench.gd`). This story asserts that budget against the real `AI`/`Movement`/`Combat` classes (not the spike's stand-ins), per ADR-0011's own non-blocking follow-up note. **Note**: typed Integration for the story-done gate (evidence lives in `tests/performance/`); it is a performance-budget regression test.

**Control Manifest Rules (this layer)**:
- Performance Guardrail: AI enumerate→commit loop (`choose_action`) measured ~3.7 ms p95 / ~3.68 ms mean per full pass (845 candidates, N≤24 units on 14×16); a full 5-commit turn totals ~16.4 ms of compute, fitting inside one 60 FPS frame before pacing applies — source: ADR-0011
- Performance Guardrail: Dominant AI cost is enumeration (O(N²·W·H) shape), not scoring (O(1) per formula) — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] At the VS worst-case army size (N ≤ 24) on the pinned 14×16 board, a full `choose_action()` pass completes within budget — the GDD placeholder ceilings (AC-9b `[PLACEHOLDER: 3000ms turn / 400ms per-commit]`) are resolved to the concrete QQ-06 numbers: assert p95 per pass under a stated margin above the ~3.7ms baseline (e.g. < 50ms p95, generous enough to avoid CI flakiness on shared hardware while still catching a real regression)
- [ ] The test runs against the **real** `AI`/`Movement`/`Combat` classes (not the spike's stand-ins) — ADR-0011's flagged non-blocking follow-up
- [ ] A full 5-commit streaming turn totals within budget (~16.4ms of compute measured in the spike, well under one 60 FPS frame, before `commit_pacing_sec` applies)
- [ ] Test failure threshold and measurement method are both stated explicitly in the test file (p95 over N repeated runs, wall-clock via `Time.get_ticks_usec()` or engine-equivalent) — not just "fast enough"

---

## Implementation Notes

*Derived from ADR-0011 Performance Implications:*

- Port the measurement methodology from `prototypes/spikes/qq06_ai_loop_bench.gd` (exists, PASSED) into a proper `tests/performance/` test that exercises the shipped `AI.choose_action`/`AITurnDriver` rather than the spike's stand-in classes.
- This is NOT a re-litigation of the search strategy — full re-enumeration already meets budget with ~2 orders of magnitude headroom; no incremental-invalidation fallback is needed at this scale (OQ-1's fallback stays unused unless a future roster grows N > 24, a playtest tripwire, not a story-blocking condition here).
- Construct or reuse a fixture board with N=24 units on the pinned 14×16 board matching the spike's scenario as closely as possible.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- OQ-1's incremental-invalidation/caching fallback (not needed, do not implement)
- Revisiting the perf gate's PASS/FAIL threshold values themselves (already decided — this is measurement/regression-test porting only)

---

## QA Test Cases

- **AC (p95)**: Given N=24 units on the pinned 14×16 board (QQ-06 scenario), When `AI.choose_action` runs repeatedly, Then p95 wall-clock is within the asserted threshold (regression vs ~3.7ms with margin).
- **AC (5-commit turn)**: Given a full simulated 5-commit AI turn, Then total compute stays well under one 60 FPS frame (16.6ms) before any `commit_pacing_sec` delay.
- **Method**: p95 over ≥20 repeated `choose_action` calls on the fixed N=24/14×16 fixture, measured via engine wall-clock; fail if p95 exceeds a stated margin above the ~3.7ms baseline (5–10× headroom, not a hair-trigger).
- **Edge**: N=1 (near-trivial board) — sanity check the harness itself isn't dominating measured time.

---

## Test Evidence

**Story Type**: Integration (performance-budget regression test)
**Required evidence**: `tests/performance/ai-opponent/ai_loop_perf_budget_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001–006 (needs the real, complete `AI.choose_action` + `AITurnDriver`)
- Unlocks: None (terminal verification story; can run in parallel with Story 007 once 006 lands)
