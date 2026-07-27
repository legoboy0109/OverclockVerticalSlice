# Test Infrastructure — OVERCLOCK

**Engine**: Redot 26.2 (Godot 4.6-compatible fork) — binary at `./redot`
**Test Framework**: GdUnit4 (addon)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-07-24

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

Local (uses the Redot binary at the repo root):

```
./redot --headless --script tests/gdunit4_runner.gd
```

CI runs the same GdUnit4 suite on every push/PR to `main` (see CI note below).

## GdUnit4 (vendored)

GdUnit4 **v6.1.3** is vendored in-repo at `res://addons/gdUnit4/` (enabled in
`project.godot`), so local runs need no editor/AssetLib step — clone and run.
CI does not use the vendored copy; the `gdUnit4-action` fetches its own (see CI note).

First run on a fresh clone builds the script class cache:

```
./redot --headless --import        # one-time, generates .godot/ (gitignored)
./redot --headless --script tests/gdunit4_runner.gd
```

The runner defaults to scanning `tests/unit/` + `tests/integration/`, and passes
`--ignoreHeadlessMode` (GdUnit4 blocks headless runs by default because UI
`InputEvent`s don't propagate headless — our suites are pure-logic, so this is
safe; UI/feel checks live in `tests/evidence/`, not here). Exit code is 0 on
pass, non-zero on failure, so CI blocks correctly. Override the scan set with
explicit `-a res://path` args.

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Test Rules (from `.claude/docs/coding-standards.md`)

- **Determinism**: same result every run — no unseeded RNG, no time-dependent asserts.
- **Isolation**: each test sets up and tears down its own state; no order dependence.
- **No hardcoded data**: use constant files / factory functions (exception: boundary
  value tests where the exact number is the point).
- **Independence**: no external APIs, DBs, or file I/O — use dependency injection.

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration (multi-system) | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

> **Script-class cache pre-build**: CI checks out a fresh tree with no `.godot/`
> (gitignored), so `class_name` scripts are not yet registered in the global
> script class cache. The workflow installs Godot 4.6 and runs a two-pass
> `--headless --import` **before** the test step to build the cache — otherwise
> any newly added `class_name` script fails the headless run with "Could not
> find type X" (Godot #93424 / #75684). This mirrors the one-time local
> `./redot --headless --import` step above. When adding a new `class_name`
> script, no manual action is needed for CI; locally, re-run the import (or
> `./redot --headless --quit --editor`) if the runner reports the type missing.

> **Redot vs Godot in CI**: There is no Redot-specific GitHub Action. CI uses the
> `gdUnit4-action` with stock **Godot 4.6** as a compatible stand-in — Redot 26.2 is a
> Godot-4.6 hard-fork and headless GdUnit4 tests run identically. If a Redot-specific
> engine behavior ever diverges under test, switch CI to a self-hosted runner using the
> `./redot` binary.
