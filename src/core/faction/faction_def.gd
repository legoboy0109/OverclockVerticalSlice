## Forward-declared stub for the Faction Identity epic's FactionDef (ADR-0012).
## Exists only so GameState/PlayerState.faction: FactionDef type-checks and
## clones correctly (ADR-0001 Story 001). The Faction Identity epic replaces
## this file with the full 6-domain schema per ADR-0012 — do not add fields
## here beyond what this story's tests require.
class_name FactionDef
extends Resource
