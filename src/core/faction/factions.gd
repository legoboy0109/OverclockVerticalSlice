## Factions — thin logic-free registry of FactionDef consts (Story 007 stub).
##
## Mirrors [code]UnitTypes[/code]/[code]Balance[/code]'s "preload once, expose
## by reference" idiom (ADR-0006/0007). [code]class_name[/code] + [code]const[/code]
## rather than an Autoload: a [code]const[/code] resolves statically as
## [code]Factions.NEUTRAL[/code] with no [code]project.godot[/code] registration
## needed (ADR-0012 §2's [code]preload()[/code]'d registry-const pattern).
##
## [b]Story 007 stub, extended for the VS (S4-03)[/b] — this registry now carries all
## three §2 identity consts ([code]NEUTRAL[/code]/[code]RUSH[/code]/[code]BOOM[/code],
## ADR-0012 §2), but [code]RUSH[/code]/[code]BOOM[/code] ship with [b]empty
## [member FactionDef.unit_deltas][/b]: identity/ownership only, mechanically identical
## to Neutral (VS parity preserved — faction asymmetry, the §1 6-domain delta schema,
## stays deferred to the Faction Identity epic). The Neutral no-op regression (AC-1)
## remains a genuine registry read. The VS pins its two sides to [code]RUSH[/code]/
## [code]BOOM[/code] so ownership reads by hue (art-bible §4.2; the entity renderer maps
## [code]RUSH[/code]→#FF5A2E, [code]BOOM[/code]→#22C7F0).
class_name Factions
extends RefCounted

const NEUTRAL: FactionDef = preload("res://data/factions/neutral.tres")
const RUSH: FactionDef = preload("res://data/factions/rush.tres")
const BOOM: FactionDef = preload("res://data/factions/boom.tres")
