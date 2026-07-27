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
