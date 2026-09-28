## Forward-declared stub for the Faction Identity epic's FactionDef (ADR-0012).
## Exists only so GameState/PlayerState.faction: FactionDef type-checks and
## clones correctly (ADR-0001 Story 001). The Faction Identity epic replaces
## this file with the full 6-domain schema per ADR-0012 — do not add fields
## here beyond what this story's tests require.
class_name FactionDef
extends Resource

## Player-facing name. Generated from the vault note's title (game-data/Factions/).
@export var display_name: String

## One-line player-facing description.
@export_multiline var description: String

## ★ Faction framework v2 (faction-identity.md CR-2, built 2026-09-28). A faction OWNS its
## content (D1/D5/D6): its HQ, the structures its Builders may raise and its tech tree. Its units
## follow from what those structures produce, so there is no separate unit list to keep in step.
## Anything left empty falls back to the shared base content — which is what Neutral (the test
## and default faction) does, and why every pre-v2 test still means what it meant.

## Offered in the faction picker. Neutral and the two seat-colour palettes are not.
@export var playable: bool = false

## This faction's HQ type (it decides what the HQ produces — the faction's Builder). Null = the
## shared HQ.
@export var hq: StructureTypeDef = null

## Structures this faction's Builders may raise (D5). Empty = the shared buildable roster.
@export var structures: Array[StructureTypeDef] = []

## This faction's tech tree (D6). Empty = the shared tree.
@export var techs: Array[TechDef] = []

## MOD domains (CR-4: folded in at the owning system's read site, never written into base data).
## D3 — added to the base infantry cap.
@export var infantry_cap_delta: int = 0
## D4 — added to base Credit income per turn.
@export var base_income_delta: int = 0
## D9 — percent added to total upkeep (e.g. 20 = +20%). Floored so upkeep never goes negative.
@export var upkeep_pct_delta: int = 0

## This faction's units earn merit and rank up (promotion-veterancy.md PV-8: the Holy Cosmic
## Empire only, in the current design). Off for everyone else, so all merit logic is inert.
@export var promotes: bool = false

## Ranks need a standing support structure (PV-7): with none COMPLETED at the start of the
## owner's turn, every unit drops one rank (merit is kept). Only meaningful with [member promotes].
@export var rank_requires_support: bool = false

## Structure types that count as support for PV-7.
@export var rank_support_structures: Array[StructureTypeDef] = []

## Per-unit-type cost/mobility deltas (ADR-0012 §1 field name, exact). Story
## 007's minimal slice of the eventual closed 6-domain schema — only the
## [FactionUnitDelta] entries this story's [code]effective_produce_cost[/code]/
## [code]effective_move_cost[/code] read. Empty on [code]Factions.NEUTRAL[/code]
## (ADR-0012 §5's Neutral regression pin: empty arrays -> every scan is an
## instant miss -> every [code]effective_X == base_X[/code] exactly).
@export var unit_deltas: Array[FactionUnitDelta] = []
