## DamageEvent — fired for every hit that lands, whether or not it kills.
##
## Combat-owned event type (ADR-0004, which names `damage_event.gd (Combat)` in
## its planned-event table). Appended by [method Combat.apply] for the primary
## hit and again, with the roles swapped, for a counterattack — so a single
## committed [AttackAction] can produce two of these.
##
## [b]Why this exists at all.[/b] Combat previously announced only DEATHS
## ([UnitDestroyedEvent] / [StructureDestroyedEvent]), which meant nothing
## downstream could tell who swung at whom on a hit that the defender survived —
## the common case. The Board Renderer's attack lunge and hit recoil (§8.5,
## Story 008 / sprint task S5-06) both need exactly that pairing, and re-deriving
## it from an hp diff is the structural-diff anti-pattern ADR-0004 §256 forbids.
##
## [b]Ordering (ADR-0004 §306).[/b] A lethal hit's DamageEvent is appended
## BEFORE the [method GameState.destroy_entity] events it causes, so a consumer
## replaying the array in order sees the blow before the death. A counterattack's
## DamageEvent likewise precedes its own kill.
##
## [b]Deviation from the ADR sketch, recorded:[/b] the sketch reads
## [code]target_id, amount, is_crit[/code]. [code]is_crit[/code] is dropped —
## there is no crit system in [Combat] and inventing a permanently-false field
## would be dead weight. [code]attacker_id[/code] is added, because "who swung"
## is the half the renderer cannot get anywhere else.
##
## Usage:
## [codeblock]
## for e in result.events:
##     if e is DamageEvent:
##         feed.lunge((e as DamageEvent).attacker_id)
##         feed.recoil((e as DamageEvent).target_id)
## [/codeblock]
class_name DamageEvent
extends Event

## The [member EntityState.entity_id] of whoever dealt the damage. On a
## counterattack this is the original DEFENDER — the roles are genuinely
## swapped, not annotated.
@export var attacker_id: int = -1

## The [member EntityState.entity_id] of whoever took it.
@export var target_id: int = -1

## Damage actually dealt, as computed by [method Combat.damage] — the pre-clamp
## figure passed to [method Combat._apply_damage_to], not the hp delta. The two
## differ on an overkill: a 9-damage blow on a 4-hp target reports 9 here while
## hp moves only 4. Overkill is the honest number for a log line and makes no
## difference to the renderer, which reads only the ids.
@export var amount: int = 0


func _init(p_attacker_id: int = -1, p_target_id: int = -1, p_amount: int = 0) -> void:
	attacker_id = p_attacker_id
	target_id = p_target_id
	amount = p_amount
