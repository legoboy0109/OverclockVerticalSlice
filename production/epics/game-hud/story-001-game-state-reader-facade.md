# Story 001: `GameStateReader` Facade + Event-Driven Read Binding + Dirty-Flag Coalescing

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-001`, `TR-hud-002`, `TR-hud-003`, `TR-hud-020`, `TR-hud-023`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §1); ADR-0004: Event/signal architecture (secondary — `action_applied` single event surface + coalescing)
**ADR Decision Summary**: The HUD is injected with a getters-only `GameStateReader` facade (never the live mutable `GameState`), subscribes to `action_applied`, and coalesces N per-frame state changes to ≤1 native `queue_redraw()`.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Pure `RefCounted` facade + `queue_redraw()` native coalescing — stable ≤4.3, unchanged for 4.6. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: The HUD must be injected with a `GameStateReader` facade (getters only) — never the live mutable `GameState` — source: ADR-0016
- Required: On any relevant signal, a HUD `Control` must call `queue_redraw()` (native redraw-coalescing) rather than a hand-rolled `_process` dirty-flag poll — source: ADR-0016
- Forbidden: Never let the HUD read the live mutable `GameState` directly — source: ADR-0016

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN N tracked state-change signals fire within one frame, THEN the HUD issues exactly one coalesced redraw reflecting all N new values — verified via a mock signal bus + redraw-count spy (AC-1a)
- [ ] GIVEN HUD-only interactions (hover AP counter, toggle income breakdown, scroll log, hover an entity), THEN zero `apply_action`/commit calls are invoked AND the read values (`current_ap`, `active_player`, `round_number`, entity hp/status) are unchanged before vs after (AC-2)
- [ ] A `GameStateReader` instance exposes no method that mutates `GameState` — grep/reflection check finds zero setter/`apply_action` surface reachable from the injected object
- [ ] GIVEN each pass-through display mapping (income breakdown, hp pips, build-timer badge, research progress, projected AP) is stubbed with an injected value, THEN the HUD displays that exact injected value verbatim (AC-21) — this story establishes the facade + stub harness; per-mapping wiring lands in each widget's story
- [ ] **Deferred (flag, don't skip)**: AC-1b (≤1-frame render-latency integration test) is blocked on a frame-stepped test harness that does not yet exist — this story covers AC-1a (coalescing count, testable today) and explicitly records AC-1b as blocked-on-infra

---

## Implementation Notes

*Derived from ADR-0016 §1 + ADR-0004:*

- Build `game_state_reader.gd` — `class_name GameStateReader extends RefCounted`, constructed with a private `_state: GameState`, exposing getters only: `active_player()`, `round_number()`, `match_status()`, `current_ap(player)`, `income_breakdown(player)` (forward-declares `AP.ap_income_breakdown`), `can_afford(player, amount)`, `entities()`, `entity_at(tile)` — one getter per read the HUD needs, no write path on the object.
- HUD `Control` nodes subscribe to `GameState.action_applied(result)` (ADR-0004) and call `queue_redraw()` on any relevant signal — never a hand-rolled `_process` dirty-flag poll. `queue_redraw()` natively coalesces N calls in one frame to one `_draw()`.
- Add the companion `src/ui/` lint rule (candidate CI check, static allowlist) restricting which Autoload methods HUD scripts may call — belt-and-suspenders against reaching around the facade.
- This story does NOT wire the 7 individual upstream reads into widgets (each subsequent story's job) — it establishes the facade class + coalescing mechanism + stub-and-verify harness for AC-21/AC-2.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Individual widget rendering — all later stories
- The `HUDConfig` Resource — Story 002
- The AP-counter FSM — Story 003

---

## QA Test Cases

- **AC-1a**: Given a mock signal bus firing `hp_changed` ×3 + `ap_spent` ×2 within one `_process` frame, When the frame advances, Then the redraw-count spy records exactly 1 call. Edge cases: 0 events → 0 redraws.
- **AC-3 (facade lint)**: Given a `GameStateReader` instance, When reflection/grep scans its public method set, Then no method name matches a mutation-shaped pattern (`apply_action`, `spend`, `set_*`, `mutate*`).
- **AC-2**: Given the HUD hovers an AP counter with no commit, When the interaction completes, Then `current_ap`/`active_player`/`round_number` and all queried entity hp/status are bit-identical before and after.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/game-hud/game_state_reader_test.gd` — must exist and pass

**Status**: [x] Created and passing — 10 tests, all green (2026-07-28)

---

## Dependencies

- Depends on: None (first story — the epic's foundation). The 7 upstream systems (Grid, GameState, AP, Unit, Combat, Base&Production, Research) are all Complete.
- Unlocks: every other HUD story (all widgets are injected with this facade)

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: 4/4 testable passing (AC-1a, AC-2, AC-3, AC-21). AC-1b DEFERRED — blocked-on-infra (frame-stepped render-latency harness does not exist yet; documented skip in the test file).
**Deviations**:
- OUT OF SCOPE (valid, not creep): `tests/unit/unit-system/unit_read_surface_test.gd` allowlist extended to admit the 10 new `GameStateReader` methods — required because this story extends the shared facade that test guards; sanctioned by that test's own "the allowlist grows with each read accessor" comment. Non-mutating brokers documented as affordances.
- Implementation note: new `class_name` scripts (`HudReactiveControl`) written outside the editor required `./redot --headless --import` to register in the global class-name cache before tests resolved them.
**Test Evidence**: Logic — `tests/unit/game-hud/game_state_reader_test.gd` (10 tests, PASS). Full suite 721/721 green.
**Code Review**: Complete — APPROVED (independent godot-gdscript read-only pass + coordinator review; ADR-0016 §1/§8 compliant, 6/6 standards).
