---
id: cinder_tank
unit_class: ground_vehicle
can_target:
- infantry
- ground_vehicle
hp: 22
attack: 7
attack_range: 4
defense: 0
move_cost: 2
soft_move_cap: 3
produce_cost: 1900
production_turns: 2
ground_offset_px: 5
upkeep: 530
counts_toward_cap: false
can_counterattack: false
can_build: false
targeting_mode: area
min_range: 2
damage_type: incendiary
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

Always needs a pilot. ⚠ Its design gives it TWO weapons (napalm at range 2–4, a machine gun at range 1); only the napalm gun is built — see the decision log.
