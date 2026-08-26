## BuildAction — commits a structure build via [method GameState.apply_action].
##
## Core-layer command model per ADR-0002/ADR-0017. Mirrors [AttackAction]'s
## shape: its own top-level file with a [code]class_name[/code] (never a
## nested inner class), setting [member Action.verb] to
## [constant Action.Verb.BUILD] in [code]_init()[/code]. Its
## [code]validate()[/code]/[code]apply()[/code] handlers live on
## [BaseProduction] (the owning Core system), never on this class (ADR-0002
## forbids the command-pattern of methods directly on an [Action] subclass).
##
## The builder is [b]always[/b] [member GameState.active_player] at commit
## time — this class carries no separate builder/owner field of its own
## ([member Action.player] already IS the acting player per ADR-0002's base
## contract, and [method GameState.apply_action]'s step 2 already gates it to
## the active player before [BaseProduction.validate_build] ever runs).
##
## Usage:
## [codeblock]
## var action := BuildAction.new()
## action.player = state.active_player
## action.structure_type = StructureTypes.FACTORY
## action.tile = Vector2i(3, 4)
## var result: ActionResult = state.apply_action(action)
## [/codeblock]
class_name BuildAction
extends Action

## The [StructureTypeDef] template to build — a preload'd reference into the
## [code]StructureTypes[/code] registry (ADR-0007), never a runtime-loaded
## duplicate.
@export var structure_type: StructureTypeDef

## The tile to place the new structure on. Must be present in
## [method BaseProduction.legal_build_tiles_for]'s result set for
## [member builder_id] at commit time.
@export var tile: Vector2i

## [member EntityState.entity_id] of the [UnitState] raising this structure.
##
## ★ [b]Build stopped being a player-level command on 2026-08-25[/b] (user
## decision). It used to belong to the PLAYER — any frontier tile beside any owned
## entity was legal, and no unit was involved — which is why this field did not
## exist. Now a structure is raised by a specific Builder standing beside the tile,
## and that Builder is CONSUMED by the build.
##
## ⚠ Consequence worth stating plainly: with no living Builder a player cannot
## build at all. That is not a soft-lock, because only the HQ produces Builders and
## losing the HQ is already a decisive defeat
## ([constant GameState.VictoryCause.HQ_DESTROYED]).
@export var builder_id: int = -1


func _init() -> void:
	verb = Action.Verb.BUILD
