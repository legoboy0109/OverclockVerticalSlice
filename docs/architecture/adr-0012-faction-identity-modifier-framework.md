# ADR-0012: Faction Identity Modifier Framework (FactionDef, effective_X Resolution, Setup Lifecycle)

## Status
Accepted

## Date
2026-07-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Redot 26.2 (Godot 4.6-compatible fork) |
| **Domain** | Core (data model + effective-value resolution) |
| **Knowledge Risk** | LOW — this is a pure data/rules layer (a `Resource` schema + integer clamp arithmetic + a preload'd registry). It reuses the exact `duplicate_deep()` / preload'd-path-having-Resource mechanics ADR-0001/0007 already validated against live 4.6 docs; it introduces no new engine API and no post-cutoff surface. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; `design/gdd/faction-identity.md` (full); `docs/architecture/adr-0001`, `adr-0003`, `adr-0006`, `adr-0007`, `adr-0008`, `adr-0010`, `adr-0011` |
| **Post-Cutoff APIs Used** | None. `duplicate_deep()` (4.5) is reused via ADR-0001's already-validated clone path; `preload()` into registry consts is ADR-0007's already-validated pattern. |
| **Verification Required** | None net-new. The load-bearing engine claim (a path-having preload'd `FactionDef` is *shared* by reference, not deep-copied, on `GameState.clone()`) is the *same* finding ADR-0007 already had the godot-specialist confirm against `core/io/resource.cpp` — this ADR reuses it, it does not re-open it. **godot-specialist 2026-07-24 raised one blocking schema issue — resolved pre-write**: the initial draft used untyped `Resource`-keyed `Dictionary` delta tables (violates the typed-collections standard + a fragile `.tres`/inspector-authoring corner); reworked to typed `Array[FactionUnitDelta]`/`[FactionStructureDelta]`/`[FactionTechDelta]` entry sub-resources (§1) — fully typed, Resource-ref identity preserved, idiomatic inspector authoring. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`PlayerState` — this ADR adds the `faction` field + the `faction_of(player)` accessor already named in the GameState read API; `clone()` carries it), ADR-0003 (determinism — `FactionDef` is fixed data, no per-match RNG; every effective value is integer arithmetic), ADR-0006 (`credit_income` — `effective_credit_income` folds faction income deltas into the Credit income formula; `gameplay_config_storage`/registry-const precedent), ADR-0007 (`entity_stat_template_storage` — the preload'd-registry + Resource-reference-identity pattern `FactionDef`/`Factions` reuses; the forward-declared-`effective_X` pattern), ADR-0010 (`effective_attack` — the existing effective-value site faction combat deltas extend, identity-locked in the VS), ADR-0011 (AI reads `effective_X` via the shared sites with `player` as an argument; the `is_ai_controlled` Setup-lock precedent this ADR's `faction` field mirrors) |
| **Enables** | The Faction Identity epic (framework + Neutral baseline); the faction-asymmetry prototype runs against this framework. The AI reads faction-correct costs with zero AI-code change (ADR-0011). |
| **Blocks** | Faction epic implementation; the effective-value fold-ins owed to Unit/AP/Base & Production/Research (this ADR forward-declares them). Not a hard blocker on any Presentation ADR (no overlap). |
| **Ordering Note** | The last of the 16-ADR plan; the only Feature-layer ADR besides ADR-0011. **Owed-but-deferrable** (game-hud/faction GDDs): under the VS's Neutral-vs-Neutral default every delta is identity, so only the `PlayerState.faction` plumbing + Neutral `FactionDef` are needed for a playable VS — the effective-value fold-ins + owed floors land alongside the asymmetry prototype, not before. This ADR fixes *what a faction may modify and how*, matching the GDD's framework-only scope (Rush/Boom values stay prototype-gated). |

## Context

### Problem Statement
`faction-identity.md` is the modifier framework making each faction "a distinct way to spend AP,"
not a reskin (Pillar 4). It is fully designed as a **framework-only** GDD (Rush/Boom asymmetry
values are prototype-gated), but its architecture is unresolved: (1) what `FactionDef` concretely is
and how "a faction is data, not logic" (CR-1) is enforced structurally; (2) the closed 6-domain
schema and how an out-of-domain field is rejected (CR-2); (3) the `effective_X` resolution pattern —
where faction deltas fold in, the signature, the per-domain floors, and how it composes with
ADR-0010's already-forward-declared `effective_attack` (CR-4); (4) the two-sided `production_cap`
inert invariant (Formulas 4c); (5) faction persistence, the setup FSM, starting-loadout placement,
and clone survival (States); (6) the Neutral zero-behavior-change guarantee (CR-6); (7) orphaned-delta
inertness (Edge Cases); (8) the `faction_hue` + `faction_pattern_id` schema (Visual/Audio); (9) the
AI reading `effective_X` via the shared sites (Dependencies).

### Constraints
- Static GDScript typing (`.claude/docs/technical-preferences.md`).
- **A faction is data, not logic** (CR-1): `FactionDef` is a pure data `Resource` — numbers + enum
  flags, no executable behavior, no `_process`.
- **Closed 6-domain schema** (CR-2): a `FactionDef` may modify *only* unit cost, unit mobility,
  income-curve params, structure cost/time/cap, tech access/cost, and starting loadout — nothing else.
- **Pillar 1 invariant** (CR-3): a faction may only re-cost/re-time/re-scale actions *already priced
  in AP* — never a second resource, a 0-AP version of a paid verb, a new verb, or a value outside CR-2.
- **Live modifier resolution, no base mutation** (CR-4): faction deltas fold in *at each owning
  system's read site*; the base registry values are never rewritten.
- **Determinism** (CR-7, ADR-0003): `FactionDef` is fixed data applied identically every match; no
  per-match randomization; every effective value is integer arithmetic (faction deltas are `int`).
- **Additive, never multiplicative** (Formulas): integer-AP is a hard invariant — a faction delta is
  an additive `int`, never a `×` factor (a ×0.8 breaks integer-AP).
- **Faction never owns a base value or formula** — it is a modifier *provider*, the same discipline
  the AI and Command & Action Interface follow.

### Requirements
- `FactionDef` as a data-only, statically-typed `Resource` with exactly the 6 CR-2 domains, rejecting
  out-of-schema fields at load (TR-faction-001/002).
- `effective_X(state, base_owner, player)` functions on the owning systems folding faction deltas
  with per-domain floors (TR-faction-003/004/005/007), including the two-sided `production_cap`
  invariant (TR-faction-006).
- `PlayerState.faction` persistence, the setup FSM, one-time loadout placement, and clone survival
  (TR-faction-008/009/010).
- `effective_X == base_X` exactly under Neutral (TR-faction-011).
- Orphaned-delta inertness + load warning (TR-faction-012).
- `faction_hue` + reserved `faction_pattern_id` schema handles (TR-faction-013).
- The faction-picker UI contract (TR-faction-014).
- AI reads `effective_X` via the shared sites, no AI-only branch (TR-faction-015).

## Decision

### 1. `FactionDef` — a data-only `Resource`, closed 6-domain schema (TR-faction-001/002/013)

Per-entity deltas are authored as **typed arrays of tiny entry sub-resources** (each keyed by a
Resource-reference `type`, preserving ADR-0007's Resource-ref identity) rather than
`Resource`-object-keyed `Dictionary`s — the idiomatic, fully-typed, inspector-authorable shape that
sidesteps the fragile Resource-key `.tres` serialization corner (godot-specialist, 2026-07-24):

```gdscript
# faction_unit_delta.gd — one entry per modified unit type (domains 1, 2a, 2b, + combat)
class_name FactionUnitDelta extends Resource
@export var type: UnitTypeDef = null                  # Resource-ref identity (ADR-0007)
@export var cost_delta: int = 0                       # domain 1 (produce_cost)
@export var move_cost_delta: int = 0                  # domain 2a
@export var soft_move_cap_delta: int = 0              # domain 2b
@export var combat_delta: FactionCombatDelta = null   # {hp,atk,range} — SCHEMA-PRESENT, identity-LOCKED for VS (CR-6); null = identity

# faction_structure_delta.gd — one entry per modified structure type (domain 4)
class_name FactionStructureDelta extends Resource
@export var type: StructureTypeDef = null
@export var cost_delta: int = 0                       # build_cost
@export var time_delta: int = 0                       # build_time
@export var cap_delta: int = 0                        # production_cap

# faction_tech_delta.gd — one entry per modified tech (domain 5)
class_name FactionTechDelta extends Resource
@export var tech: TechDef = null
@export var cost_delta: int = 0                       # research_cost
@export var time_delta: int = 0                       # research_time
@export var denied: bool = false                      # domain 5c: faction_allows = NOT denied

# faction_def.gd — pure data, NO logic (CR-1)
class_name FactionDef extends Resource

@export var faction_name: StringName = &"Neutral"
@export var faction_hue: Color = Color.WHITE          # at-a-glance ownership tint (art bible owns values)
@export var faction_pattern_id: StringName = &"none"  # RESERVED non-hue redundant identity handle (colorblind fallback, TR-faction-013) — asset deferred to /art-bible, field required non-empty

# --- the closed 6-domain modifier set (CR-2); every delta is int, 0 = identity ---
@export var unit_deltas: Array[FactionUnitDelta] = []        # domains 1 / 2a / 2b / combat
@export var base_income_delta: int = 0                        # domain 3 intercept lever
@export var outpost_tier1_delta: int = 0                      # domain 3 slope lever
@export var outpost_tier2_delta: int = 0                      # domain 3 slope lever
@export var structure_deltas: Array[FactionStructureDelta] = []  # domain 4 (build_cost/time/cap)
@export var tech_deltas: Array[FactionTechDelta] = []            # domain 5 (research_cost/time/availability)
@export var starting_loadout: FactionLoadout = null          # domain 6: starting AP + units + structures
```

The schema is exactly the 6 CR-2 domains (+ the two identity handles). **"Data, not logic" is
structural**: `FactionDef` (and its entry sub-resources) extend `Resource` with only `@export` data
fields and no methods beyond trivial getters — a schema/lint check (candidate CI, TR-faction-001)
asserts it declares no `_process` and no logic. **Out-of-domain fields are rejected at load**
(TR-faction-002): the loader validates a `FactionDef`'s exported field set against this closed list
and fails on any extra field. Both identity handles (`faction_hue`, `faction_pattern_id`) are
required non-empty (TR-faction-013). *(Note: `starting_loadout`, if inlined as an anonymous sub-
resource inside a `FactionDef` `.tres`, is itself path-less and would be deep-copied on `clone()` —
harmless, because `PlayerState.faction` holds the `FactionDef` reference [shared, §2] not the
loadout, and the loadout is read once at Setup, never on the AI's per-candidate clone path.)*

### 2. Storage: preload'd `Factions` registry consts, Resource-reference identity (reuses ADR-0007)

```gdscript
# factions.gd — thin logic-free registry Autoload (mirrors UnitTypes/StructureTypes/Techs, ADR-0007)
const NEUTRAL: FactionDef = preload("res://data/factions/neutral.tres")
const RUSH: FactionDef    = preload("res://data/factions/rush.tres")
const BOOM: FactionDef    = preload("res://data/factions/boom.tres")
```

Faction identity is answered by **Resource-reference equality** (`player_faction == Factions.RUSH`),
exactly as ADR-0007 answers "which type is this." **Because each `FactionDef` is a path-having
preload'd Resource, `GameState.clone()`'s `duplicate_deep()` SHARES it by reference — it does not
deep-copy it** (ADR-0007's confirmed `core/io/resource.cpp` `is_built_in()` gating). So `PlayerState.
faction` survives `clone()` at **zero cost** and every clone's faction is the *same* `FactionDef`
object as the authoritative state's — satisfying TR-faction-008's "clone() deep-copies faction"
requirement structurally (the reference is carried; the shared target is correct precisely because it
is immutable data). No parallel `enum FactionKind` discriminator (rejected — same reasoning ADR-0007
declined the enum: loses inspector authoring + the clone-sharing guarantee).

### 3. `effective_X` resolution: owning systems fold the faction delta at their read site (TR-faction-003/004/005/007)

Faction is a **modifier provider**; each owning system exposes an `effective_X(state, base_owner,
player)` that folds the acting player's faction delta into its own base value with a per-domain floor
(CR-4). Faction never owns a base value. A tiny static helper centralizes the delta lookup + the
orphaned-key inertness (§5):

```gdscript
# faction.gd — static helper (no instance state); NOT an owner of any base value
class_name Faction extends RefCounted

static func of(state: GameState, player: int) -> FactionDef:
    return state.player_states[player].faction   # == GameState.faction_of(player)

## Returns the FactionUnitDelta entry for `type`, or null if absent/orphaned — centralizes
## TR-faction-012 inertness (a missing entry contributes 0). Linear scan over a roster-sized
## typed array (<=4 units / 5 structures / few techs; Neutral's arrays are empty -> instant miss).
static func unit_delta(f: FactionDef, type: UnitTypeDef) -> FactionUnitDelta:
    for d in f.unit_deltas:
        if d.type == type: return d
    return null   # orphaned/absent -> caller treats as 0 (inert)
# structure_delta(f, type) / tech_delta(f, tech) analogous.
```

Each owning system's `effective_X` then folds faction alongside any existing delta term (reading the
entry's field, or 0 when the entry is null — orphaned-inert). The pattern **extends ADR-0010's
`effective_attack`** rather than adding a new resolution site:

```gdscript
# Unit system (extends ADR-0010's forward-declared effective_attack; `d` = Faction.unit_delta(f, type)):
effective_attack(state, attacker) = base_attack(type) + (RESEARCH_ATK_BONUS if has_attack_tech else 0)
                                  + (d.combat_delta.atk if d and d.combat_delta else 0)   # 0 in VS (CR-6 lock)
effective_produce_cost(state, unit_type, player) = max(1, base_produce_cost(type) + (d.cost_delta if d else 0))
effective_move_cost(state, unit_type, player)    = max(MIN_MOVE_COST, base_move_cost(type) + (d.move_cost_delta if d else 0))
effective_soft_move_cap(state, unit_type, player)= max(1, base_soft_move_cap(type) + (d.soft_move_cap_delta if d else 0))
# AP & Credits Economy (folds into the EXISTING 4-term CREDIT income formula, preserving the econ-tech term + its cap — TR-faction-004):
# (economy pivot: income deltas now fold into Credit income — effective_ap_income renamed effective_credit_income)
effective_credit_income(state, player) = max(BASE_INCOME_FLOOR, (BASE_INCOME + f.base_income_delta)
    + (OUTPOST_BONUS_TIER1 + f.outpost_tier1_delta)·min(n,T) + (OUTPOST_BONUS_TIER2 + f.outpost_tier2_delta)·max(0,n−T)
    + econ_tech_term)   # econ_tech_term carried VERBATIM from ADR-0006; factions never touch it or ECONOMY_TECH_TIER_THRESHOLD
# Base & Production (TR-faction-005) + Research (TR-faction-007) analogously, each with its domain floor.
```

The floors (`max(1,…)`, `max(MIN_MOVE_COST,…)`, `max(MIN_BUILD_TIME,…)`, `max(MIN_RESEARCH_TIME,…)`,
`BASE_INCOME_FLOOR`) enforce CR-3's "never a free/0-cost verb." **`MIN_MOVE_COST` already exists**
(Movement's Approved `move_cost ≥ 1`); the other three floors are one-line additions owed to the
owning GDDs, load-bearing only once a subtractive delta ships (all no-ops under Neutral). These
`effective_X` functions are **forward-declared** to Unit/AP/Base & Production/Research — the same
forward-declaration pattern ADR-0006→0007 and ADR-0010 used.

### 4. The two-sided `production_cap` inert invariant — branch on base-cap sign (TR-faction-006)

```gdscript
effective_production_cap(state, structure_type, player):
    var base_cap := base_production_cap(structure_type)
    if base_cap == 0:
        return 0                                              # base non-producer (Lab / Defensive) — delta INERT, cannot manufacture a producer (CR-3 (c))
    var sd := Faction.structure_delta(Faction.of(state, player), structure_type)
    return max(1, base_cap + (sd.cap_delta if sd else 0))     # base producer — floor 1, never zeroed (no asymmetric verb-deletion)
```

This is **not** a single clamp — it branches on the sign of the base cap. A faction `production_cap`
delta may move a cap only *within* the producing range `[1, ∞)`; it never crosses the
produces/doesn't-produce boundary in **either** direction (may not zero a base-positive cap →
asymmetric verb-deletion; may not raise a base-zero cap → manufacturing a withheld verb). The base
cap-0 (Research Lab / Defensive Structure) stays a *symmetric* base-game property, never a faction
lever.

### 5. Orphaned-delta inertness (TR-faction-012) + Neutral regression pin (TR-faction-011)

- **Orphaned deltas**: a `FactionUnitDelta`/`FactionStructureDelta`/`FactionTechDelta` whose `type`/
  `tech` no longer exists in the base roster is silently inert — `Faction.unit_delta()` (etc.) simply
  never matches it, so its contribution is 0 with no runtime error (AC-21). An orphaned
  `starting_loadout` reference is a *different* code path (setup placement, AC-20): a loadout entry
  referencing a removed type is skipped inert. Both log a load-time schema warning (a validation pass
  scans the entry arrays + loadout against the live roster at load). Factions degrade to "no modifier
  for the missing entity," never hard-break on a base-roster change.
- **Neutral regression pin (TR-faction-011)**: `Neutral`'s entry arrays are empty and its income
  scalars are 0 (`starting_loadout` = the base default), so `effective_X(state, base_owner,
  neutral_player) == base_X` **exactly** for every domain (the floors never bind because every Approved base value
  already sits at/above its floor). A parametrized unit test reads the base tables directly and
  asserts equality — the critical CR-6 invariant that Neutral-vs-Neutral changes nothing the whole
  corpus is balanced around. This is Logic-typed and runs against the data tables (no playable build).

### 6. Setup lifecycle: `PlayerState.faction`, set at commit, locked at Setup→PlayerTurn (TR-faction-008/009/010)

**`PlayerState` (ADR-0001) gains a `faction: FactionDef` field** — Setup-locked, immutable after the
Setup→PlayerTurn transition, the **same lock as `is_ai_controlled`** (ADR-0011; the registry already
cites "same lock as `PlayerState.faction`"). ADR-0001 is not edited here — a follow-up adds the field
+ backref, exactly as ADR-0011 did for `is_ai_controlled`.

The picker's setup FSM (`UNASSIGNED → SELECTING → ASSIGNED → LOCKED`) is a **setup-UI lifecycle**; the
*authoritative* lock is the field's immutability:
- **SELECTING**: a highlighted candidate is *previewable* (starting loadout viewable, AC-28) — **no
  board placement** occurs. Re-highlighting stays in SELECTING (pre-lock re-pick).
- **SELECTING → ASSIGNED** (confirm): `faction_of(player)` is set and the `starting_loadout` is placed
  **exactly once**, before Setup→PlayerTurn completes, validated against legal setup tiles (a
  malformed loadout is rejected at load, not a runtime crash — AC-19/26). Non-Neutral factions pass an
  explicit "unvalidated values" acknowledgment on this transition (AC-27); Neutral needs none.
- **ASSIGNED → LOCKED** (Setup→PlayerTurn): faction is immutable for the match; a second assignment
  attempt is rejected/no-op (AC-22). No mid-match switch code path exists.

Setup ownership (assignment + one-time loadout placement + the lock) sits with the Turn Manager /
`start_match()` (ADR-0001/0008's Setup→first-PlayerTurn boundary) — faction is one more thing
`start_match()` finalizes before the first `start_turn()`.

### 7. AI reads `effective_X` via the shared sites, no AI-only branch (TR-faction-015)

Because every `effective_X` takes `player` as an argument (§3), the AI passing `ai_player` gets
faction-correct costs/income **automatically, with zero AI code change** (ADR-0011; AC-24). The
"no AI-only branch" claim is a code-shape property routed to a static check (the AI's cost/income
call sites invoke the shared `effective_X`, never an AI-local recompute) — the same static-allowlist
discipline ADR-0011 established. **Forward-flag to ADR-0011 (OQ-7):** once real Rush/Boom deltas
exist, (a) any future AI cost cache must key on `player` (not just `base_owner`, since `effective_X`
is a function of both), and (b) a Rush `economy_outpost.build_cost` discount raises the AI's
`economy_ceiling_score` and can re-open the Neutral-tuned `LETHAL_FLOOR_BONUS > economy_ceiling_score`
invariant (ADR-0011) *along the faction axis* — must be re-verified with the asymmetry prototype.
Both are no-ops under Neutral.

### Architecture Diagram

```
   FactionDef (.tres, data-only)          Factions registry (preload'd consts)
        │  6-domain int deltas                  NEUTRAL / RUSH / BOOM
        │  + faction_hue + faction_pattern_id        │  Resource-ref identity
        └────────────────────┬───────────────────────┘
                             ▼
              PlayerState.faction (ADR-0001 field, Setup-locked; survives clone()
              as a shared path-having Resource — zero clone cost, ADR-0007)
                             │  faction_of(player)
                             ▼
   Owning systems' effective_X(state, base_owner, player) ── fold Faction.{unit,structure,tech}_delta(...) at each read site:
     Unit: effective_produce_cost/move_cost/soft_move_cap/attack(+faction combat, id-locked)
     Credits: effective_credit_income (into the 4-term Credit income formula, econ-tech term preserved)
     B&P:  effective_build_cost/build_time/production_cap (two-sided inert invariant)
     Research: effective_research_cost/research_time + faction_allows tech gate
                             │  all clamped to their domain floor
                             ▼
   Every consumer (Command & Action preview, HUD, AI, Combat) reads effective_X —
   Neutral => effective_X == base_X exactly (zero corpus behavior change)
```

### Key Interfaces

```gdscript
# faction_def.gd — class_name FactionDef extends Resource (data-only, §1)
# factions.gd — registry consts NEUTRAL/RUSH/BOOM (preload'd, §2)
# faction_unit_delta.gd / faction_structure_delta.gd / faction_tech_delta.gd — typed entry Resources (§1)
# faction.gd — class_name Faction extends RefCounted (static helper, §3):
static func of(state: GameState, player: int) -> FactionDef
static func unit_delta(f: FactionDef, type: UnitTypeDef) -> FactionUnitDelta          # null if absent/orphaned (inert)
static func structure_delta(f: FactionDef, type: StructureTypeDef) -> FactionStructureDelta
static func tech_delta(f: FactionDef, tech: TechDef) -> FactionTechDelta

# PlayerState (ADR-0001) gains:
@export var faction: FactionDef = null   # Setup-locked, immutable after Setup->PlayerTurn (like is_ai_controlled)

# Forward-declared effective_X to the owning systems (§3):
#   Unit:     effective_produce_cost / effective_move_cost / effective_soft_move_cap (+ faction term in effective_attack)
#   Credits:  effective_credit_income
#   B&P:      effective_build_cost / effective_build_time / effective_production_cap (two-sided, §4)
#   Research: effective_research_cost / effective_research_time / faction_allows
```

## Alternatives Considered

### Alternative A (composition): owning system owns effective_X, faction is one more folded term — CHOSEN
- **Pros**: Faction stays a pure modifier provider (owns no base value, CR-4); extends ADR-0010's
  existing `effective_attack` pattern rather than adding a parallel resolution site; the AI/HUD/preview
  all read one `effective_X` per domain regardless of how many delta sources exist (research + faction).
- **Cons**: N `effective_X` functions forward-declared across 4 systems (a broad but shallow contract).
- **Rejection Reason**: n/a (chosen).

### Alternative B: a central `Faction.effective_X` computing every domain
- **Cons**: Faction would have to read (and effectively own) base values from 5 systems, breaking the
  "modifier provider, never owns a base value" discipline (CR-4) and re-accreting cross-system logic
  onto faction — the exact coupling ADR-0006/0010's owning-system-owns-effective_X pattern avoids.
- **Rejection Reason**: Rejected per explicit decision this session.

### Alternative C: `enum FactionKind` + const Dictionary of deltas
- **Cons**: Deltas become hardcoded GDScript consts (violating the data-driven standard — designers
  can't author/tune a faction without touching code); loses Resource authoring and the clone-sharing
  guarantee. Parallels the `enum` discriminator ADR-0007 explicitly rejected for entity types.
- **Rejection Reason**: Rejected per explicit decision this session — Resource-ref identity, mirroring
  `entity_stat_template_storage`.

### Alternative (delta authoring shape): `Resource`-object-keyed `Dictionary` delta tables
- **Description**: author per-entity deltas as `Dictionary[UnitTypeDef, int]` keyed by the type Resource.
- **Cons**: `Resource`-object keys are a fragile `.tres` serialization corner (ExtResource-keyed
  entries work but are a less-battle-tested shape than value-position refs) and the inspector's
  Dictionary editor handles non-primitive keys poorly — a bad authoring experience for designers
  tuning Rush/Boom (godot-specialist, 2026-07-24). The untyped `Dictionary` form additionally violates
  the project's typed-collections standard.
- **Rejection Reason**: Rejected per explicit decision this session — typed `Array[Faction*Delta]`
  entry sub-resources (§1) keep Resource-ref identity while being fully typed and cleanly
  inspector-authorable, sidestepping the Resource-key corner entirely.

### Alternative (production_cap): a single symmetric `max(0, base + Δ)` clamp
- **Cons**: Fails both halves of the two-sided invariant — a single `max(0,…)` lets a faction zero a
  base-positive producer (asymmetric verb-deletion) AND does nothing to stop a delta raising a
  base-zero cap (manufacturing a withheld verb). The GDD requires branching on the base-cap sign.
- **Rejection Reason**: Rejected — TR-faction-006 mandates the two-sided branch, not a single clamp.

## Consequences

### Positive
- Under Neutral (the VS default) every `effective_X == base_X` exactly, so the entire corpus's
  balance is untouched — the framework is provably inert until a real delta ships (TR-faction-011).
- Faction survives `clone()` at zero cost as a shared preload'd Resource — the AI's lookahead never
  pays to copy faction data, and every clone reads the same immutable `FactionDef` (ADR-0007's finding
  reused, not re-derived).
- The AI plays any faction correctly-costed with zero AI code change (every `effective_X` takes
  `player`).
- The two-sided `production_cap` invariant forecloses both asymmetric verb-deletion and verb-creation
  by *rule*, resolving the GDD's CR-3-borderline concern without a per-faction review.
- Reserving `faction_pattern_id` now closes the 4×-recurring colorblind gap at the schema level — no
  downstream consumer ships an hue-only identity path needing a later retrofit.

### Negative
- N `effective_X` functions are forward-declared across 4 owning systems + 3 floors owed to their
  GDDs (`BASE_INCOME_FLOOR`/`MIN_BUILD_TIME`/`MIN_RESEARCH_TIME`) — a broad contract, though every
  piece is a no-op under Neutral and lands with the asymmetry prototype (owed-but-deferrable).
- `PlayerState.faction` is a follow-up field on ADR-0001 (like `is_ai_controlled`) — a coordination
  note, not a re-open.
- Rush/Boom values are prototype-gated — this ADR fixes the framework shape, not the balance; the
  aggregate cross-domain power-budget (OQ-10) and per-stat saturation (OQ-4) are prototype concerns,
  not architecture this ADR can resolve.

### Risks
- **The `effective_X` fold-ins are owed to 5 GDDs that don't yet list Faction as a dependent**
  (reciprocity gap, GDD OQ-6) — closed via `/propagate-design-change`, deferrable because Neutral
  makes them no-ops. Named so the propagation isn't lost.
- **A faction income delta stacks a third per-`n` term onto the base×tech curve** — the same
  unbounded-stacking failure AP & Credits Economy already caught once (econ-tech term). The GDD's combined-income-
  ceiling rule (any non-zero income delta re-validated against AP & Credits Economy's `n`-swept ceiling model,
  combined ceiling re-approved as a single number) is a *validation-discipline* obligation owed at the
  first real income delta — no-op under Neutral, flagged here so the asymmetry prototype honors it.
- **Combat-stat deltas are schema-present but identity-locked** (`unit_combat_delta`, CR-6). If the
  asymmetry prototype finds tempo-only asymmetry insufficient for Pillar 4 (GDD OQ-9), unlocking them
  is a framework-shape change requiring a fresh `/design-review` — not something this ADR pre-authorizes.
- **The two identity handles' *values* are art-bible-owed** — this ADR reserves the fields
  (`faction_hue`, `faction_pattern_id`) non-empty but sets no palette/pattern art.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| faction-identity.md | TR-faction-001: FactionDef data-only Resource, loaded at setup; lint asserts no logic | §1 (`extends Resource`, `@export`-only, no `_process`; schema/lint check) |
| faction-identity.md | TR-faction-002: schema exposes exactly 6 CR-2 domains, reject out-of-set field at load | §1 (closed schema; loader rejects extra fields) |
| faction-identity.md | TR-faction-003: effective_produce_cost/move_cost/soft_move_cap fold faction delta, floors | §3 (Unit effective_X with `max(1,…)`/`max(MIN_MOVE_COST,…)`) |
| faction-identity.md | TR-faction-004: effective_credit_income folds Δ into the 4-term Credit income formula, floored, preserves econ-tech term+cap | §3 (Credits `effective_credit_income`, econ-tech term carried verbatim from ADR-0006) |
| faction-identity.md | TR-faction-005: effective_build_cost/build_time/production_cap, floors | §3 (B&P effective_X) + §4 (production_cap) |
| faction-identity.md | TR-faction-006: production_cap two-sided inert invariant, branch on base-cap sign not single clamp | §4 (explicit `if base_cap == 0: return 0` else `max(1,…)`) |
| faction-identity.md | TR-faction-007: effective_research_cost/time/tech_available(faction_allows), floors + AND-gate | §3 (Research effective_X + `faction_allows` = NOT the tech's `FactionTechDelta.denied` flag) |
| faction-identity.md | TR-faction-008: Turn Manager persists faction_of full match, set at SELECTING→ASSIGNED, immutable (LOCKED); clone() deep-copies faction | §6 (`PlayerState.faction`, Setup-locked) + §2 (survives clone() as shared preload'd Resource) |
| faction-identity.md | TR-faction-009: apply starting_loadout once at SELECTING→ASSIGNED before Setup→PlayerTurn; placement validation | §6 (one-time placement at confirm, legal-tile validation, AC-19/26) |
| faction-identity.md | TR-faction-010: SELECTING sub-state, re-highlight preview + acknowledgment-gated confirm for non-Neutral | §6 (SELECTING preview, no placement; AC-27 ack on confirm for non-Neutral) |
| faction-identity.md | TR-faction-011: zero behavior change when all deltas 0 (Neutral): effective_X == base_X exactly | §5 (Neutral regression pin, parametrized test) |
| faction-identity.md | TR-faction-012: orphaned deltas inert + load warning; orphaned loadout vs numeric delta | §5 (an orphaned entry never matches in the scan → contributes 0; two code paths: loadout ref vs numeric-delta entry; load-time warning) |
| faction-identity.md | TR-faction-013: schema declares faction_hue + reserved faction_pattern_id, both non-empty | §1 (both handles required non-empty) |
| faction-identity.md | TR-faction-014: faction-selection UI showing 3 VS FactionDefs, default Neutral, ack-gated non-Neutral, preview loadout before lock | §6 (setup FSM contracts: SELECTING preview AC-28, ack gate AC-27, Neutral default) — pixel UX to `/ux-design` |
| faction-identity.md | TR-faction-015: AI reads effective_X via shared call sites, no AI-only branch; future cache key includes player | §7 (every effective_X takes `player`; static-check the no-AI-branch; cache-key + LETHAL_FLOOR flag to ADR-0011) |

## Performance Implications
- **CPU**: `Faction.unit_delta`/etc. is a linear scan over a roster-sized typed array (≤4 units / 5
  structures / few techs); each `effective_X` adds one scan + one clamp over its base computation —
  negligible. Neutral's empty entry arrays make every scan an instant miss. (If a future large roster
  + heavy AI-lookahead profile shows this binds, the owning system can memoize a
  `Dictionary[type,entry]` once at faction-load — reversible, since the faction data is immutable.)
- **Memory**: 3 preload'd `FactionDef` Resources shared across all clones (zero per-clone cost, §2);
  `PlayerState.faction` is one reference per player. No per-frame allocation.
- **Clone cost**: `GameState.clone()` carries `PlayerState.faction` as a reference and SHARES the
  path-having `FactionDef` (ADR-0007) — the AI's per-candidate lookahead pays nothing for faction data.
- **Load Time**: Negligible — 3 small `.tres` preload'd once.
- **Network**: N/A.

## Migration Plan
N/A — greenfield. (The `effective_X` fold-ins are additive to systems not yet implemented; Neutral
ships them as identity.)

## Validation Criteria
- **Neutral pin**: `effective_X(state, base_owner, neutral_player) == base_X` for every unit cost/
  mobility, every structure cost/time/cap, every tech cost/time/availability, and `credit_income`
  (TR-faction-011 / AC-4a — reads the base tables directly, no playable build).
- **Floors bind correctly**: a subtractive delta driving any value below its floor returns exactly the
  floor, never below/0/negative (AC-7/8/9/10/11/13).
- **production_cap two-sided**: base≥1 with a zeroing delta → 1; base==0 with any delta → 0 (AC-12).
- **Closed schema**: a `FactionDef` with an out-of-domain field is rejected at load (AC-5); both
  identity handles present non-empty (AC-6b); combat deltas identity for all 3 VS factions (AC-6).
- **Clone survival**: a cloned `GameState` reads the same `FactionDef` reference as the authoritative
  state; `effective_X` on a clone == on the authoritative state under identical faction/state.
- **Orphaned inertness**: an orphaned numeric delta contributes 0 (AC-21); an orphaned loadout ref is
  skipped (AC-20); both log a load warning.
- **Setup lock**: `faction_of(player)` immutable after Setup→PlayerTurn; second assignment no-op
  (AC-22). Loadout placed exactly once at confirm, not during preview (AC-26).
- **Asymmetric per-player reads**: `effective_produce_cost(unit, A)` reflects only A's faction delta,
  never B's (AC-17).

## Related Decisions
- ADR-0001: state model (`PlayerState.faction` field + `faction_of(player)`; `clone()` carries it)
- ADR-0003: determinism (`FactionDef` fixed data, no per-match RNG; integer-only deltas)
- ADR-0006: AP & Credits Economy (`effective_credit_income` folds faction income deltas into the 4-term Credit income formula, econ-tech term preserved)
- ADR-0007: entity stat schema (the preload'd-registry + Resource-ref-identity pattern reused; the
  path-having-Resource clone-sharing finding; the forward-declared-`effective_X` pattern)
- ADR-0010: combat resolution (`effective_attack` — the existing effective-value site the faction
  combat delta extends, identity-locked in the VS)
- ADR-0011: AI opponent (AI reads `effective_X` via the shared sites; `is_ai_controlled` Setup-lock
  precedent; the `LETHAL_FLOOR_BONUS`/cache-key faction-axis forward-flags)
- `design/gdd/faction-identity.md` — the framework-only design this ADR makes concrete (Rush/Boom
  values remain prototype-gated per the GDD's own scope)
