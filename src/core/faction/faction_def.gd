## Forward-declared stub for the Faction Identity epic's FactionDef (ADR-0012).
## Exists only so GameState/PlayerState.faction: FactionDef type-checks and
## clones correctly (ADR-0001 Story 001). The Faction Identity epic replaces
## this file with the full 6-domain schema per ADR-0012 — do not add fields
## here beyond what this story's tests require.
class_name FactionDef
extends Resource

## Per-unit-type cost/mobility deltas (ADR-0012 §1 field name, exact). Story
## 007's minimal slice of the eventual closed 6-domain schema — only the
## [FactionUnitDelta] entries this story's [code]effective_produce_cost[/code]/
## [code]effective_move_cost[/code] read. Empty on [code]Factions.NEUTRAL[/code]
## (ADR-0012 §5's Neutral regression pin: empty arrays -> every scan is an
## instant miss -> every [code]effective_X == base_X[/code] exactly).
@export var unit_deltas: Array[FactionUnitDelta] = []
