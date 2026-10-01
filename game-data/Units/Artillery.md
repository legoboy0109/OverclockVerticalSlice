---
id: artillery
unit_class: ground_vehicle
can_target:
- infantry
- ground_vehicle
hp: 16
attack: 8
attack_range: 5
defense: 0
move_cost: 2
soft_move_cap: 2
produce_cost: 1600
production_turns: 3
ground_offset_px: 7
upkeep: 380
counts_toward_cap: false
can_counterattack: false
can_build: false
targeting_mode: area
min_range: 2
damage_type: kinetic
resist_kinetic: 0
resist_emf: -2
resist_incendiary: 0
area_shape: burst
area_length: 4
abilities: []
can_pilot: false
requires_pilot: true
transport_capacity: 0
transport_accepts: []
transport_size: 3
targets_crew: false
---

## Notes

★ Stats from `design/gdd/factions/democratic-alliance.md` (the baseline roster). ⚠ Placeholder art.

Breaks a static line. Area targeting: fires over anything in the way, but cannot hit anything closer than 2 tiles.
