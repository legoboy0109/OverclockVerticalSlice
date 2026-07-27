## StructureState — TEST STUB for the forward-declared Unit & Structure
## Entity/Stat Schema (ADR-0007)'s [code]StructureState[/code] concrete
## [EntityState] subclass.
##
## ⚠️ TEMPORARY. This is NOT the real [code]StructureState[/code] — it is a
## minimal, test-controllable stand-in carrying just enough shape (one
## test-observable per-turn flag) for [method GameState.start_turn]'s step 2
## (the [code]e is StructureState[/code] dispatch) to be exercised before the
## Unit & Structure Entity/Stat Schema epic lands. The real
## [code]StructureState[/code] lands with that epic (ADR-0007).
##
## [b]DELETE THIS FILE when the real [code]StructureState[/code] class is
## created in [code]src/[/code].[/b] GDScript [code]class_name[/code] is
## project-global, so the real class and this stub would collide (duplicate
## global class name).
##
## Only ONE stub declaration of [code]class_name StructureState[/code] may
## exist in the project — this file. GS-003's test suite is the only current
## consumer; never redeclare it per test file.
##
## Combat Resolution Story 001 extends this stub with a minimal [code]type[/code]/
## [code]defense[/code] shape (ADR-0010/ADR-0007) — just enough for
## [method Combat.damage]'s structure-defender branch
## ([code]defender.type.defense[/code]) to be exercised before the real
## [code]StructureTypeDef[/code] schema lands. Deliberately minimal: only
## [code]type.defense[/code] and the inherited [code]position[/code] (Combat's
## damage formula needs nothing else) — no unrelated Base & Production fields
## (build_status, production, etc.) belong here; those come with that epic.
##
## Combat Resolution Story 004 further extends this stub with
## [member current_hp] and [member TypeStub.hp] — just enough for
## [method Combat._apply_damage_to]'s structure-defender branch (the inline
## [code]clampi(current_hp - dmg, 0, type.hp)[/code] mutator) to be exercised
## before Base & Production's real structure-hp mutator lands. [b]A fixture
## that sets [member current_hp] must also set [member TypeStub.hp] to at
## least that value[/b] — otherwise the clamp ceiling (default 10) silently
## caps [member current_hp] below what the fixture intended, giving a
## confusing wrong result on the very first hit.
##
## Combat Resolution Story 005 further extends this stub with:
## [member has_attacked] (a NEW, separate field from [member has_acted] — the
## two are never conflated; see that field's own doc comment), [member
## is_hq_flag]/[method is_hq] (backing [method GameState.destroy_entity]'s
## HQ-vs-non-HQ event-shape decision), and — required for a structure
## attacker to flow through the [i]same[/i] [method Combat.legal_targets]/
## [method Combat._effective_attack_for] pipeline a unit attacker uses —
## [member TypeStub.attack]/[member TypeStub.attack_range]/[member
## TypeStub.targeting_mode]/[member TypeStub.min_range]. Without these four
## fields a [code]StructureState[/code] attacker would crash reading
## [code]attacker.type.attack_range[/code] inside [method Combat._walk_direction];
## they are additive-only and default to values that are DIRECT-safe/no-op
## for every pre-Story-005 fixture that never sets them.
##
## Combat Resolution Story 006 further extends [TypeStub] with [member
## TypeStub.can_counterattack] — required for a [code]StructureState[/code]
## defender (the Defensive Structure, the GDD's first live counter case) or
## attacker to exercise [method Combat.apply]'s counter step.
##
## Usage in a test:
## [codeblock]
## var s := StructureState.new()
## s.entity_id = 6
## s.owner = 0
## s.has_acted = true
## s.type.defense = 2
## s.type.hp = 10
## s.current_hp = 10
## state.entities_by_id[s.entity_id] = s
## [/codeblock]
class_name StructureState
extends EntityState

## Test-observable per-turn flag, mirroring the real (not-yet-implemented)
## Base & Production system's per-turn structure flags, consumed by
## [method Structure.reset_turn_flags]. Defaults [code]true[/code] so a test
## can assert [method Structure.reset_turn_flags] actually flips it to
## [code]false[/code] rather than observing an already-false default.
## [b]Independent of [member has_attacked][/b] — the two are separate fields
## until the real [code]StructureState[/code] (Base & Production epic)
## reconciles them; never rename or reuse one for the other.
@export var has_acted: bool = true

## Test-observable per-turn flag (Combat Resolution Story 005, ADR-0010/
## ADR-0007) — mirrors the real [code]StructureState.has_attacked[/code] field
## name exactly. [method Combat.validate]'s structure-attacker branch rejects
## a Defensive Structure attacker once this is [code]true[/code] (already
## fired this turn); [method Combat.apply] flips it to [code]true[/code] on a
## successful attack, exactly like [code]UnitState.has_attacked[/code].
## Defaults [code]false[/code] (a fresh structure has not fired this turn).
## [b]A NEW field — never conflated with [member has_acted][/b] (see that
## field's doc comment).
@export var has_attacked: bool = false

## Test-controllable HQ flag (Combat Resolution Story 005, ADR-0010) — backs
## [method is_hq]. Defaults [code]false[/code] (an ordinary, non-HQ
## structure); a fixture representing the match's HQ must set this
## explicitly.
@export var is_hq_flag: bool = false

## Test-controllable current hit points (Combat Resolution Story 004), mutated
## by [method Combat._apply_damage_to]'s structure-defender branch. Mirrors
## [code]UnitState.current_hp[/code]'s role but has no dedicated mutator yet
## (Base & Production owns that epic) — a test/fixture may assign this
## directly. Defaults to [code]0[/code]; a fixture representing a healthy
## structure must set this explicitly (and see [member TypeStub.hp]'s note on
## keeping the two in agreement).
@export var current_hp: int = 0

## Forward-declared [code]StructureState[/code] contract (ADR-0007) [method
## GameState.destroy_entity] reads to decide whether a destroyed structure's
## event is win-check-decisive (Combat Resolution Story 005). Stub behavior:
## returns [member is_hq_flag] verbatim.
func is_hq() -> bool:
	return is_hq_flag

## Minimal per-type stand-in exposing the fields [method Combat.damage]/
## [method Combat._apply_damage_to]/[method Combat.legal_targets]/
## [method Combat._effective_attack_for] read ([code]defender.type.defense[/code],
## [code]target.type.hp[/code], and — Story 005 — [code]attacker.type.attack[/code]/
## [code]attack_range[/code]/[code]targeting_mode[/code]/[code]min_range[/code]
## for a structure-as-attacker fixture) — deliberately NOT a [code]class_name[/code],
## so it can never collide with the real [code]StructureTypeDef[/code] the
## Unit & Structure Entity/Stat Schema epic will introduce. Nested here
## (rather than at file scope) for the same reason.
class TypeStub extends RefCounted:
	var defense: int = 0
	## Hp ceiling [method Combat._apply_damage_to]'s inline clamp reads,
	## mirroring [code]UnitTypeDef.hp[/code]'s role. Defaults to [code]10[/code]
	## (matching [code]damage_formula_test.gd[/code]'s [code]_make_unit_type[/code]
	## HP convention) — a fixture that assigns [member StructureState.current_hp]
	## above the default must also raise this to match, or the clamp silently
	## caps it.
	var hp: int = 10
	## Attack value [method Combat._effective_attack_for] reads for a
	## structure attacker (Combat Resolution Story 005) — mirrors
	## [code]UnitTypeDef.attack[/code]'s role. Defaults to [code]0[/code]
	## (inert); a Defensive Structure attacker fixture must set this
	## explicitly (e.g. [code]4[/code] for the story's AC-5 stat block).
	var attack: int = 0
	## Attack range [method Combat._walk_direction]/[method Combat.legal_targets]
	## read for a structure attacker (Story 005) — mirrors
	## [code]UnitTypeDef.attack_range[/code]'s role. Defaults to [code]1[/code]
	## (never zero — a zero range would make every DIRECT walk immediately
	## exhausted, which is never the intended "unset" behavior).
	var attack_range: int = 1
	## Targeting-mode stand-in mirroring [code]UnitTypeDef.targeting_mode[/code]
	## (an [code]int[/code]-typed field here, matching [enum UnitTypeDef.TargetingMode]'s
	## values, since this stub is not a [code]class_name[/code] and cannot
	## declare its own enum reference safely). Defaults to
	## [code]UnitTypeDef.TargetingMode.DIRECT[/code] (0) — every VS Defensive
	## Structure fixture to date is DIRECT.
	var targeting_mode: int = UnitTypeDef.TargetingMode.DIRECT
	## Minimum attack range mirroring [code]UnitTypeDef.min_range[/code].
	## Defaults to [code]1[/code], matching [code]UnitTypeDef[/code]'s own
	## default and always satisfying [code]min_range <= attack_range[/code]
	## for a DIRECT fixture (TR-combat-011's schema invariant).
	var min_range: int = 1
	## Counterattack eligibility mirroring [code]UnitTypeDef.can_counterattack[/code]
	## (Combat Resolution Story 006, ADR-0010, TR-combat-009) — read directly
	## by [method Combat.apply]'s counter-step gate
	## ([code]target.type.can_counterattack[/code]). Defaults to [code]false[/code]
	## (no VS Defensive Structure counters unless a fixture explicitly opts
	## in) — mirrors [code]UnitTypeDef.can_counterattack[/code]'s own
	## default-false, roster-wide convention.
	var can_counterattack: bool = false

## Per-type stand-in this story's Combat fixtures read as
## [code]structure.type.defense[/code] — mirrors [code]UnitState.type[/code]'s
## shape (ADR-0007) just enough for the damage formula's structure-defender
## branch. Auto-constructed so a test only needs to set
## [code]structure.type.defense = 2[/code] — never a bare
## [code]structure.defense[/code] (ADR-0007 keeps [code]defense[/code] a
## template field, not an entity field; [method Combat.damage] would not
## compile against a bare field).
var type: TypeStub = TypeStub.new()
