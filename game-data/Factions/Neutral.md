---
id: neutral
description: No modifiers — the baseline every faction is measured against.
playable: false
hq: null
structures: []
techs: []
infantry_cap_delta: 0
base_income_delta: 0
upkeep_pct_delta: 0
unit_changes: []
promotes: false
rank_requires_support: false
rank_support_structures: []
---

## Notes

The six designed factions (design/gdd/factions/) will live here once the faction framework is built.

`unit_changes` adjusts a unit for this faction only, e.g.

```yaml
unit_changes:
  - unit: "[[Trooper]]"
    cost: -50
    move_cost: 0
```
