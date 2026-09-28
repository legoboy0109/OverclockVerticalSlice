---
id: democratic_alliance
description: 'The generalist: a serviceable answer to everything, the best answer to nothing. The balance baseline.'
playable: true
hq: '[[HQ]]'
structures:
- '[[Barracks]]'
- '[[Factory]]'
- '[[Airfield]]'
- '[[Research Lab]]'
- '[[Defensive Structure]]'
techs:
- '[[Attack Tech]]'
- '[[Defense Tech]]'
- '[[Economy Tech]]'
- '[[Penetration]]'
- '[[Volley]]'
- '[[Plating]]'
- '[[Field Repair]]'
- '[[Logistics]]'
- '[[Foundry]]'
infantry_cap_delta: 0
base_income_delta: 0
upkeep_pct_delta: 0
unit_changes: []
promotes: false
rank_requires_support: false
rank_support_structures: []
---

## Notes

★ The **balance baseline** (`design/gdd/factions/democratic-alliance.md`): every other faction is
measured against it (CR-10). Every modifier is zero — the Alliance is the game with nothing added
and nothing taken away.

It owns the base roster: Builder, Scout, Trooper, Heavy, Sniper (HQ/Barracks), Tank, Artillery,
Transport (Factory), Fighter, Bomber, Helicopter (Airfield).

⚠ Differences from its design doc, kept deliberately for now: Barracks hp 14 (doc 12), Research Lab
hp 12 (doc 10) — the shipped values have been played; the tech tree is the CR-14 tree; the
Defensive Structure is not yet "manned" (needs a pilot) — see `design/decision-log.md`.
