---
id: supply_depot
buildable: true
art_id: research_lab
hp: 10
build_cost: 500
build_time: 2
upkeep: 100
max_count: 0
cap_bonus: 0
production_cap: 0
produces: []
attack: 0
attack_range: 0
defense: 0
can_counterattack: false
can_research: false
resupplies: true
can_target:
- infantry
- ground_vehicle
targeting_mode: direct
min_range: 1
damage_type: kinetic
resist_kinetic: 0
resist_emf: 0
resist_incendiary: 0
---

## Notes

Refills the ammo of every own vehicle and aircraft on a neighbouring tile at the start of its
owner's turn (user decision 2026-10-01). HQ, factories and airfields do the same; the depot is
how a player pushes a supply point forward. Values are starting guesses, untuned.
art_id borrows the Research Lab until its own art is generated.
