## Faction — static utility class for faction-delta lookups (ADR-0012 §3).
##
## Feature-layer system per ADR-0012 (faction identity modifier framework).
## Mirrors the [code]AP[/code]/[code]Movement[/code]/[code]Combat[/code]/
## [code]BaseProduction[/code]/[code]Research[/code] shape: static, stateless,
## state/faction passed explicitly — no instance fields of its own. Faction is
## a [b]modifier provider[/b], never an owner of any base value (CR-4) — the
## owning systems' [code]effective_X[/code] functions call into this helper
## and fold the result themselves.
##
## Story 007 ships only [method unit_delta] (the one lookup
## [method Unit.effective_produce_cost]/[method Unit.effective_move_cost]
## need). [code]structure_delta[/code]/[code]tech_delta[/code] are the Faction
## Identity epic's (ADR-0012 §3 forward-declares them alongside this one).
class_name Faction
extends RefCounted


## Returns the [FactionUnitDelta] entry in [param f]'s [member FactionDef.unit_deltas]
## whose [member FactionUnitDelta.type] is the [b]same Resource reference[/b]
## as [param type] (identity via [code]==[/code], never a string/enum key —
## ADR-0007's identity discipline), or [code]null[/code] if [param type] has
## no entry.
##
## [code]null[/code] is a first-class, expected result — an absent entry is
## inert (contributes 0 to whichever domain the caller folds), not an error.
## This also covers ADR-0012 §5's orphaned-delta case: a [FactionUnitDelta]
## whose [member FactionUnitDelta.type] no longer exists in the live roster
## simply never matches any caller's [param type] either, so it is silently
## inert with no special-casing needed here.
##
## Linear scan over a roster-sized typed array (ADR-0012: ≤4 units in the VS
## roster; [code]Factions.NEUTRAL[/code]'s array is empty, an instant miss).
static func unit_delta(f: FactionDef, type: UnitTypeDef) -> FactionUnitDelta:
	for d: FactionUnitDelta in f.unit_deltas:
		if d.type == type:
			return d
	return null


# ---------------------------------------------------------------------------
# ★ Faction framework v2 (2026-09-28) — what a player's faction owns.
# Every "what can THIS player build / research / field" question goes through here, so the
# rules, the menus and the AI can never disagree about a faction's content.
# ---------------------------------------------------------------------------

## The structures [param player] may build: their faction's own list, or the shared roster.
static func buildable(state: GameState, player: int) -> Array[StructureTypeDef]:
	var f: FactionDef = state.faction_of(player)
	if f != null and not f.structures.is_empty():
		return f.structures
	return StructureTypes.BUILDABLE


## [param player]'s tech tree, in the faction's authored order, or the shared tree.
static func techs(state: GameState, player: int) -> Array[TechDef]:
	var f: FactionDef = state.faction_of(player)
	if f != null and not f.techs.is_empty():
		return f.techs
	return Techs.ALL


## The HQ type [param faction] starts with.
static func hq_type(faction: FactionDef) -> StructureTypeDef:
	return faction.hq if faction != null and faction.hq != null else StructureTypes.HQ


## Every unit type [param faction] can field: whatever its HQ and buildable structures produce.
## Derived, not listed — a unit list kept beside the structures would be one more thing to drift.
static func units(faction: FactionDef) -> Array[UnitTypeDef]:
	var out: Array[UnitTypeDef] = []
	var sources: Array[StructureTypeDef] = [hq_type(faction)]
	sources.append_array(faction.structures if faction != null and not faction.structures.is_empty() \
		else StructureTypes.BUILDABLE)
	for s: StructureTypeDef in sources:
		for t: UnitTypeDef in s.producible_types:
			if not out.has(t):
				out.append(t)
	return out


## D3 / D4 / D9 folds — each owning system adds these at its own read site (CR-4).
static func infantry_cap_delta(state: GameState, player: int) -> int:
	var f: FactionDef = state.faction_of(player)
	return f.infantry_cap_delta if f != null else 0


static func base_income_delta(state: GameState, player: int) -> int:
	var f: FactionDef = state.faction_of(player)
	return f.base_income_delta if f != null else 0


static func econ_tier_bonus_delta(state: GameState, player: int) -> int:
	var f: FactionDef = state.faction_of(player)
	return f.econ_tier_bonus_delta if f != null else 0


static func vehicle_upkeep_pct_delta(state: GameState, player: int) -> int:
	var f: FactionDef = state.faction_of(player)
	return f.vehicle_upkeep_pct_delta if f != null else 0


static func upkeep_pct_delta(state: GameState, player: int) -> int:
	var f: FactionDef = state.faction_of(player)
	return f.upkeep_pct_delta if f != null else 0
