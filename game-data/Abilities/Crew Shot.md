---
id: crew_shot
description: Shoot the pilot of an enemy vehicle within 4 tiles for 6 damage. Kills most pilots, leaving the vehicle empty for a Pirate to take.
ap_cost: 3
credit_cost: 0
ability_range: 4
cooldown: 2
uses_per_match: 0
amount: 6
---

## Notes

Added 2026-10-01 (user direction): gives the Lightless Marksman a natural pairing with the
Pirate's Capture Vehicle. 6 kills every infantry pilot except the Knight (7 hp). The effect is
code (`Ability.apply`, `&"crew_shot"`); the numbers are here.
