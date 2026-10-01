---
id: sniper
unit_class: infantry
can_target:
- infantry
- ground_vehicle
hp: 3
attack: 4
attack_range: 3
defense: 0
move_cost: 2
soft_move_cap: 3
produce_cost: 550
production_turns: 2
upkeep: 100
counts_toward_cap: true
can_counterattack: false
can_build: false
targeting_mode: direct
min_range: 1
damage_type: kinetic
resist_kinetic: 0
resist_emf: 2
resist_incendiary: 0
area_shape: single
area_length: 4
abilities: []
can_pilot: false
requires_pilot: false
transport_capacity: 0
transport_accepts: []
transport_size: 1
targets_crew: false
---

## Notes

Design notes for this unit go here — the game ignores everything below the properties.

- **2026-09-29:** attack 6 → 4 and cost 500 → 550. At 6 it one-shot Troopers from out of their
  reach, and AI games turned into Sniper duels where armies never formed. It still one-shots
  Snipers, Scouts and Builders. ⚠ Raising the cost further (600) made the AI build *more*
  Snipers, because the AI currently rates units partly by price.
