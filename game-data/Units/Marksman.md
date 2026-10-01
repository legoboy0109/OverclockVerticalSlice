---
id: marksman
unit_class: infantry
can_target:
- infantry
- ground_vehicle
hp: 3
attack: 5
attack_range: 4
defense: 0
move_cost: 1
soft_move_cap: 3
produce_cost: 600
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
crew_bonus_attack: 0
---

## Notes

- **2026-09-29 (Highlands balance):** attack 7 → 5. At range 4 on Highlands' open lanes it hit
  first and hardest: The Lightless won 25/30 there. At 5: 12 / 14 / 17 of 30 on the three maps.

★ Stats from `design/gdd/factions/independents.md`. ⚠ Placeholder art borrowed from `sniper` — looks identical to it on the board.

⚠ Its design carries SPOT, which is deferred (see the decision log).
