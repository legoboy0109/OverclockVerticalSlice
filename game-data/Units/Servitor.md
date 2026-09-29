---
id: servitor
unit_class: infantry
can_target:
- infantry
- ground_vehicle
hp: 4
attack: 2
attack_range: 1
defense: 0
move_cost: 2
soft_move_cap: 3
produce_cost: 200
production_turns: 1
upkeep: 230
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
can_pilot: true
requires_pilot: false
transport_capacity: 0
transport_accepts: []
transport_size: 1
targets_crew: false
crew_bonus_attack: -1
crew_bonus_move_cost: 0
art_id: trooper
---

## Notes

★ Stats from `design/gdd/factions/galactic-protectorate.md`. ⚠ Placeholder art borrowed from `trooper` — looks identical to it on the board.

A humanoid robot: does not count toward the infantry cap, but costs 300 upkeep — bounded by money, not a cap (CR-11a). A poor pilot (crew bonus −1 attack). Weak to EMF like any machine.
