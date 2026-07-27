# Story 007: AI-vs-Human `apply_action` Diff Harness + Seeded/Fuzz Corpus

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-015`, `TR-ai-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary — TR-ai-015 "satisfied by construction," TR-ai-016 enabled by headlessness); ADR-0003 (secondary — determinism)
**ADR Decision Summary**: Because `AITurnDriver` commits through the identical `apply_action` pipeline a human's UI uses, an AI commit is indistinguishable from a human one; this story asserts that via a field-level diff and a seeded fuzz corpus proving determinism + no-negative-AP.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: No new engine surface — a test-authoring story building on Stories 001–006. Fuzz generator uses a fixed seed (never `randi()`/`randomize()`, ADR-0003 Rule 1).

**Control Manifest Rules (this layer)**:
- Required: `choose_action` must be pure, headless, and must never call `apply_action` itself — this story's diff proves the *driver's* `apply_action` calls are indistinguishable from a human's — source: ADR-0011
- Forbidden: No engine RNG in state transitions — the fuzz generator must use a fixed seed, never the banned global RNG functions — source: ADR-0003

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] For a full logged AI turn, for every commit, the fields **position, hp, `current_ap(player)`, and entity-existence (created/destroyed)** are identical between the AI-driven `apply_action()` result and the same action committed by a human through the player-facing path for matched inputs — verified by **field-level diff of exactly those named fields**, NOT full-object serialization equality (AC-28)
- [ ] A fixed corpus of ≥20 authored board-state fixtures spans early/mid/late-game AP totals, roster compositions, and at least one zero-legal-action state
- [ ] Each fixture runs a full AI turn under property-based fuzzing of AP totals and unit placement — ≥500 generated cases total, with a **fixed test seed** (deterministic, not a "no seed" run)
- [ ] `current_ap(ai_player)` never goes negative during or after any commit, across the entire fixture + fuzz corpus (AC-7)
- [ ] Given a fixed board state and fixed AP total on the same build, running the AI's full turn twice from identical starting conditions produces the exact same ordered sequence of committed actions (AC-3, at scale)

---

## Implementation Notes

*Derived from ADR-0011:*

- TR-ai-015 is "satisfied by construction" — because `AITurnDriver` commits through the identical `apply_action` pipeline (ADR-0002) a human's UI uses, there is no AI-specific mutation path to diverge; this story writes the *diff assertion*, not new commit infrastructure.
- Confirm before writing: does a human-driven `apply_action` call path already exist as a callable test fixture (e.g. the Command & Action Interface's own `apply_action` call) to diff against? If so, reuse it directly — the "diff" is comparing two independent calls to the same underlying `GameState.apply_action`, not a mocked comparison.
- The fuzz corpus reuses the Story 006 driver loop as its execution vehicle. Use a fixed integer seed for the property-based generator (e.g. a project-standard `FuzzSeed` constant) — never `randi()`/`randf()`/`randomize()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The diff harness does not re-derive/re-implement `apply_action` — it only calls the existing pipeline twice (once via `AITurnDriver`, once via a direct/human-equivalent call) and diffs results
- **AC-34 (win-rate band vs a reference opponent) is explicitly OUT OF SCOPE** — no reference-opponent harness exists (OQ-9); do not attempt to build one

---

## QA Test Cases

- **AC-28**: Given matched inputs committed once via `AITurnDriver` and once via a human-equivalent `apply_action` call, Then position/hp/current_ap/existence fields are identical.
- **AC-7**: Given the ≥20-fixture corpus run under ≥500 fuzzed cases with a fixed seed, Then `current_ap(ai_player)` is never negative at any point.
- **AC-3 (corpus-scale)**: Given the same fixed board+AP total run twice, Then the ordered commit sequence is identical both times.
- **Edge (zero-legal)**: a zero-legal-action fixture — the harness handles a same-turn immediate End Turn without a false diff failure.
- **Edge (reseed)**: rerun the entire fuzz corpus with the same seed on a second run — byte-identical chosen-action sequence (regression guard against accidental nondeterminism, e.g. Dictionary insertion order).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ai-opponent/ai_human_diff_fuzz_corpus_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (needs the full driver to run complete AI turns). Confirm a human-equivalent `apply_action` call path exists to diff against (Command & Action Interface / direct call).
- Unlocks: None (verification story) — should run before Story 008 confirms no perf-load regressions
