## AbilityDef — one catalogue entry (unit-abilities.md AB-1): an action a unit may take
## besides moving and attacking. Base-game values, identical for every faction that carries
## the ability (AB-8). Generated from `game-data/Abilities/*.md`.
##
## The EFFECT is code, keyed by [member id] (see [Ability]); everything a designer tunes —
## prices, range, cooldown, magnitude — is here.
class_name AbilityDef
extends Resource

## Stable identifier the effect code dispatches on: repair, fortify, demolish, self_destruct,
## capture_vehicle, paradrop.
@export var id: StringName

## Player-facing name and one-line description.
@export var display_name: String
@export_multiline var description: String

## AP spent on use. Always >= 1 — there are no free abilities (AB-3).
@export var ap_cost: int = 1

## Credits spent on use (0 = none). A Credit-costing ability is blocked in deficit.
@export var credit_cost: int = 0

## Manhattan range to the target tile; 0 = self.
@export var ability_range: int = 1

## Owner-turns before it can be used again (0 = every turn).
@export var cooldown: int = 0

## Uses per match per unit (0 = unlimited).
@export var uses_per_match: int = 0

## The ability's magnitude: hp repaired, defence gained, bonus damage, blast damage, tiles.
@export var amount: int = 0
