# Control Manifest

> **Engine**: Godot 4.6 (Redot 26.2, Godot-4.6-compatible fork)
> **Last Updated**: 2026-07-27
> **Manifest Version**: 2026-07-27
> **ADRs Covered**: ADR-0001 through ADR-0018 (all Accepted; ADR-0001 has an S2-02 per-player-index addendum)
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this
date when created; `/story-readiness` compares a story's embedded version to this
field to detect stories written against stale rules. Always matches `Last Updated`.

This manifest is a programmer's quick-reference extracted from all 18 Accepted ADRs,
`technical-preferences.md`, and the engine reference docs. For the reasoning behind
each rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: state model, scene/match bootstrap, event architecture, save/load, engine initialisation*

### Required Patterns
- **`GameState` must extend `Resource` and be constructed only via `.new()` at runtime — never loaded from disk** — source: ADR-0001
- **`clone()` must be implemented as `duplicate_deep()` cast to `GameState` — one call, no hand-written per-field copy** — source: ADR-0001
- **Every field on `GameState`/`PlayerState`/`EntityState` must carry `@export` (storage usage) or it is silently excluded from `duplicate_deep()`** — source: ADR-0001, ADR-0007
- **Entities must be small typed `Resource` subclasses (`EntityState`), never bare Dictionaries** — source: ADR-0001
- **No Autoload may hold authoritative `GameState`; the authoritative instance is created by a match-bootstrap script and passed by reference (DI)** — source: ADR-0001
- **`MatchService` (Autoload) must stay a thin, logic-free lookup pointer: get/set current state only, no mutation/validation/signals** — source: ADR-0001
- **Unit tests and the AI must construct or receive a `GameState` directly, never touching `MatchService`** — source: ADR-0001
- **`entity_id` must be a single incrementing `int` field (`next_entity_id`) living directly on `GameState`, bumped on entity creation via `apply_action`** — source: ADR-0001
- **Every state field must be a plain serializable value — no engine object references (`Node`, `RID`)** — source: ADR-0001
- **`GameState` must expose a side-effect-free read API: `active_player`, `current_ap(player)`, `round_number`, `match_status`, `entities()`, `entity_at(tile)`, `grid`, `faction_of(player)`** — source: ADR-0001
- **Per-player-index parameters are a trusted internal contract — accessors indexing `per_player[player]` (`GameState.current_ap`/`faction_of`, all `AP.*(state, player)`, `Unit.effective_*` via `unit.owner`, any `effective_X(state, base, player)`) must NOT bounds-guard the index; an out-of-range/invalid player index is a programmer error and must fail-fast (crash), never return a sentinel (`0`/`null`/`{}`)** — source: ADR-0001 (read-API), S2-02 ruling
- **The `GameStateReader` presentation facade is the sole sanctioned bounds-guard boundary: it already returns empty (`{}`/`[]`) on an unresolvable `entity_id`, and is the ONLY place a future out-of-range `player` guard (stale UI-state lag) may be added — the core mutation/query layer stays trusted-crash** — source: ADR-0016 §1 (read-only facade), S2-02 ruling
- **`faction_of(player)` must be stored and `starting_loadout` applied once at Setup, then locked** — source: ADR-0001
- **`GameState` must support an optional `MAX_ROUNDS` cap + `TIEBREAK_METRIC` anti-drag terminal predicate** — source: ADR-0001
- **`end_turn()` must be unconditionally legal for the active player — no softlock** — source: ADR-0001
- **Grid must be owned inside `GameState`, decoupled from any render node** — source: ADR-0001
- **`apply_action(action) -> ActionResult` is the sole mutation vector for `GameState`** — source: ADR-0001, ADR-0002
- **Each `Action` must be a typed subclass, one per verb, in its own top-level file with `class_name` (never a nested inner class), setting `verb: Verb` in `_init()`** — source: ADR-0002
- **Dispatch must be by the `verb` enum via a `Dictionary[int, Callable]` built once — never by runtime type inspection** — source: ADR-0002
- **`apply_action` must be a thin orchestrator; each verb's rules live in the owning Core system as pure `validate(state, action) -> int` and `apply(state, action) -> Array[Event]`** — source: ADR-0002
- **`validate()` must be pure and total (check ALL failure conditions, including `AP.can_afford`); `apply()` must assume validation passed and never return failure** — source: ADR-0002
- **Atomicity must be achieved via validate-before-mutate with no rollback** — source: ADR-0002
- **`apply_action` must return a uniform `ActionResult` `{ok: bool, reason: int, events: Array[Event]}` for every verb** — source: ADR-0002
- **Idempotency must be handled via stateless re-validation — no dedup IDs, no seen-set** — source: ADR-0002
- **`EndTurnAction` must be exempt from all affordability/legality checks — unconditionally legal for the active player** — source: ADR-0002
- **`apply_action`'s fixed 7-step pipeline must run in order: (1) GameOver gate, (2) active-player gate, (3) validate, (4) reject if not OK, (5) apply, (6) run_win_check, (7) return ActionResult** — source: ADR-0002
- **`validate()`'s return type must stay `-> int` (a Reason code) deliberately — do not "fix" it to a `Reason` object** — source: ADR-0002
- **RNG must be isolated to Grid map generation only, run once at load, via a dedicated seeded `RandomNumberGenerator` (seed = map definition's `PROC_SEED`)** — source: ADR-0003
- **All state must be 100% integer — every field on `GameState`/`PlayerState`/`EntityState`/`GridState` is `int`/`enum`/`Vector2i`, no float ever** — source: ADR-0003
- **Fractional gameplay coefficients must be stored as scaled integers (e.g. `PENALTY_X10 = 15`) and computed via integer ceil/floor-division** — source: ADR-0003
- **Spatial iteration must use flat arrays indexed `index(x,y) = y*GRID_WIDTH + x`** — source: ADR-0003
- **Any order-sensitive pass over `entities_by_id` must iterate a list sorted by a stable key (`entity_id` or tile index) — never rely on Dictionary hash/insertion order** — source: ADR-0003
- **`GameState` must declare and emit its own signal directly: `signal action_applied(result: ActionResult)` — no separate Event-bus Autoload** — source: ADR-0004
- **`action_applied` must be emitted exactly once, synchronously, at the end of `apply_action`'s pipeline, and only when `result.ok == true`** — source: ADR-0004
- **`Event` must be a top-level `class_name Event extends RefCounted`; each owning Core system defines its own `Event` subclasses as top-level files, appended to `events` in the order effects actually happened** — source: ADR-0004
- **Event append order inside `apply()` is the resolution order — nothing downstream may reorder it** — source: ADR-0004
- **A subscriber must never mutate state from inside its `action_applied` handler** — source: ADR-0004
- **`GridState` must extend `Resource`, storing the board as two flat packed arrays (`terrain: PackedByteArray`, `occupancy: PackedInt32Array`) plus `width`/`height`** — source: ADR-0005
- **Index into both grid arrays via `index(x, y) = y * width + x`** — source: ADR-0005
- **`occupancy` must store `entity_id` (int) or `-1`, never an `EntityState` reference** — source: ADR-0005
- **`terrain` must be static after load; `occupancy` is the only mutable part of grid data** — source: ADR-0005
- **`place`/`remove`/`move` must be the grid's only mutators, called only from inside `apply_action` handlers** — source: ADR-0005
- **`MapDefinition` must extend `Resource` (`.tres`), loadable standalone, with a `mode` field (`AUTHORED`/`PROCEDURAL`)** — source: ADR-0005
- **`build_grid(map_def) -> GridState` must be the sole grid constructor; the same definition must yield identical grids on every build** — source: ADR-0005
- **`build_grid` must run in order: validate dims in [8,24]² → lay terrain → validate HQ-to-HQ reachability → init occupancy + place entities → return `GridState`** — source: ADR-0005
- **Authored maps failing HQ-to-HQ reachability must be rejected at load; procedural maps must self-correct via seed-stable-order thinning (no re-roll), clamping density and logging if still unconnectable** — source: ADR-0005
- **The reachability validator must be a pure, headless, deterministic BFS flood-fill over passable tiles** — source: ADR-0005
- **`AP` must be a static utility class (`class_name AP extends RefCounted`) with only pure/static functions taking `GameState` explicitly — no instance fields** — source: ADR-0006
- **Tuning constants must live in a dedicated `EconomyConfig` Resource (`.tres`), never as GDScript `const`s and never on `GameState`** — source: ADR-0006
- **A thin, logic-free `Balance` Autoload must load `EconomyConfig` once at boot and expose it by reference — never mutating/validating/interpreting** — source: ADR-0006
- **`AP.can_afford()` must stay a pure query; `AP.spend()` must be the sole AP mutator, atomic, gated to `player == active_player`, called only from inside a verb handler's `apply()`** — source: ADR-0006
- **`AP.reset_turn()`/`AP.discard()` must be called only from the start-of-turn sequence** — source: ADR-0006
- **`Research.economy_tech_income_bonus()` returns the fully-capped term; callers must add it verbatim and never re-apply `ECONOMY_TECH_TIER_THRESHOLD`** — source: ADR-0006
- **Non-negativity must be enforced by construction (`max(0, n)` floor, `spend()` bounds checks)** — source: ADR-0006
- **`EntityState` must be specialized into exactly two concrete subclasses — `UnitState` and `StructureState` — no further subclassing (a Research Lab is a `StructureState`)** — source: ADR-0007
- **Each entity must carry a `type` reference to an immutable stat-template `Resource` (`UnitTypeDef`/`StructureTypeDef`), `preload()`'d once into thin logic-free registry consts — never runtime `load()`** — source: ADR-0007
- **Type identity must be answered by Resource-reference identity (e.g. `structure.type == StructureTypes.ECONOMY_OUTPOST`), never a parallel enum discriminator** — source: ADR-0007
- **Template registry constants must be declared `const`, never `var`, and never mutated at runtime** — source: ADR-0007
- **`entities()` iteration must be in `entity_id` order (stable)** — source: ADR-0007
- **`GameState.start_turn(player: int) -> Array[Event]` must be a `GameState`-owned instance method running the canonical 4-step sequence in this exact order: (1) set active player, (2) reset per-turn flags for that player's entities, (3) advance build + research timers (completing structures/techs), (4) `AP.reset_turn()` income snapshot** — source: ADR-0008
- **Steps 2 and 3 must both complete before step 4's income snapshot; the two timer-advance calls WITHIN step 3 (build vs research) are order-independent and must stay commutative** — source: ADR-0008
- **`start_turn()` must be called in exactly two places: `start_match()` for the starting player, and `EndTurnAction.apply()` for the next player** — source: ADR-0008
- **`EndTurnAction.apply()` must, in order: discard the outgoing player's AP, determine next player, increment `round_number` only if `next_player == starting_player`, then call `start_turn(next_player)`** — source: ADR-0008
- **`GameState` gains a `starting_player: int` field, set once by `start_match()`, never mutated after** — source: ADR-0008
- **Per-turn flag resets must be attributed to owning systems (`Unit.reset_turn_flags`, `Structure.reset_turn_flags`) — `GameState` owns only the timing** — source: ADR-0008
- **New `Event` subclasses (`StructureCompletedEvent`, `TechCompletedEvent`) must flow through the existing `action_applied` signal — no new signal or polling path** — source: ADR-0008
- **`InputConfig` must be a new per-system config Resource loaded by the Balance-style Autoload, kept off `GameState`, never runtime-mutated** — source: ADR-0014
- **`HUDConfig` must be a new per-system config Resource (`gameplay_config_storage` pattern) with knobs: `pip_max_hp`, `action_log_length`, `ap_fill_flourish_ms`, `ap_tick_duration_ms`, `turn_banner_duration_ms`, `hud_audio_duck_ms`, `show_opponent_ap`, `show_opponent_fill_flourish`, `income_breakdown_default_expanded`** — source: ADR-0016
- **The config loader (Autoload, not either Resource's `_init()`) must enforce `InputConfig.input_lock_ms >= HUDConfig.ap_tick_duration_ms` after loading both, using a release-surviving guard (`push_error` + clamp), never a bare `assert()`** — source: ADR-0014, ADR-0016
- **`PlayerState.is_ai_controlled: bool` must be set once at Setup, immutable after Setup→PlayerTurn** — source: ADR-0011
- **`PlayerState.faction: FactionDef` must be Setup-locked, immutable after Setup→PlayerTurn** — source: ADR-0012

### Forbidden Approaches
- **Never use an Autoload singleton holding full authority over `GameState`** — structurally hostile to `clone()`-based AI lookahead and headless testing, and conflicts with the DI-over-singletons standard — source: ADR-0001
- **Never use `RefCounted` + a hand-written `clone()`** — a forgotten field fails silently (reverts to class default) instead of test-visibly, a manual-sync regression risk on the most safety-critical operation — source: ADR-0001
- **Never conflate state ownership with event propagation in a single event-bus-core Autoload** — violates single-responsibility and drags a global-bus dependency into every unit test — source: ADR-0001
- **Never represent entities as plain Dictionaries** — loses static typing/autocomplete in the AI's hot loops — source: ADR-0001
- **Never add a defensive bounds-guard returning a safe-default snapshot to a core per-player-index accessor** — a swallowed bad index lets an AI `clone()` score a corrupt state and turns a caller bug into a silent test-green instead of a loud fail; the sim is single-process/all-in-repo so every player index originates from `active_player` or a `0/1` literal and a bad one is definitionally a programmer error — source: S2-02 ruling (ADR-0001, ADR-0003 determinism)
- **Never build a separate injectable `EntityIdAllocator` object** — disproportionate machinery for one incrementing integer that must itself stay in sync under `clone()` — source: ADR-0001
- **Never dispatch a verb via `Object.get_class()`** — for a GDScript-defined class it returns the base engine class name (`"RefCounted"`), so `match action.get_class()` silently never matches — source: ADR-0002
- **Never use snapshot-and-rollback for atomicity** — pays a full `clone()` cost on every committed action, doubling the AI's already-hot `clone()` usage — source: ADR-0002
- **Never embed `validate()`/`apply()` methods directly on `Action` subclasses (command pattern)** — pulls verb rules out of the owning Core system, violating the module-ownership map — source: ADR-0002
- **Never represent an Action as a tagged Dictionary `{verb, params}`** — untyped params lose compile-time checking in the AI's hot enumeration loop — source: ADR-0002
- **Never give each verb its own Result subtype** — forces every caller to switch on verb to read a result — source: ADR-0002
- **Never mutate state inside `validate()`, or check a precondition only in `apply()`** — breaks the "illegal action ⇒ zero state change" atomicity guarantee — source: ADR-0002
- **Never pursue full cross-platform bit-determinism (fixed-point everywhere including AI scoring)** — forces AI scoring into fixed-point at a portability cost with no consumer in current scope — source: ADR-0003
- **Never rely on best-effort determinism (seed once, allow floats in state, rely on ordered dictionaries)** — float accumulation and hash/insertion-order coupling make the sim subtly irreproducible — source: ADR-0003
- **Never call global `randi()`/`randf()`/`randi_range()`/`randf_range()`/`randomize()`/`seed()` anywhere in the project** — one hidden shared stream any stray call silently perturbs, breaking map-gen reproducibility + determinism — source: ADR-0003
- **Never route `action_applied` through a dedicated `EventBus` Autoload** — redundant with `MatchService`'s already-solved lookup, adds indirection for no VS-scope capability — source: ADR-0004
- **Never expose several separate typed signals (`ap_changed`, `hp_changed`, …) instead of one unified signal** — loses free per-commit coalescing and deterministic intra-commit ordering — source: ADR-0004
- **Never emit a generic diff payload (`state_changed(diff: Dictionary)`)** — throws away the static typing already built into `events: Array[Event]` — source: ADR-0004
- **Never emit `action_applied` unconditionally with subscribers filtering on `result.ok`** — wastes work on rejected actions and weakens the "a fired signal always means real state change" contract — source: ADR-0004
- **Never store the grid as an Array of per-tile `Tile` objects** — object-per-tile allocation overhead, deep-copied every clone, and occupant references reintroduce clone-aliasing — source: ADR-0005
- **Never store the grid as a `Dictionary` keyed by `Vector2i`** — hash lookups instead of O(1) index, and hash/insertion-order iteration violates determinism — source: ADR-0005
- **Never store an `EntityState` reference in grid occupancy** — under `clone()` the same entity would be deep-copied into two divergent objects (a severe aliasing bug) — source: ADR-0005
- **Never use JSON/text map files with a custom parser** — needs a hand-written parser/validation layer and loses typed fields + inspector editing — source: ADR-0005
- **Never mutate `terrain`/`occupancy` directly outside `place`/`move`/`remove`** — bypasses the single-occupant invariant and determinism guarantees — source: ADR-0005
- **Never make AP Economy an instance-based service object** — no per-instance state justifies it and it is inconsistent with sibling static verb handlers — source: ADR-0006
- **Never put `income()`/`spend()`/`can_afford()` directly on `GameState`/`PlayerState`** — bloats `GameState`'s surface, re-centralizing what was deliberately decentralized — source: ADR-0006
- **Never use one shared `BalanceConfig` Resource for all systems' tuning constants** — couples unrelated systems' balance passes into one git-diff-noisy file — source: ADR-0006
- **Never hardcode tuning constants as GDScript `const`s** — violates the data-driven coding standard — source: ADR-0006
- **Never thread an explicit `config: EconomyConfig` parameter through every `AP` call site** — changes signatures across the codebase for effectively load-time-constant data — source: ADR-0006
- **Never have AP Economy iterate `entities_by_id` directly to count outposts** — requires it to know structure-type vocabulary owned by Base & Production — source: ADR-0006
- **Never model stat data as a GDScript enum + static const Dictionary** — every balance tweak needs a code change/redeploy, no inspector editing, untyped access loses static typing — source: ADR-0007
- **Never add a third concrete `EntityState` subclass (e.g. `ResearchLabState`)** — forces `is ResearchLabState` checks elsewhere against the "no new mechanics" framing — source: ADR-0007
- **Never add a parallel `StructureKind`/`UnitKind` enum discriminator alongside the `type` Resource reference** — two fields that must always agree is a second failure mode Resource-identity avoids — source: ADR-0007
- **Never store entity stats as data-oriented parallel arrays** — the few-dozen entity count makes the cache-locality win irrelevant — source: ADR-0007
- **Never call `load()` on a template `.tres` outside the registry Autoloads** — returns a second Resource instance with different identity, silently breaking `==` comparisons — source: ADR-0007
- **Never split turn-orchestration into a separate static `TurnManager` utility class** — creates two homes for closely related sequencing logic for no benefit — source: ADR-0008
- **Never leave Base & Production's / Research's timer-advance contracts undefined until those systems get their own ADR** — nothing would ever formally define them — source: ADR-0008
- **Never inline per-turn flag resets directly in `GameState.start_turn()`** — couples the Foundation layer to every Core system's per-turn flag set — source: ADR-0008
- **Never reorder start_turn step 4 before step 3** — the income snapshot must observe structures/techs that completed this same turn — source: ADR-0008
- **Never use silent state transitions with no completion events (polling/diffing)** — reintroduces exactly the polling problem ADR-0004 eliminated — source: ADR-0008

### Performance Guardrails
- **`clone()`**: cost scales with entity count + per-Resource duplication overhead; budgeted by ADR-0011's AI loop — source: ADR-0001
- **`apply_action`**: one `validate()` + one `apply()` dispatch per committed action — negligible for turn-based play; avoid per-call allocation where hot — source: ADR-0002
- **Determinism sorting**: `keys().sort()` on order-sensitive passes is O(n log n) over a small entity set — negligible — source: ADR-0003
- **`action_applied` emission**: one `emit_signal` per successful commit; scales with subscriber count (2–3 in VS scope) — negligible — source: ADR-0004
- **Grid queries**: O(1) integer index; `neighbors` O(4); BFS reachability validator O(W·H), run once at load — source: ADR-0005
- **Grid memory**: on a 24×24 max board, `terrain` = 576 B + `occupancy` = 2.3 KB per `GridState` — cheap even cloned many times per AI turn — source: ADR-0005
- **AP Economy**: `income()`/`can_afford()`/`spend()` are O(1) integer arithmetic; `income()` dominated by `completed_outpost_count()`'s per-player scan — source: ADR-0006
- **`EconomyConfig`**: single small resource loaded once at boot, not per-clone — zero incremental AI-lookahead cost — source: ADR-0006
- **Template resources**: 12 total, each a few dozen bytes, loaded once at boot, shared by reference — never duplicated per instance or per clone — source: ADR-0007
- **`completed_outpost_count()`**: O(entity count), called once per player per start-of-turn (not per-frame) — source: ADR-0007
- **`start_turn()`**: runs once per player per turn — one filtered O(entity count) pass plus two per-system passes — source: ADR-0008

### Engine API Constraints
- **`Resource.duplicate_deep()` (Godot 4.5) default `DEEP_DUPLICATE_INTERNAL` mode recursively deep-copies nested arrays/dictionaries and path-less (runtime `.new()`) Resource instances — confirmed against live 4.6 docs** — source: ADR-0001
- **`duplicate_deep()` treats disk-loaded (path-having, e.g. `preload()`'d) Resources as SHARED references, NOT deep-copied — confirmed against engine source, gated on `Resource::is_built_in()`** — source: ADR-0007
- **Typed `Dictionary[int, EntityState]` is supported since Godot 4.4** — source: ADR-0001
- **`get_class()` on a GDScript-defined class returns the base engine class name, not the script's `class_name`** — source: ADR-0002
- **Covariant Object-subclass array typing (`Array[Event]` holding subclass instances) is supported in 4.6** — source: ADR-0002
- **Godot dictionaries do preserve insertion order, but this must not be relied on for correctness** — source: ADR-0003
- **`Resource` has NO `DUPLICATE_SIGNALS`/`CONNECT_PERSIST` opt-in (unlike `Node.duplicate()`) — a cloned `Resource` architecturally carries zero signal connections** — source: ADR-0004
- **String-based `connect("signal", obj, "method")` was removed in Godot 4.0 — always use `signal.connect(callable)`** — source: ADR-0004
- **`PackedByteArray`/`PackedInt32Array` are recursively duplicated by `duplicate_deep()`; all stable pre-cutoff APIs** — source: ADR-0005
- **Instance-method dispatch is identical whether `GameState` came from `.new()` or `duplicate_deep()`; `duplicate_deep()` copies a field's value at call time (no lazy snapshot)** — source: ADR-0008

---

## Core Layer Rules

*Applies to: movement/pathfinding, combat resolution, base & production, research/tech, main gameplay loop*

### Required Patterns
- **`Movement` must be a static utility class (`class_name Movement extends RefCounted`, no instance state); all entry points take `state` explicitly** — source: ADR-0009
- **The reachable-tile search must use plain BFS by depth plus a closed-form length→cost conversion — not a priority-queue Dijkstra — under the min-length ≡ min-cost property for uniform terrain** — source: ADR-0009
- **BFS expansion must stop the instant a layer's cost exceeds `current_ap`** — source: ADR-0009
- **The BFS-by-depth shortcut is scoped to uniform-terrain rules; it must be revisited (algorithm change) the moment difficult-terrain (variable per-tile cost) lands** — source: ADR-0009
- **Visited/cost bookkeeping must use flat `PackedInt32Array`, never `Dictionary`** — source: ADR-0009
- **`reachable()` must be recomputed fresh every invocation — no caching, fresh-per-call allocation (a pooled buffer risks stale depth leaking across cloned states)** — source: ADR-0009
- **`Movement` must NOT call `GridState.neighbors()` for BFS traversal (order unpinned); it must iterate its own explicit fixed offset order (N→E→S→W)** — source: ADR-0009
- **`reachable()`'s per-depth cost and `move()`'s billing must share the identical cost function** — source: ADR-0009
- **`SOFT_MOVE_PENALTY` must be a Unit-owned fixed-point int in a new `UnitConfig` Resource (`soft_move_penalty_x10`), never on `GameState`** — source: ADR-0009
- **Occupancy predicate for movement: friendly units may be passed through; structures (any owner) and enemy units are always hard blockers** — source: ADR-0009
- **`Combat` must be a static utility class (`class_name Combat extends RefCounted`, no instance state); all entry points take `state` explicitly** — source: ADR-0010
- **Damage formula must be `max(MIN_DAMAGE, effective_attack(state, attacker) - cover_reduction(state, defender) - defense(defender))`, with `cover_reduction` always 0 for `StructureState` (structures cover-immune)** — source: ADR-0010
- **`MIN_DAMAGE`/`COVER_DR` must live in a `CombatConfig` Resource, never on `GameState`** — source: ADR-0010
- **`effective_attack(state, entity)` must be a forward-declared Unit-owned contract; Combat must call it and never touch Research state directly** — source: ADR-0010
- **DIRECT targeting must walk tiles outward along each cardinal up to `attack_range`; the first occupied/Impassable tile stops the walk (nearest-only, no pierce)** — source: ADR-0010
- **AREA targeting (dormant) must ignore line-of-fire and select any enemy tile with `min_range ≤ manhattan_distance ≤ attack_range`; enforce the `min_range ≤ attack_range` schema invariant (violation ⇒ empty target set as a validation error, never a silent soft-lock)** — source: ADR-0010
- **`legal_targets(state, unit, from_tile)` must evaluate identical rules as if the unit stood on `from_tile`, purely, moving nothing (must equal the zero-arg form when `from_tile == unit.position`)** — source: ADR-0010
- **`Combat.apply()` must run the fixed pipeline: primary damage → primary death → conditional single counter → counter death, then return typed events** — source: ADR-0010
- **The counter step must fire at most once, non-recursively (a structural property of the straight-line pipeline, not a runtime guard), only when the defender survived and has `can_counterattack == true`; counters are free (no AP, no `has_attacked`)** — source: ADR-0010
- **Death/removal must be a single shared `GameState.destroy_entity(entity_id) -> Array[Event]` mutation-layer method, called from inside `Combat.apply()`** — source: ADR-0010
- **`destroy_entity()` must run, in order: (a) forward-declared `Research.on_lab_destroyed()` if the entity is a Lab with an active target (while still live), (b) `GridState.remove()`, (c) drop from `entities_by_id`, (d) append the destroyed event — all synchronously in the same `apply_action`** — source: ADR-0010
- **`destroy_entity()` may only be called from inside a verb handler's `apply()`, never mid-iteration over `entities_by_id`** — source: ADR-0010
- **`run_win_check(state, events)` must scan the commit's events for a `StructureDestroyedEvent` with `is_hq == true` — no separate HQ hp re-scan** — source: ADR-0010
- **A single Combat pipeline must handle an attacker that is a `UnitState` OR a `StructureState` (Defensive Structure); only AP cost differs (`defensive_attack_cost` is B&P-owned config read cross-system by Combat)** — source: ADR-0010, ADR-0017
- **The three blocked-shot reasons must be exposed as a queryable `BlockedReason` enum** — source: ADR-0010
- **`BaseProduction` must be a static utility class (`class_name BaseProduction extends RefCounted`, no instance state), mirroring `AP`/`Movement`/`Combat`** — source: ADR-0017
- **Build/Produce/CancelBuild must be typed `Action` subclasses routed by `apply_action`'s verb-enum dispatcher** — source: ADR-0017
- **The persisted structure lifecycle must be exactly the 2-value `BuildStatus{UNDER_CONSTRUCTION, COMPLETED}` enum; "Destroyed"/"Removed" are terminal exits (erase from `entities_by_id` + `GridState.remove()`), never stored states** — source: ADR-0017
- **`build()` must insert the structure into Grid occupancy at placement time regardless of `BuildStatus` — no intangible-under-construction carve-out (Under-Construction structures block movement and are targetable)** — source: ADR-0017
- **`Grid.place` + `AP.spend` must occur inside one `apply_action` (validate-before-mutate) so a rejected/unaffordable build leaves both untouched** — source: ADR-0017
- **`legal_build_tiles()` must be a pure, live query, never cached; candidate set = passable/empty/in-bounds friendly-frontier tiles (manhattan==1 of the player's own units AND structures, scanned N→E→S→W), filtered by strict `>2` manhattan standoff from every enemy structure, returned in canonical `sort_custom` tile-index order** — source: ADR-0017
- **The HQ must never be a candidate in `legal_build_tiles` (it is setup-placed, not a buildable type)** — source: ADR-0017
- **A transient Dictionary used purely for membership/dedup must never have its iteration order observed — only a trailing `sort_custom` makes returned order canonical** — source: ADR-0017
- **`legal_deploy_tiles()` must return empty/passable/in-bounds tiles at manhattan==1 from the producer, in canonical tile-index order** — source: ADR-0017
- **`validate_produce()` must gate on, in order: producer Completed; `unit_type in producible_types` (Resource-ref identity, never string/enum compare); `units_produced_this_turn < effective_production_cap`; `AP.can_afford`; tile in `legal_deploy_tiles`** — source: ADR-0017
- **`apply_produce()` must re-run `validate_produce` at commit (idempotent re-validation) and reject with no spend if preview-time conditions changed** — source: ADR-0017
- **`cancel_build()` must validate the structure is the owner's and `UNDER_CONSTRUCTION` (Completed structures cannot be cancelled, only combat-destroyed), then credit refund AP, `Grid.remove`, and erase the entity** — source: ADR-0017
- **Cancel refund must be returned on the `ActionResult` so the FSM/HUD render it from the query, never re-derive it** — source: ADR-0017
- **Cancel refund must use fixed-point integer percent: `refund = build_cost * cancel_refund_pct / 100` via integer division (floors), never a float rate** — source: ADR-0017
- **`BaseProductionConfig` (non-template constants) must be a dedicated Resource loaded via the Balance-style Autoload, never on `GameState`** — source: ADR-0017
- **`advance_build_timers(state, player)` must decrement `build_turns_remaining` on the player's Under-Construction structures, flip those reaching 0 to `COMPLETED`, and append one `StructureCompletedEvent` per completion (sequenced by ADR-0008 step 3, before the income snapshot)** — source: ADR-0017
- **`effective_production_cap` must use the two-sided invariant: base cap 0 stays 0 (a non-producer never becomes a producer via faction delta); base ≥ 1 → `max(1, base + delta)` — never a single symmetric clamp** — source: ADR-0017, ADR-0012
- **`Research` must be a static utility class (`class_name Research extends RefCounted`, no instance state), mirroring `BaseProduction`/`AP`/`Movement`/`Combat`** — source: ADR-0018
- **Start/Cancel Research must be typed `Action` subclasses dispatched by `apply_action`'s verb-enum router** — source: ADR-0018
- **The 3 permanent tech unlocks (`has_attack_tech`, `has_defense_tech`, `has_economy_tech`) must be `@export` bool fields on `PlayerState`** — source: ADR-0018
- **`advance_research_timers` must be the sole writer of the tech-unlock flags; once true a flag must never be reset to false (permanence, survives Lab destruction)** — source: ADR-0018
- **Per-Lab research state (`current_research_target: TechDef`, `research_turns_remaining: int`) must live on `StructureState`; `current_research_target == null` means Idle; parallel Labs track independent state** — source: ADR-0018
- **Cross-Lab same-tech mutual exclusion must be enforced at `validate_start_research` and mirrored in `legal_research_targets` (scan the same player's other Labs for `current_research_target == tech` via Resource-ref equality)** — source: ADR-0018
- **Tech status (`NOT_STARTED`/`UNDER_RESEARCH`/`COMPLETED`) must be derived, never stored in a per-(player,tech) table: `COMPLETED` ⇔ the player flag; `UNDER_RESEARCH` ⇔ some Completed Lab holds the target; else `NOT_STARTED`** — source: ADR-0018
- **`legal_research_targets(lab)` must return empty for a non-Completed (Under-Construction) or busy Lab; else filter the fixed 3-tech registry excluding Completed, Under-Research-elsewhere, and faction-disallowed, iterating in canonical declaration order** — source: ADR-0018
- **`validate_start_research` must gate on: Lab Completed, Lab Idle, tech in `legal_research_targets`, and `AP.can_afford(effective_research_cost)`** — source: ADR-0018
- **Research cost must be spent upfront in full at start, not amortized** — source: ADR-0018
- **`cancel_research`'s refund must reuse ADR-0017's `BaseProductionConfig.cancel_refund_pct` fixed-point integer division — no new config Resource** — source: ADR-0018
- **`on_lab_destroyed()` must only clear the in-progress target — it must never refund `research_cost` and never touch a completed `PlayerState` flag** — source: ADR-0018
- **`GameState.destroy_entity` must call `Research.on_lab_destroyed(state, lab)` while the Lab is still live, before Grid/entities removal** — source: ADR-0018
- **Techs must be identified by Resource-ref (`Techs.ATTACK_TECH` preload'd consts), never a string/enum discriminator or a `load()`'d copy** — source: ADR-0018
- **Labs must be iterated by ascending `entity_id` for deterministic scanning** — source: ADR-0018
- **`advance_research_timers` must be order-independent (commutative) with `advance_build_timers` within start-of-turn step 3 — neither timer body may read the other's output** — source: ADR-0018
- **Every board-space and menu interaction reachable by mouse must also be reachable by keyboard/gamepad — no hover-only interactions** — source: ADR-0014

### Forbidden Approaches
- **Never use `AStarGrid2D`/`AStar2D` (or `NavigationServer2D`/`NavigationAgent2D`) for the movement reachable-search** — their `_compute_cost`/`_estimate_cost` callbacks receive only the two endpoints with no accumulated path-depth, so the depth-dependent soft-cap surcharge cannot be computed without breaking A*'s closed-set invariant; Navigation targets continuous-space navmesh agents, not a logical tile grid — source: ADR-0009
- **Never implement a full `(tile, depth)`-keyed weighted Dijkstra under the current uniform-terrain ruleset** — overengineered; slower and more code for no current benefit (correct fallback only once difficult-terrain lands) — source: ADR-0009
- **Never add `reachable()`/`move_path_cost()` as instance methods on `GridState`** — couples Grid to Unit-owned fields it has no reason to know — source: ADR-0009
- **Never add `reachable()`/`move_path_cost()`/`legal_targets`/`attack` as instance methods on `GameState`** — re-accretes Core logic onto `GameState` (`destroy_entity` is the deliberate exception, as generic mutation-layer surgery) — source: ADR-0009, ADR-0010
- **Never use the physics engine (`PhysicsServer2D` ray/shape queries, `Area2D`/`RayCast2D`, Jolt) for combat targeting, line-of-fire, or range** — combat is deterministic integer/grid logic; physics raycasts are float-based, continuous-space, and not bit-reproducible across platforms/frames — source: ADR-0010
- **Never have Combat directly remove the piece while Research polls for reverts at start-of-turn** — the Lab-revert would no longer be same-step/synchronous — source: ADR-0010
- **Never revert Research state via an `action_applied` signal subscriber** — post-commit and observer-order-dependent; an AI clone (zero subscribers) would never revert, breaking clone parity — source: ADR-0010
- **Never re-scan all HQ hp on every `apply_action` for the win-check** — duplicates the detection `destroy_entity()` already did; key off the `StructureDestroyedEvent{is_hq}` — source: ADR-0010
- **Never implement `BaseProduction` as a Node/Autoload with instance state (e.g. caching `legal_build_tiles`)** — would be deep-copied on every AI `clone()`, and caching live placement legality across a mutating board is a stale-cache bug magnet — source: ADR-0017
- **Never store all four GDD lifecycle states (`UNDER_CONSTRUCTION`/`COMPLETED`/`DESTROYED`/`REMOVED`) as a persisted enum** — keeps dead terminal entities in `entities_by_id`, forcing every consumer to add an "is it actually alive?" filter and duplicating erasure logic Grid/`destroy_entity` already own — source: ADR-0017
- **Never use a float cancel-refund rate (`CANCEL_REFUND_RATE: float = 0.5`) as literally written in the GDD** — injects a float into the AP-refund path; the economy is integer-only — source: ADR-0017
- **Never store a data-driven `completed_techs` set/Dictionary on `PlayerState` instead of the 3 named bool flags** — contradicts ADR-0008's already-registered `advance_research_timers` signature; the VS tech tree is fixed at 3 — source: ADR-0018
- **Never store a per-(player,tech) tri-state status table** — redundant with (flags + Lab targets), gives "Under Research" two representations that drift, and forces `on_lab_destroyed` to actively rewrite it instead of auto-reverting — source: ADR-0018
- **Never create a dedicated `ResearchConfig` Resource** — `research_cost`/`research_time`/effect magnitudes are per-tech `TechDef` template data (ADR-0007); `cancel_refund_pct` is B&P's, `ECONOMY_TECH_TIER_THRESHOLD` is AP-Economy's — source: ADR-0018

### Performance Guardrails
- **`reachable()`**: O(frontier size) per call, bounded by tiles within `current_ap`'s reach; measured ~2.0 ms/call worst-case (24×24 near-full saturation), 25–340 µs typical; at ~500 AI calls/turn ~1.0 s worst-case / <200 ms realistic-mix — acceptable (no per-frame deadline) — source: ADR-0009
- **`reachable()` memory**: one `PackedInt32Array` of size `width × height` per call, plus a small `Array[ReachableTile]` sized to result count — source: ADR-0009
- **`damage()`/`attack()`**: O(1) integer work plus one tile-walk (DIRECT) or one ring scan (AREA) — source: ADR-0010
- **`legal_targets()`**: O(4·attack_range) DIRECT / O(ring area) AREA; `legal_targets_from()` is reachable-sized (dominant caller = AI lookahead); `destroy_entity()` is O(1) plus the forward Lab-revert — source: ADR-0010
- **`legal_build_tiles`**: ≈ `friendly_count × 4 × enemy_structure_count` per call — trivial on 14×16, safe to recompute live, no cache/spike gate — source: ADR-0017
- **`legal_deploy_tiles`**: ≈ 4 checks per call — source: ADR-0017
- **`legal_research_targets`**: ≈ 3 techs × per-player Lab count scan — negligible — source: ADR-0018
- **`advance_research_timers`**: ≈ per-player Lab count — negligible — source: ADR-0018

### Engine API Constraints
- **`PackedInt32Array.resize()` + `.fill(-1)`, `Array[Vector2i]` frontier layers, and nested classes inside `class_name`-registered outer classes are idiomatic with no 4.4–4.6 change** — source: ADR-0009
- **Inner classes (e.g. `Movement.ReachableTile`) are not auto-registered as global `class_name` symbols — external references need the `Outer.Inner` prefix** — source: ADR-0009
- **`GridState.neighbors()`'s iteration order is not pinned by ADR-0005's contract — do not assume it is stable** — source: ADR-0009
- **`is` (script-class inheritance check) is the correct idiom for entity-subtype checks, explicitly distinct from the banned `get_class()` string-dispatch** — source: ADR-0010
- **Godot's 2D physics / Jolt is not used for combat — grid tactics has no physics simulation** — source: ADR-0010
- **`sort_custom(Callable)` (not the deprecated string-based form) is the correct custom-sort API for 4.6** — source: ADR-0017
- **GDScript integer `/` truncation equals floor for non-negative operands (confirmed for the `cancel_refund_pct` path)** — source: ADR-0017
- **Resource-ref `in`-membership on preload'd typed arrays is idiomatic and confirmed for 4.6** — source: ADR-0017
- **A nullable `TechDef` Resource-ref field with `==` identity (`null == tech` → false) clones cleanly via `duplicate_deep()` (null trivial; non-null preload'd `TechDef` stays SHARED per ADR-0007); `@export` bool `PlayerState` fields value-copy correctly under clone; `Array[TechDef]` construction has no covariance trap** — source: ADR-0018

---

## Feature Layer Rules

*Applies to: AI opponent decision loop, faction identity / modifier framework*

### Required Patterns
- **`AI` must be a static utility (`class_name AI extends RefCounted`, no instance state) exposing exactly one public entry point: `choose_action(state, economy_investments_committed) -> Action`** — source: ADR-0011
- **`choose_action` must be pure, headless, side-effect-free — it clones internally (`state.clone()`) and evaluates every candidate against the clone, and must never call `apply_action` itself (committing is the caller's job)** — source: ADR-0011
- **`choose_action` must never materialize a full candidate array — it must use a streaming max-scan, replacing the running-best only when strictly better under the tie-break comparator** — source: ADR-0011
- **The tie-break comparator must resolve ties within `score_tie_epsilon` by lowest `ap_cost`, then lowest `entity_id`** — source: ADR-0011
- **Entity iteration order for AI enumeration must be `entity_id`-ascending (sorted once), never raw Dictionary order** — source: ADR-0011
- **Each per-verb enumeration helper must call only the approved query surface and `AIConfig` — never a raw field outside the approved public accessors** — source: ADR-0011
- **The `economy_investments_committed: int` cadence-cap counter must be an explicit caller-passed parameter, never internal `AI` state** — source: ADR-0011
- **`AITurnDriver` must be a small `Node` (not Autoload, not authoritative) owning only real-time pacing between commits, holding zero authoritative state of its own** — source: ADR-0011
- **On a rejected/stale action the driver must re-loop immediately (`if not result.ok: continue`) with no AP spent and no pacing delay** — source: ADR-0011
- **If the AI's own commit ends the match, the driver must stop immediately and never enumerate again against a terminal state** — source: ADR-0011
- **`ai.gd` must not `extends Node` and must contain no `await` (lint-enforced)** — source: ADR-0011
- **The AI's approved query surface is a fixed named allowlist of `GameState`/`Movement`/`Combat`/`AP`/`BaseProduction`/`Research`/`GridState` reads; a lint rule must verify `ai.gd` never reaches outside it** — source: ADR-0011
- **`AIConfig` must hold exactly 15 externally-tunable `@export` knobs, loaded by the same thin Balance-style Autoload** — source: ADR-0011
- **`REACHABILITY_MULTIPLIER`'s fixed 3-band and `CANCEL_REFUND_RATE` must NOT be `AIConfig` fields (the band stays a code constant; the refund rate is read from `BaseProductionConfig`)** — source: ADR-0011
- **The cross-knob invariant `lethal_floor_bonus > economy_ceiling_score` must be enforced at config load with a release-surviving guard (`push_error` + hard failure/clamp), never a bare `assert()`** — source: ADR-0011
- **`FactionDef` must be a data-only `Resource` — numbers + enum flags only, no executable behavior, no `_process`** — source: ADR-0012
- **`FactionDef`'s schema must expose exactly the closed 6-domain set (unit cost, unit mobility, income-curve params, structure cost/time/cap, tech access/cost, starting loadout); the loader must reject out-of-schema fields at load** — source: ADR-0012
- **Per-entity faction deltas must be authored as typed arrays of tiny entry sub-resources (`Array[FactionUnitDelta]`/`[FactionStructureDelta]`/`[FactionTechDelta]`), each keyed by a Resource-reference `type`** — source: ADR-0012
- **A faction delta must be additive `int`, never multiplicative (a `×` factor would break integer-AP)** — source: ADR-0012
- **A faction may only re-cost/re-time/re-scale actions already priced in AP — never a second resource, a 0-AP version of a paid verb, a new verb, or a value outside the closed 6 domains** — source: ADR-0012
- **Faction deltas must fold in at each owning system's read site via `effective_X(state, base_owner, player) = clamp(base_X + delta, floor, inf)` — base registry values must never be rewritten** — source: ADR-0012
- **Every `effective_X` function must apply a per-domain floor (`max(1,…)`, `max(MIN_MOVE_COST,…)`, `max(MIN_BUILD_TIME,…)`, `max(MIN_RESEARCH_TIME,…)`, `BASE_INCOME_FLOOR`) enforcing "never a free/0-cost verb"** — source: ADR-0012
- **`effective_ap_income` must preserve the econ-tech term from ADR-0006 verbatim** — source: ADR-0012
- **`effective_production_cap` must branch on the sign of the base cap (two-sided invariant): base 0 → always 0; base ≥ 1 → `max(1, base+delta)`** — source: ADR-0012
- **`FactionDef` instances must be stored as preload'd registry consts (`Factions.NEUTRAL/RUSH/BOOM`), identity checked via Resource-reference equality — no parallel `enum FactionKind`** — source: ADR-0012
- **An orphaned delta (whose `type`/`tech` no longer exists) must be silently inert (contribute 0), logging a load-time schema warning** — source: ADR-0012
- **Under Neutral, `effective_X == base_X` must hold exactly for every domain (regression-pinned by a parametrized test); Neutral's entry arrays must be empty and income scalars 0** — source: ADR-0012
- **Both `faction_hue` and `faction_pattern_id` identity handles must be required non-empty** — source: ADR-0012
- **`starting_loadout` must be placed exactly once at SELECTING→ASSIGNED confirm, validated against legal setup tiles** — source: ADR-0012
- **Every `effective_X` function must take `player` as an argument so the AI reads faction-correct values via the same shared call sites with zero AI-only branch** — source: ADR-0012

### Forbidden Approaches
- **Never let `AI` own the whole loop and its own pacing as a `Node`/coroutine** — directly violates the headless requirement; every Logic-typed AC would degrade to needing a running `SceneTree` — source: ADR-0011
- **Never make the AI event-driven (reacting to its own `action_applied` signal to pick its next move)** — a signal handler reacting to its own emitted signal is re-entrant with no natural pacing seam and is harder to unit-test as a whole-turn sequence — source: ADR-0011
- **Never materialize the full candidate array then `sort()`** — adds O(candidates) allocation + O(candidates·log) sort for a result that only needs the single maximum — source: ADR-0011
- **Never enforce the `lethal_floor_bonus > economy_ceiling_score` invariant via a standalone offline tool instead of a load-time assert** — relies on someone remembering to run it — source: ADR-0011
- **Never use a bare `assert()` to enforce a gameplay-correctness invariant that must hold in shipped builds** — stripped from release exports — source: ADR-0011
- **Never let a central `Faction.effective_X` compute every domain itself** — forces Faction to read/own base values from 5 systems, breaking the "modifier provider, never owns a base value" discipline — source: ADR-0012
- **Never represent factions as `enum FactionKind` + a const Dictionary of deltas** — hardcodes deltas as GDScript consts, violates the data-driven standard, loses clone-sharing — source: ADR-0012
- **Never author per-entity faction deltas as `Resource`-object-keyed `Dictionary` tables** — a fragile `.tres` serialization corner with poor inspector editing for non-primitive keys — source: ADR-0012
- **Never apply `production_cap`'s faction delta via a single symmetric `max(0, base + Δ)` clamp** — fails both halves of the two-sided invariant (lets a faction zero a base-positive producer or manufacture a base-zero one) — source: ADR-0012

### Performance Guardrails
- **AI enumerate→commit loop (`choose_action`)**: measured ~3.7 ms p95 / ~3.68 ms mean per full pass (845 candidates, N≤24 units on 14×16); a full 5-commit turn totals ~16.4 ms of compute, fitting inside one 60 FPS frame before pacing applies — source: ADR-0011
- **Dominant AI cost is enumeration (O(N²·W·H) shape), not scoring (O(1) per formula)** — source: ADR-0011
- **AI memory**: one `lookahead` clone per `choose_action` call (per-commit, not per-candidate); no candidate array retained — source: ADR-0011
- **`Faction.unit_delta`/etc.**: linear scan over a roster-sized typed array (≤4 units / 5 structures / few techs) — negligible; Neutral's empty arrays make every scan an instant miss — source: ADR-0012
- **`GameState.clone()` carries `PlayerState.faction` as a shared reference — zero per-clone cost** — source: ADR-0012

### Engine API Constraints
- **A `Node` coroutine using `await get_tree().create_timer(...).timeout` for inter-commit pacing is standard GDScript 2.0 async, stable since 4.0** — source: ADR-0011
- **`Array.sort()` is not guaranteed-stable, but entity ids are unique so no equal keys exist for instability to affect** — source: ADR-0011
- **A bare `assert()` is stripped from release exports unless debug asserts are enabled — this shared risk applies to every `*Config` load-time check (`EconomyConfig`/`UnitConfig`/`CombatConfig`/`AIConfig`)** — source: ADR-0011
- **A path-having preload'd `FactionDef` is shared by reference (not deep-copied) on `GameState.clone()` — same finding as ADR-0007** — source: ADR-0012

---

## Presentation Layer Rules

*Applies to: isometric board rendering & picking, input/focus, Command & Action Interface FSM (view), HUD, audio*

### Required Patterns
- **`grid_to_screen(tile)`/`screen_to_grid(px)` must be one shared hand-rolled exact closed-form linear transform pair (2:1 dimetric shear+scale), never engine `local_to_map`/`map_to_local`** — source: ADR-0013
- **The forward/inverse transforms must be exact mathematical inverses, verified by round-trip identity** — source: ADR-0013
- **`screen_to_grid` must use `floori()` on the exact algebraic inverse so boundary ties resolve deterministically toward the lower-index tile** — source: ADR-0013
- **`grid_to_screen(tile)` must double as the sprite placement anchor; author every unit/structure/prop sprite pivot at its ground-contact point (bottom-center) so no extra offset is needed** — source: ADR-0013
- **Depth-sort must use native `y_sort_enabled` on `OccupantLayer`, never custom depth math** — source: ADR-0013
- **`BoardRenderer` scene structure must be `FloorTileMapLayer` (z_index 0) → `OverlayTileMapLayer` (z_index 1) → `OccupantLayer` (y_sort_enabled, z_index 2); Floor/Overlay sit outside the Y-sort group** — source: ADR-0013
- **`OverlayTileMapLayer` must share the floor's exact `TileSet` iso config (same tile dims + `TILE_SHAPE_ISOMETRIC`), with one atlas entry per the 9-class overlay taxonomy** — source: ADR-0013
- **Command & Action Interface must call `BoardRenderer.set_overlay(tiles, class_id)`/`clear_overlay()` — never touch `grid_to_screen`/pixel math itself for overlay placement** — source: ADR-0013
- **Picking must be occupant-priority then diamond fallback: `pick_at(screen_pos)` tests occupant sprites front-to-back in Y-sort draw order first (each clickable region an authored sprite Rect2/mask, not derived from `grid_to_screen`), falling back to plain `screen_to_grid` for empty-tile clicks** — source: ADR-0013
- **Command & Action Interface must consume `pick_at()` as its one click-routing entry point — never call `screen_to_grid` directly for routing** — source: ADR-0013
- **Every on-board glyph must anchor at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, with `GLYPH_OFFSETS` authored as data, not hardcoded literals; hp legibility wins any offset conflict (enforced by authoring discipline, not runtime arbitration)** — source: ADR-0013
- **Children of `OccupantLayer` must not set a `z_index` that fights the Y-sort** — source: ADR-0013
- **Never call `TileMapLayer.set_cell()` (or query a cell) with a raw grid tile — always go through `BoardRenderer.cell_for(tile)`** — a grid tile is NOT a tile-map cell; Redot's `TILE_SHAPE_ISOMETRIC` layout uses a different basis than the hand-rolled dimetric pair, and painting raw tiles drifts up to 1408px across a 12×10 board — source: ADR-0013 (Amendment 2026-08-19)
- **`TileSet.tile_size` is the 2× TEXTURE size (256×128) with both tile layers scaled 0.5; `TILE_WIDTH_PX`/`TILE_HEIGHT_PX` (128×64) remain the ON-SCREEN cell and must not be changed to match** — source: ADR-0013 (Amendment 2026-08-19)
- **Every occupant sprite must be `centered = false` with `offset = (-width/2, -height)` so its bottom-centre is the ground-contact pivot, anchored per-texture (sprites are trimmed to opaque bounds and differ in size)** — source: ADR-0013, art-bible §8.4
- **Cover must render as TWO nodes — a floor cell plus a separate Y-sorted prop — never one TileMapLayer cell** — a cell cannot participate in the occupant Y-sort — source: ADR-0013, art-bible §8.8
- **`BoardRenderer` must read `GameState`/`GridState` read-only and react to the `action_applied` signal — it must never mutate authoritative state** — source: ADR-0013
- **`BoardCursor` must be a headless `RefCounted` value object (`Vector2i grid_pos`) — no scene-tree reference, no input-polling of its own, no game rules** — source: ADR-0014
- **`BoardCursor.step(direction, grid)` must map to grid-axis directions (`ui_up`→y-1, `ui_down`→y+1, `ui_left`→x-1, `ui_right`→x+1), never screen-axis/iso-visual directions** — source: ADR-0014
- **`BoardCursor.jump_to_next(candidates, grid)` must cycle in deterministic ascending tile-index order (`y*GRID_WIDTH+x`), wrapping last to first** — source: ADR-0014
- **`BoardCursor` stepping must bind to the same `ui_up`/`ui_down`/`ui_left`/`ui_right` actions menu Controls consume, read in `_unhandled_input` (a focused Control consuming the event in the GUI pass IS the arbitration — no manual "who owns this keypress" flag)** — source: ADR-0014
- **`board_cursor_cycle` must be a dedicated input action, distinct from `ui_focus_next`/Tab** — source: ADR-0014
- **Mouse-hover vs. `BoardCursor` precedence must use last-updated-wins via `active_locus`/`active_tile` fields updated on tile-change — no timestamp/frame-delta comparison** — source: ADR-0014
- **`INPUT_LOCK_MS` must be a UX debounce timer only (flag + `await get_tree().create_timer(...).timeout`) gating only new commit dispatch — hover, cursor movement, and menu focus traversal must remain live during the lock window; it must NOT duplicate the single-commit safety already structurally guaranteed by synchronous dispatch + immediate FSM transition** — source: ADR-0014
- **Every interactive `Control` must use `grab_click_focus()` for mouse-click focus and `grab_focus()` for keyboard/gamepad focus — distinct methods, distinct `hover`/`focus` StyleBoxes, no custom focus-ring wiring** — source: ADR-0014
- **Present-but-inert controls (opponent's Action phase, `GAME_OVER`) must set `focus_mode = FOCUS_NONE` — never hand-roll per-frame focus-ring suppression** — source: ADR-0014
- **When `menu_keyboard_nav_enabled = false`, interactive Controls must use `focus_mode = FOCUS_CLICK` (not `FOCUS_NONE`) so mouse click still registers while Tab/`ui_focus_next` traversal is suppressed** — source: ADR-0014
- **`CommandFSM` (pure `RefCounted` core: `next_state`, `menu_model`, D-1/D-2/D-3 derivations) must be split from `CommandInterface` (Presentation `Node` that drives it), mirroring the `AI`/`AITurnDriver` split** — source: ADR-0015
- **`CommandFSM.next_state()` must be a pure, total function of (current state, trigger, read-only GameState)** — source: ADR-0015
- **`GAME_OVER` must be absorbing: `next_state()` returns `GAME_OVER` for every trigger once entered** — source: ADR-0015
- **The Node must enter `GAME_OVER` the moment it observes `match_status == GameOver` in its `action_applied` handler — both player instances converge via the same shared signal, no polling** — source: ADR-0015
- **Cancel-Build must be a bounded hold sub-condition inside `ENTITY_SELECTED`, never a new top FSM state: accumulate `_cancel_hold_elapsed_ms += delta*1000` in `_process` and poll `Input.is_action_pressed` for release (chosen over `create_timer` to detect release-before-threshold abort for free)** — source: ADR-0015
- **`menu_model()` must reach cost/legality data only by calling an owning system's side-effect-free query — never hold or reference a balance constant by name (structural Pass-Through Invariant enforcement)** — source: ADR-0015
- **The four-tier recompute strategy must fire at fixed points: Tier-1 (`reachable()`/`legal_targets()`) once per preview entry + re-issued on `action_applied` while a preview is open; Tier-2 (`legal_targets_from` D-3 batch) once per `PREVIEW_MOVE` entry only, never per hover; Tier-3 hover reads O(1) dict lookups into precomputed sets; Tier-4 legality re-validation only inside the owning `apply_action`** — source: ADR-0015
- **Raw `InputEventMouseMotion` must be tile-change-gated — read in the same `_unhandled_input` tier ADR-0014 established, compute `pick_at(event.position).tile`, and act only when the resolved tile differs from the last** — source: ADR-0015
- **The FSM must commit only via `GameState.apply_action` — it must never write state, deduct AP, or re-validate legality itself; on reject it swallows, re-issues Tier-1, and stays in the menu** — source: ADR-0015
- **Board-change detection must be defined against the logical `GameState` model, never scene-tree node presence** — source: ADR-0015
- **Commit-flash (this ADR) and AP-tick (ADR-0016) must both subscribe to the single `GameState.action_applied(result)` signal — neither polls for an AP delta, neither reacts to the other** — source: ADR-0015
- **Attack commits must fire no interface audio from `CommandInterface` — Combat triggers its own cue off the same `action_applied` event so exactly one system calls `play()`** — source: ADR-0015
- **If `GameState` is reused across a match restart within one process, `CommandInterface` must `disconnect` from `action_applied` in `_exit_tree()` so connections don't accumulate** — source: ADR-0015
- **The HUD must be injected with a `GameStateReader` facade (getters only) — never the live mutable `GameState` — so a mutating call is structurally unreachable, not just review-forbidden** — source: ADR-0016
- **The HUD must consume `AP.ap_income_breakdown()`'s pre-labeled decomposition verbatim — never receive raw inputs (outpost count, tech flag) and split/recompute the breakdown locally** — source: ADR-0016
- **`ApCounterFsm` (pure `RefCounted` core: `next_state`) must be split from the rendering widget, mirroring the `CommandFSM`/`CommandInterface` split** — source: ADR-0016
- **The AP counter FSM must have exactly 4 states: `COMMITTED`, `FILL_FLOURISH`, `TICK_DOWN`, `PREVIEW_ECHO` — only the local player's counter reaches all four; the opponent's reaches only `COMMITTED` (+ optionally `FILL_FLOURISH`/`TICK_DOWN`)** — source: ADR-0016
- **On any `PlayerTurn`/`EndTurn` transition, the widget must tear down the preview echo synchronously as the first step, before evaluating the incoming fill trigger — never infer the echo is gone** — source: ADR-0016
- **A commit triggering `GameOver` must force any in-flight tick-down to complete instantly (snap to final value within one frame); the killing commit's hp-pip drain is NOT truncated but also does NOT gate the overlay's one-frame appearance** — source: ADR-0016
- **Preview echo must snap (no tween); the committed value moves only on a real commit** — source: ADR-0016
- **The HUD must consume ADR-0014's `input_locked` debounce for AP-tick serialization — it must NOT build its own tick queue/interrupt logic** — source: ADR-0016
- **The action log must be an append-newest-on-top ring buffer sized `HUDConfig.action_log_length` (default 20), appending one entry per `result.events` element in the events' fixed append order, dropping oldest when full** — source: ADR-0016
- **The detail panel's data-flow must be outward-in: the HUD subscribes to `CommandInterface.selection_changed` — `CommandInterface` must never call into a HUD-owned node** — source: ADR-0016
- **A single HUD-owned `HudAudioDispatcher` must be the sole `play()` chokepoint for every HUD audio event — no widget plays its own sound** — source: ADR-0016
- **True audio ducking (lower-priority cue plays quieter but audible) requires ≥2 `AudioStreamPlayer` children/bus sends managed internally by the dispatcher (a single player replaces rather than layers)** — source: ADR-0016
- **Audio collisions must resolve against a single total priority order (highest first): `GameOver > turn-change stinger > completion cue (deduped) > AP-fill arpeggio` — lower-priority cues duck under `hud_audio_duck_ms`, except `GameOver` which hard-preempts (cut, not ducked); simultaneous completion cues dedupe to one played cue per frame** — source: ADR-0016
- **On any relevant signal, a HUD `Control` must call `queue_redraw()` (native redraw-coalescing) rather than a hand-rolled `_process` dirty-flag poll** — source: ADR-0016
- **The hp display must branch on `HUDConfig.pip_max_hp`: `max_hp < pip_max_hp` → discrete drain-on-damage pips; `max_hp >= pip_max_hp` → numeric `current/max` stepping in whole integers, never a smooth bar (the `>=` boundary is load-bearing)** — source: ADR-0016
- **The Build button must read `can_afford` across structure types and dim (never hide) when none affordable, holding a pressed/active treatment while `PREVIEW_BUILD` is live** — source: ADR-0016
- **On `match_status = GameOver(winner)` the victory/defeat overlay must appear within one frame, truncating any in-flight or pending turn banner** — source: ADR-0016
- **Build + End Turn controls must be live only in the local Action phase; otherwise render but set `FOCUS_NONE` (inert); readouts stay live** — source: ADR-0016
- **The four interactive HUD controls must follow ADR-0014's dual-focus conventions (`grab_click_focus`/`grab_focus`, `hover`/`focus` StyleBox)** — source: ADR-0016

### Forbidden Approaches
- **Never call `TileMapLayer.local_to_map()` for picking (nor `map_to_local()` for our own coordinate math)** — it has a documented accuracy bug for `TILE_SHAPE_ISOMETRIC` (GH#89423) and does not reliably invert the iso projection — source: ADR-0013
  - *Bounded exception*: `BoardRenderer.cell_for()` uses `local_to_map()` solely to address the engine's OWN cell space (which engine cell covers a point our transform located). Engine forward and engine inverse are mutually exact — verified 0.0px over 120 tiles. This is never grid↔screen math and never picking — source: ADR-0013 (Amendment 2026-08-19)
- **Never mix an engine `map_to_local()` forward transform with a hand-rolled inverse** — two independently-sourced math paths for what must be exact inverses risk drifting apart at edge pixels, a preview-vs-commit-style render-seam bug — source: ADR-0013
- **Never render floor/overlay tiles as individually placed Polygon2D/Sprite2D nodes instead of `TileMapLayer`** — forfeits native batching the draw-call budget depends on — source: ADR-0013
- **Never resolve clicks via pure diamond math (`screen_to_grid` alone) with no occupant-priority layer** — a tall sprite's overlapping silhouette could silently resolve to the wrong tile — source: ADR-0013
- **Never build `BoardCursor` as a `Node` with its own `_unhandled_input`** — two Nodes independently listening for overlapping input risks input-order bugs and breaks headless testability — source: ADR-0014
- **Never build a fully custom focus system bypassing native `Control` dual-focus** — reimplements an already-verified-correct engine subsystem and forfeits free StyleBox styling and future AccessKit integration — source: ADR-0014
- **Never track timestamp/frame-delta comparisons for mouse-vs-cursor precedence** — Godot's synchronous single-threaded dispatch already resolves "most recent" for free — source: ADR-0014
- **Never sort `jump_to_next()` candidates by nearest-tile-first (Manhattan distance)** — introduces a second novel ordering concept when tile-index order already satisfies the determinism convention — source: ADR-0014
- **Never fold `INPUT_LOCK_MS`/`MENU_KEYBOARD_NAV` into a different ADR's config Resource** — knobs live with the ADR that defines their mechanism, not a downstream consumer — source: ADR-0014
- **Never build a single `CommandInterface` Node holding transitions + rendering + input with no separable pure core** — every FSM-transition/menu-filter AC becomes Integration-typed and the Pass-Through Invariant becomes review-only rather than structural — source: ADR-0015
- **Never model FSM state as a Resource with per-state handler classes (State pattern)** — 7 states is small; a class hierarchy is harder to table-test and the corpus has otherwise avoided subclass hierarchies — source: ADR-0015
- **Never implement Cancel-Build as an affordance + separate confirm click** — adds a transient armed sub-state and a second UI target for no more double-click-proofing than the hold-to-confirm timer — source: ADR-0015
- **Never re-run `reachable()` on every hover instead of holding the Tier-1 set** — `reachable()` is a BFS/uniform-cost search, not O(1); re-running per mouse-motion event risks frame hitches — source: ADR-0015
- **Never let widgets subscribe directly and hold their own state with no facade** — never-mutates reverts to review/lint-only, AP animation states aren't cleanly headless-testable, and audio ownership scatters — source: ADR-0016
- **Never let the HUD read the live mutable `GameState` directly** — directly violates the structural never-mutates guarantee — source: ADR-0016
- **Never self-validate the cross-config invariant inside `HUDConfig._init()`** — `HUDConfig` cannot see `InputConfig` at its own init; the check needs the loader Autoload holding both — source: ADR-0016
- **Never use a bare `assert(input_lock_ms >= ap_tick_duration_ms)`** — `assert()` is stripped in Godot release exports, so the guard would silently vanish in the shipped build — source: ADR-0016
- **Never let each cue's owning system play its own sound independently** — reintroduces the double-`play()` risk and scatters total-priority-order resolution across systems that can't see each other's cues; binding audio to a value-change (`ap_changed`) instead of the commit signal is a second form of this bug — source: ADR-0016

### Performance Guardrails
- **Board rendering (floor + overlay)**: target ~5–10 draw calls for the whole 14×16 board; occupants batch per shared-atlas/material; project-wide ceiling < 500 draw calls — source: ADR-0013
- **`grid_to_screen`/`screen_to_grid`**: O(1) closed-form arithmetic — source: ADR-0013
- **`pick_at()`**: O(visible occupants) worst case, bounded by the same N≤24 army size ADR-0011 budgets — source: ADR-0013
- **`BoardCursor.step()`**: O(1); `jump_to_next()`: O(k log k) in candidate-set size k, bounded by `reachable()`/`legal_targets()`'s existing budgets — source: ADR-0014
- **Tier-3 hover**: O(1) dict read; Tier-2 `legal_targets_from` batch is O(|reachable| × candidate targets) once per `PREVIEW_MOVE` entry (bounded by N≤24); the Cancel-Build `_process` poll is a bounded ~500 ms window, not a steady-state per-frame cost — source: ADR-0015
- **HUD render**: event-driven, not `_process`-polled; N events from one commit coalesce to ≤1 redraw per frame; `ApCounterFsm.next_state` is O(1); log append O(1) amortized — source: ADR-0016

### Engine API Constraints
- **`TileMapLayer.local_to_map()` has a documented accuracy bug for isometric tile shapes (GH#89423), confirmed via WebSearch — mandates the custom inverse, not optional caution** — source: ADR-0013
- **`TileSet.TILE_SHAPE_ISOMETRIC` and `Node2D.y_sort_enabled` are pre-4.0-cutoff stable APIs; engine spike CLEARED 2026-07-25 confirming seamless diamond tiling and correct `y_sort_enabled` draw-order flips across a tall prop's row** — source: ADR-0013
- **`z_index` is the coarse cross-tree sort key; `y_sort_enabled` only re-sorts within a Y-sort group at the same effective z-index — a Y-sorted child cannot escape its parent's z-index band. `CanvasGroup` is irrelevant to depth-sort (material compositing only)** — source: ADR-0013
- **`Control.grab_click_focus()` (mouse-click focus, distinct from `grab_focus()`) and dual-focus `focus`/`hover` StyleBox slots are 4.6 APIs, confirmed present via direct `ClassDB` introspection of the Redot 26.2 binary** — source: ADR-0014
- **Godot dispatches input top-down; a focused `Control` consumes an event in the GUI pass (`_gui_input`), marking it handled so it never reaches `_unhandled_input` — this IS the arbitration between `BoardCursor` and menu focus (engine spike CLEARED 2026-07-25, including asymmetric keyboard-focus-only vs mouse-hover-only cases)** — source: ADR-0014
- **`Control.FOCUS_CLICK` is skipped by keyboard/gamepad traversal while allowing mouse-click focus (engine spike CLEARED 2026-07-25)** — source: ADR-0014
- **`create_timer()`'s `process_always` parameter defaults to `true` — a lock timer runs even against a paused tree** — source: ADR-0014
- **The Godot 4.5 "recursive Control disable" feature's exact property identifier is NOT confirmed against this project's engine-reference corpus — verify the exact identifier before any story cites it** — source: ADR-0014
- **The Cancel-Build hold uses a `_process`-delta accumulator + `Input.is_action_pressed` poll (both stable ≤4.3) rather than `create_timer`, for free early-release detection** — source: ADR-0015
- **`InputEventMouseMotion`/`event.position` handling is unchanged since ≤4.3 and unaffected by the 4.6 dual-focus split (which changes `Control` focus routing only, not raw event delivery to a plain `Node`)** — source: ADR-0015
- **Godot auto-drops signal connections to freed objects; explicit `disconnect` in `_exit_tree()` is only needed if `GameState` is reused across a match restart within one process** — source: ADR-0015
- **`queue_redraw()` coalesces N calls within one frame into exactly one `_draw()` — confirmed unchanged for 4.6, preferred over a hand-rolled `_process` dirty-flag poll** — source: ADR-0016
- **`AudioStreamPlayer.play()`, `Control` focus APIs, and `_process` redraw are all stable ≤4.3 or already validated — no new post-cutoff API introduced by the HUD** — source: ADR-0016

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `UnitController` |
| Variables/functions | snake_case | `move_speed`, `end_turn()` |
| Signals/Events | snake_case, past tense | `turn_ended`, `unit_moved` |
| Files | snake_case matching class | `unit_controller.gd` |
| Scenes | PascalCase matching root node | `UnitController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_ACTION_POINTS` |

> Use static typing in GDScript (`var hp: int = 10`) — it catches bugs and is meaningfully faster in the tight loops a turn-based AI hits.

### Performance Budgets
| Target | Value |
|--------|-------|
| Target Framerate | 60 FPS |
| Frame Budget | 16.6 ms/frame |
| Draw Calls | < 500 (generous for 2D isometric; TileMap batching should keep this low) |
| Memory Ceiling | TO BE CONFIGURED — set when target hardware is known |

> Turn-based means no hard real-time simulation deadline — 60 FPS is for smooth camera/UI feel.

### Approved Libraries / Addons
- **GDUnit4** — approved test framework (addon); run via `./redot --headless --script tests/gdunit4_runner.gd`
- No other third-party libraries configured yet — add as dependencies are approved.

### Forbidden APIs (Godot 4.6 / Redot 26.2)
These APIs are deprecated for this engine version; if suggested they MUST be replaced with the "Use Instead" form. Source: `docs/engine-reference/godot/deprecated-apis.md`.

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` / `VisibilityNotifier3D` | `VisibleOnScreenNotifier2D` / `3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

Deprecated **patterns** (not just APIs): String-based `connect()` → typed signal connections; `$NodePath` in `_process()` → `@onready var` cached reference; untyped `Array`/`Dictionary` → `Array[Type]`/typed vars; `Texture2D` in shader parameters → `Texture` base type (4.4); manual post-process viewport chains → `Compositor` + `CompositorEffect` (4.3+); GodotPhysics3D for new projects → Jolt (4.6 default — N/A here, project is 2D-only).

### Cross-Cutting Constraints
- **`apply_action` is the sole mutation vector for `GameState`** — a system must never write `GameState`/`PlayerState`/`EntityState`/`GridState` fields directly — source: ADR-0001, ADR-0002
- **No RNG anywhere except the single sanctioned seeded map-gen `RandomNumberGenerator`** — global `randi()`/`randf()`/`randi_range()`/`randf_range()`/`randomize()`/`seed()` are banned project-wide (CI greps for them) — source: ADR-0003
- **No float in any state field, ever** — all state is `int`/`enum`/`Vector2i`; fractional coefficients are scaled integers with integer ceil/floor-division; floats allowed only in AI advisory scoring (never written to state) and pure presentation (animation) — source: ADR-0003
- **All order-sensitive iteration must use a stable, data-derived key (`entity_id` or tile index) — never Dictionary hash/insertion order** — source: ADR-0003
- **Config Resources (`*Config extends Resource`) are load-time-only, must never be mutated at runtime, and must never be stored on `GameState` (would be deep-copied on every AI clone)** — source: ADR-0006
- **Type identity for any registry-backed data (unit types, structure types, techs, factions) must use Resource-reference equality via `preload()`'d consts — never a parallel enum, never a runtime `load()`** — source: ADR-0007, ADR-0012, ADR-0018
- **A bare `assert()` is stripped from Godot release exports — any invariant that must hold in a shipped build requires a release-surviving guard (`push_error()` + a hard failure/clamp), never a bare `assert()`** — source: ADR-0011, ADR-0016
- **Pure game-logic classes (`GameState`, `AP`, `Movement`, `Combat`, `BaseProduction`, `Research`, `AI`, `CommandFSM`, `ApCounterFsm`, `BoardCursor`) must be headless-testable with zero scene tree — no `Node` dependency** — source: ADR-0001, reinforced by ADR-0009/0010/0011/0014/0015/0016/0017/0018
- **Dependency injection over singletons — no game-logic class may become an Autoload-coupled singleton that resists unit testing; the only Autoloads permitted are thin, logic-free lookup/config holders (`MatchService`, `Balance`)** — source: ADR-0001, `.claude/docs/coding-standards.md`
- **Gameplay values must be data-driven (external `.tres` Resource config), never hardcoded GDScript `const`s** — source: `.claude/docs/coding-standards.md`, reinforced by ADR-0006/0007/0009/0010/0011/0012/0016/0017
- **Static GDScript typing is required throughout game-logic code** — source: `technical-preferences.md`
- **No hover-only interactions — every core action reachable by mouse must also be reachable by keyboard/gamepad (keeps a gamepad/cursor port feasible)** — source: `technical-preferences.md`, enforced by ADR-0014
- **`ripgrep` has no `gdscript` type: `*.gd` is registered under `gap`, so `rg --type gdscript` is a hard error — always use `rg --glob "*.gd"` (or the Grep tool's `glob: "*.gd"`)** — source: `docs/engine-reference/godot/current-best-practices.md`
- **Engine knowledge-gap warning: the LLM's training covers Godot up to ~4.3; 4.4–4.6 introduced changes the model does not know by default — always cross-reference `docs/engine-reference/godot/` before suggesting an API call** — source: `docs/engine-reference/godot/VERSION.md`

---

## Rule Counts
- **Foundation**: 66 required, 39 forbidden, 10 guardrails
- **Core**: 63 required, 13 forbidden, 8 guardrails
- **Feature**: 30 required, 9 forbidden, 5 guardrails
- **Presentation**: 55 required, 18 forbidden, 6 guardrails
- **Global**: 6 naming conventions, 14 forbidden APIs (+6 deprecated patterns), 1 approved library (GDUnit4)
