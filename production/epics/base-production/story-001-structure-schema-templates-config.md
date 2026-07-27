# Story 001: Structure Schema, Templates & Config — StructureTypeDef / StructureState / StructureTypes / BaseProductionConfig

> **Epic**: Base & Production
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 4 hours
> **Manifest Version**: 2026-07-25
> **Last Updated**: 2026-07-27

## Context

**GDD**: `design/gdd/base-production.md` — Core Rules 1–2, 2b; the Structure stat-template table (Formulas); the "Named constants (Base & Production-owned)" table.
**Requirement**: `TR-baseprod-001`, `TR-baseprod-002`, `TR-baseprod-014`, `TR-baseprod-016`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017: Base & Production mechanics (D1 structure lifecycle FSM; D6 `BaseProductionConfig`)
**Secondary ADRs**: ADR-0007 (StructureState/StructureTypeDef schema, `BuildStatus` enum, preload'd type registry, `producible_types`).
**ADR Decision Summary**: The persisted structure lifecycle is the 2-value `StructureState.BuildStatus{UNDER_CONSTRUCTION, COMPLETED}` enum declared on `StructureState` by ADR-0007 (D1); "Destroyed"/"Removed" are terminal erasure exits, never stored states. Structure templates are immutable data `Resource`s (`StructureTypeDef`) preload'd once into a thin logic-free `StructureTypes` registry; type identity is Resource-reference equality, never a parallel enum. Non-template B&P constants live in a dedicated `BaseProductionConfig` (`extends Resource`, `.tres`) loaded via the Balance-style Autoload — never on `GameState` (D6).

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: `@export`-carrying fields on `StructureState` are required for `duplicate_deep()` inclusion (ADR-0001/0007). Preload'd (path-having) `StructureTypeDef` templates stay SHARED references under `duplicate_deep()` (not deep-copied) — ADR-0007. No post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: "`EntityState` must be specialized into exactly two concrete subclasses — `UnitState` and `StructureState` — no further subclassing (a Research Lab is a `StructureState`)" — source: ADR-0007
- Required: "The persisted structure lifecycle must be exactly the 2-value `BuildStatus{UNDER_CONSTRUCTION, COMPLETED}` enum; 'Destroyed'/'Removed' are terminal exits, never stored states" — source: ADR-0017
- Required: "Each entity must carry a `type` reference to an immutable stat-template `Resource` (`StructureTypeDef`), `preload()`'d once into thin logic-free registry consts — never runtime `load()`" — source: ADR-0007
- Required: "Type identity must be answered by Resource-reference identity (e.g. `structure.type == StructureTypes.ECONOMY_OUTPOST`), never a parallel enum discriminator" — source: ADR-0007
- Required: "Template registry constants must be declared `const`, never `var`, and never mutated at runtime" — source: ADR-0007
- Required: "`BaseProductionConfig` (non-template constants) must be a dedicated Resource loaded via the Balance-style Autoload, never on `GameState`" — source: ADR-0017
- Forbidden: "Never add a third concrete `EntityState` subclass (e.g. `ResearchLabState`)" — source: ADR-0007
- Forbidden: "Never model stat data as a GDScript enum + static const Dictionary" — source: ADR-0007

> **Codebase note**: NO real structure code exists in `src/` yet — only the Sprint-era stubs at `tests/helpers/stubs/{structure_state_stub,structure_stub,base_production_stub}.gd`. This story creates the real `StructureTypeDef`, `StructureState` (with the `BuildStatus` enum), the `StructureTypes` registry, the five `.tres` templates, and `BaseProductionConfig` — and these **supersede** the stubs. Mirror the exact pattern of `src/core/unit/` (`unit_type_def.gd` / `unit_state.gd` / `unit_types.gd` / `unit_config.gd`). New structure files live under `src/core/structure/`; the `BaseProduction` static class lands later at `src/core/base_production/base_production.gd` (Story 002).

---

## Acceptance Criteria

*Templates (Rules 1–2 — fields match the stat table EXACTLY):*
- [ ] **GIVEN** the HQ template, **THEN** `hp == 40`, `production_cap == 2`, `producible_types == {Scout}`, `defense == 2`, `can_counterattack == false` (no `build_cost`/`build_time` — placed at setup).
- [ ] **GIVEN** the Economy Outpost template, **THEN** `hp == 8`, `build_cost == 4`, `build_time == 1`, `production_cap == 0`, `producible_types == {}`, `defense == 0`, `can_counterattack == false`.
- [ ] **GIVEN** the Production Outpost template, **THEN** `hp == 14`, `build_cost == 9`, `build_time == 2`, `production_cap == 4`, `producible_types == {Trooper, Heavy, Sniper}`, `defense == 0`.
- [ ] **GIVEN** the Defensive Structure template, **THEN** `hp == 10`, `build_cost == 6`, `build_time == 1`, `production_cap == 0`, `attack == 4`, `attack_range == 2`, `defense == 1`, `can_counterattack == true`.
- [ ] **GIVEN** the Research Lab template (Rule 2b, Research-owned stat values, B&P-owned lifecycle), **THEN** it is a `StructureState` (not a new subclass), `production_cap == 0`, and its stat values are `hp 12 / build_cost 8 / build_time 2` (per registry `TR-research-001`).
- [ ] **GIVEN** any template read twice, **THEN** identical (immutable — queries never mutate; registry consts are shared references).
- [ ] **GIVEN** a fresh `StructureState`, **THEN** `build_status` is a member of `BuildStatus{UNDER_CONSTRUCTION, COMPLETED}` (exactly two persisted values); per-instance fields `hp`, `build_turns_remaining`, `units_produced_this_turn`, `has_attacked`, `owner` are declared and `@export`-carrying (`duplicate_deep`-included).
- [ ] **GIVEN** `BaseProductionConfig`, **THEN** `cancel_refund_pct == 50`, `defensive_attack_cost == 1`, `max_outpost_count == 10` and `max_outpost_count` reads **disabled** in the VS config (a sentinel/off marker — no count cap is enforced).
- [ ] **GIVEN** the VS config, **THEN** the `max_outpost_count`-disabled state is asserted by a smoke check (guards the "disabled" claim — no further count-behavior coverage while the lever is off).

---

## Implementation Notes

*Derived from ADR-0017 (D1, D6) and ADR-0007:*

- **`StructureTypeDef`** (`src/core/structure/structure_type_def.gd`, `class_name StructureTypeDef extends Resource`): `@export` immutable template fields — `display_name: String`, `hp: int`, `build_cost: int`, `build_time: int`, `production_cap: int`, `producible_types: Array[UnitTypeDef]`, and the Defensive-Structure combat fields `attack: int`, `attack_range: int`, `defense: int`, `can_counterattack: bool`. Mirror `unit_type_def.gd`. `DEFENSIVE_ATTACK_COST` is **not** a template field — it is a `BaseProductionConfig` constant (D6), read cross-system by Combat.
- **`StructureState`** (`src/core/structure/structure_state.gd`, `class_name StructureState extends EntityState`): `enum BuildStatus { UNDER_CONSTRUCTION, COMPLETED }` (ADR-0007 D1 — exactly two persisted values). Per-instance `@export` fields: `build_status: BuildStatus`, `build_turns_remaining: int`, `units_produced_this_turn: int`, `has_attacked: bool`. `owner`/`type`/`current_hp`/`position`/`entity_id` come from `EntityState` (mirror `UnitState`). Research-Lab per-Lab fields (`current_research_target`, `research_turns_remaining`) are ADR-0018's — **out of scope**, not added here.
- **`StructureTypes`** (`src/core/structure/structure_types.gd`, `class_name StructureTypes`): a thin logic-free registry with `const HQ := preload(".../hq.tres")` etc. for all five structures — mirror `unit_types.gd`. Identity is Resource-ref (`s.type == StructureTypes.ECONOMY_OUTPOST`), never a string/enum.
- **Five `.tres` templates** under `data/structures/` (or wherever `unit_types.gd`'s templates live — match that location): `hq.tres`, `economy_outpost.tres`, `production_outpost.tres`, `defensive_structure.tres`, `research_lab.tres`. Values transcribe the stat table exactly. `producible_types` arrays reference the preload'd `UnitTypes` consts (Resource-ref identity, not names).
- **`BaseProductionConfig`** (`src/core/base_production/base_production_config.gd`, `extends Resource`) + a `.tres` with `cancel_refund_pct: int = 50`, `defensive_attack_cost: int = 1`, `max_outpost_count: int = 10` — plus the VS "disabled" marker for `max_outpost_count` (0 or a sentinel, per D6). Loaded once via the existing `Balance`-style logic-free Autoload (mirror `unit_config.gd` + `unit_balance.gd`), never on `GameState`.
- **`cancel_refund_pct` is fixed-point integer percent (50)**, not a float — ADR-0017 D6 bans floats in the AP-refund path (ADR-0003). Refund math (`build_cost * pct / 100`) is Story 005's; this story only stores the constant.
- **Research Lab is a `StructureState`, not a subclass** — ADR-0007 forbids `ResearchLabState`. Its stat values (hp 12 / cost 8 / time 2) are shown for roster completeness and are Research-owned (Rule 2b); B&P owns only the generic lifecycle it reuses.

### What this story supersedes

The three stubs (`structure_state_stub.gd`, `structure_stub.gd`, `base_production_stub.gd`) are replaced by the real schema + registry + config authored here. Downstream stories (002–010) build against the real types. `base_production_stub.gd`'s `completed_outpost_count` is superseded by the real implementation in Story 003.

---

## Out of Scope

- The `BaseProduction` static utility class and any verb logic (`build`/`produce`/`cancel_build`/`legal_*`) — Stories 002, 004, 005.
- Build-timer advance / start-of-turn flag reset — Story 003.
- Refund arithmetic (`build_cost * cancel_refund_pct / 100`) — Story 005.
- Research-Lab per-Lab research state fields (`current_research_target`, `research_turns_remaining`) and tech behavior — ADR-0018 / Research epic.
- Faction `effective_*` folds over these templates — introduced where the reads occur (Stories 002/004).

---

## QA Test Cases

- **AC-templates (HQ)**: Given `StructureTypes.HQ` / When fields read / Then hp 40, cap 2, producible {Scout}, def 2, counter false; no build_cost/build_time. Edge: HQ is never a buildable type (asserted in Story 002's `legal_build_tiles`).
- **AC-templates (Economy Outpost)**: Given `StructureTypes.ECONOMY_OUTPOST` / Then hp 8, cost 4, time 1, cap 0, producible {}, def 0, counter false.
- **AC-templates (Production Outpost)**: Given `StructureTypes.PRODUCTION_OUTPOST` / Then hp 14, cost 9, time 2, cap 4, producible {Trooper, Heavy, Sniper}, def 0.
- **AC-templates (Defensive Structure)**: Given `StructureTypes.DEFENSIVE_STRUCTURE` / Then hp 10, cost 6, time 1, cap 0, atk 4, rng 2, def 1, counter true.
- **AC-templates (Research Lab)**: Given `StructureTypes.RESEARCH_LAB` / Then it is a `StructureState` instance (no third subclass), production_cap 0, hp 12 / cost 8 / time 2.
- **AC-immutability**: Given any template read twice / Then field-wise identical and the same object reference (registry const shared).
- **AC-lifecycle enum**: Given a fresh `StructureState` / Then `build_status` ∈ {UNDER_CONSTRUCTION, COMPLETED} (exactly two values); the four per-instance fields exist and carry `@export`.
- **AC-config**: Given `BaseProductionConfig` (VS) / Then cancel_refund_pct 50, defensive_attack_cost 1, max_outpost_count 10.
- **AC-max-outpost-disabled (smoke)**: Given the VS config / Then `max_outpost_count` reads **disabled** (the only assertion this lever is worth — guards the "disabled" claim).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/base-production/structure_schema_templates_config_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (foundation of the epic). Uses the already-shipped `UnitTypes` (Unit System, Complete) for `producible_types` Resource-refs and `EntityState` (Foundation, Complete).
- **Unlocks**: All other Base & Production stories (002–010) — they build/produce/cancel/attack against this schema, registry, and config.

---

## Completion Notes
**Completed**: 2026-07-27
**Criteria**: 9/9 passing (no deferred items)
**Deviations** (all ADVISORY, code-review-confirmed sound):
- `StructureTypeDef` gained `targeting_mode`/`min_range` — required by `combat.gd`'s structure-attacker reads; **ADR-0007 Key-Interfaces footnote owed** (logged to tech-debt register).
- `StructureState.is_hq()` returns `type == StructureTypes.HQ` (Resource-ref, satisfies `game_state.gd:219`); replaces the stub's `is_hq_flag`.
- MAX_OUTPOST disabled via a dedicated `max_outpost_count_enabled: bool = false` (count stays 10) rather than overloading `== 0`.
- Stub `has_acted` mapped to real `has_attacked`.
- **Scope (user-approved):** deleted `tests/helpers/stubs/structure_state_stub.gd` and migrated ~7 Complete-epic test files (Combat/Movement/turn-sequencing) to the real schema — an unavoidable `class_name StructureState` collision.
- **Code-review found + fixed:** `combat_apply_action_integration_test.gd:283` mutated the shared `StructureTypes.HQ` const (latent false-green); removed the unnecessary line.
**Test Evidence**: Logic — `tests/unit/base-production/structure_schema_templates_config_test.gd` (11 tests; full suite 386/386, exit 0, order-independent after the fix).
**Code Review**: Complete — `/code-review` APPROVED (gdscript-specialist CLEAN; qa-tester found the shared-const mutation, fixed).
**Note (CI)**: new `class_name` scripts + autoloads required the class-cache rebuild (`./redot --headless --quit --editor`) — handled by the committed CI fix.
