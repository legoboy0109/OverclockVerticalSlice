---
id: drone_maintenance
description: Sentinel and Breaker mechs no longer need pilots, and repair 2 HP at the start of your turn. Crewed ones eject their pilot. +1,200 Credits of income every turn.
tree: economy
tier: 3
research_cost: 1600
research_time: 4
ap_surcharge: 8
requires:
- '[[Forward Depots]]'
requires_structures:
- '[[Research Lab]]'
exclusive_group: eco_fwd
factions: []
economy_tier_bonus: 1
replaces:
- '[[Field Workshops]]'
frees_pilots:
- '[[Sentinel Mech]]'
- '[[Breaker Mech]]'
bonus_unit_self_repair: 2
bonus_unit_types:
- '[[Sentinel Mech]]'
- '[[Breaker Mech]]'
---

## Notes

★ 2026-10-01 (user decision): the Trappist's Supply Lines-branch way out of needing pilots, so
autonomous mechs are reachable on either Economy branch. Each path has its own twist — this one is
ENDURANCE (mechs self-repair 2 HP a turn); Mech Autonomy on the Logistics path is SPEED (+1 move).
Added because the AI took Supply Lines in 102/120 Trappist games, which put Mech Autonomy (behind
Logistics) out of reach.
