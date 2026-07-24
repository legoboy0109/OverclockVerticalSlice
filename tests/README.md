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

## Installing GdUnit4 (required before tests run)

GdUnit4 is not vendored — install it once:

```
1. Open Redot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: res://addons/gdunit4/ exists
```

Until the addon is present, `tests/gdunit4_runner.gd` will error out with a
clear message (by design) and CI will fail.

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

> **Redot vs Godot in CI**: There is no Redot-specific GitHub Action. CI uses the
> `gdUnit4-action` with stock **Godot 4.6** as a compatible stand-in — Redot 26.2 is a
> Godot-4.6 hard-fork and headless GdUnit4 tests run identically. If a Redot-specific
> engine behavior ever diverges under test, switch CI to a self-hosted runner using the
> `./redot` binary.
