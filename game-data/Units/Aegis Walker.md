---
id: aegis_walker
unit_class: ground_vehicle
can_target:
- infantry
- ground_vehicle
hp: 23
attack: 6
attack_range: 2
defense: 3
move_cost: 2
soft_move_cap: 3
produce_cost: 1400
production_turns: 2
ground_offset_px: 5
upkeep: 380
counts_toward_cap: false
can_counterattack: false
can_build: false
targeting_mode: direct
min_range: 1
damage_type: kinetic
resist_kinetic: 0
resist_emf: -2
resist_incendiary: 0
area_shape: single
area_length: 4
abilities: []
can_pilot: false
requires_pilot: true
transport_capacity: 0
transport_accepts: []
transport_size: 3
targets_crew: false
crew_bonus_attack: 0
crew_bonus_move_cost: 0
starting_merit: 0
---

## Notes

★ Stats from `design/gdd/factions/holy-cosmic-empire.md`. ⚠ Placeholder art borrowed from `tank` — looks identical to it on the board.

Survives on defence, not hit points: cheap attacks are floored to 1 damage.
