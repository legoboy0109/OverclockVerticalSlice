# Story 002: Approved Query-Façade Allowlist + Deterministic Entity Enumeration Order

> **Epic**: AI Opponent (Minimal Vertical Slice)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/ai-opponent.md`
**Requirement**: `TR-ai-004`, `TR-ai-014`, `TR-ai-017` (query surface)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: AI Opponent (primary, §2/§5); ADR-0003 (secondary — entity-id-ascending iteration)
**ADR Decision Summary**: `AI` is a static `RefCounted` with one entry point `choose_action(state, economy_investments_committed) -> Action`; it clones, enumerates via a fixed query allowlist in entity-id order, and never materializes a full candidate array or calls `apply_action` itself.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: Composes already-shipped queries (`reachable`, `legal_targets`, `preview_damage`, `can_afford`, `legal_build_tiles`, `legal_deploy_tiles`, `legal_research_targets`); no new engine API. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `AI` must be a static utility exposing exactly one public entry point: `choose_action(state, economy_investments_committed) -> Action` — source: ADR-0011
- Required: Entity iteration order for AI enumeration must be `entity_id`-ascending (sorted once), never raw Dictionary order — source: ADR-0011, ADR-0003
- Forbidden: Never materialize the full candidate array then `sort()` — source: ADR-0011

---

## Acceptance Criteria

*From GDD `design/gdd/ai-opponent.md`, scoped to this story:*

- [ ] `AI` is declared `class_name AI extends RefCounted`, no instance state, exposing exactly one public entry point: `static func choose_action(state: GameState, economy_investments_committed: int) -> Action`
- [ ] `choose_action` internally clones (`state.clone()`) and never calls `apply_action` itself
- [ ] Entity iteration for enumeration is collected once, sorted ascending by `entity_id`, never raw `entities_by_id` order — verified by seeding entities in reverse-ID insertion order and confirming enumeration still proceeds ID-ascending
- [ ] Every read in the enumeration path routes only through the ADR-0011 §5 allowlist (`GameState.clone/active_player/current_ap/entities/entity_at/match_status/faction_of`, `Movement.reachable`, `Combat.legal_targets`/`legal_targets_from`/`preview_damage`, `AP.can_afford/current_ap/income`, `BaseProduction.legal_build_tiles/legal_deploy_tiles/completed_outpost_count`, `Research.legal_research_targets`, `GridState.manhattan_distance/terrain_at/occupant_at`) plus public typed fields those calls return (AC-5/AC-6b allowlist property)
- [ ] `ai.gd` does not `extends Node` and contains no `await` (lint-checkable structural property)
- [ ] `choose_action` never materializes a full candidate array — uses the running-best streaming max-scan shape (skeleton only here; the comparator is Story 005, but the scan structure must not allocate an `Array` of candidates)

---

## Implementation Notes

*Derived from ADR-0011 §2/§5:*

- File `src/gameplay/ai/ai.gd`. This story builds the *skeleton*: the five private per-verb enumeration helper stubs named in ADR-0011 §2 (`_score_move_and_attack_candidates`, `_score_production_candidates`, `_score_build_and_economy_candidates`, `_score_research_candidates`, `_score_cancel_build_candidates`), each taking `(lookahead, entity, economy_investments_committed)` and returning an updated `(action, score, ap_cost, entity_id)` running-best — but the *scoring formulas* are Stories 003/004.
- This story proves the enumeration order, the query boundary, and the no-array-materialization shape are correct even with placeholder/trivial scores.
- **Research/Tech is NOT implemented yet** — `_score_research_candidates` and `legal_research_targets` are stubbed to return no candidates (empty) until the Research epic lands; do NOT block this story on Research.
- AC-5/AC-6b are satisfied here as the allowlist *property*: the actual CI lint enforcing the allowlist is owed to godot-specialist/CI tooling (per ADR-0011), a separate task outside this epic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Actual `combat_value`/`production_value`/`economy_value`/`research_value`/positional math — Stories 003/004
- The tie-break comparator's epsilon logic — Story 005
- `AITurnDriver` — Story 006; cadence-cap enforcement — Story 004

---

## QA Test Cases

- **AC (order)**: Given a `GameState` with 5 owned entities inserted in non-ascending ID order, When `choose_action` enumerates, Then the internal iteration list is entity-id-ascending.
- **AC (headless)**: Given `choose_action` called from a plain unit test with no `SceneTree`/`Node`, Then it runs and returns without error.
- **AC (no array)**: Given a stubbed pass with 100 fake candidates, Then no `Array` of size >1 candidate is held simultaneously (static/code-review check, documented).
- **Edge**: zero entities owned → enumeration completes with an empty running-best, no crash.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai-opponent/ai_enumeration_order_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`AIConfig` threaded through helpers)
- Unlocks: Stories 003/004 (scoring helpers plug into this skeleton)
