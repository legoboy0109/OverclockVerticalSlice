---
id: lance_tank
unit_class: ground_vehicle
can_target:
- infantry
- ground_vehicle
hp: 22
attack: 8
attack_range: 3
defense: 0
move_cost: 2
soft_move_cap: 3
produce_cost: 1800
production_turns: 2
ground_offset_px: 7
upkeep: 1050
counts_toward_cap: false
can_counterattack: false
can_build: false
targeting_mode: area
min_range: 2
damage_type: emf
resist_kinetic: 0
resist_emf: -3
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
---

## Notes

★ Stats from `design/gdd/factions/galactic-protectorate.md`. ⚠ Placeholder art borrowed from `artillery` — looks identical to it on the board.

Always needs a pilot. Indirect EMF fire, cannot hit adjacent targets.
