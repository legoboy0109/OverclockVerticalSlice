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
# ★ Faction framework v2 (2026-09-28). Added wave by wave (user decision: Alliance first).
const DEMOCRATIC_ALLIANCE: FactionDef = preload("res://data/factions/democratic_alliance.tres")
const SOLAR_FEDERATION: FactionDef = preload("res://data/factions/solar_federation.tres")
const INDEPENDENTS: FactionDef = preload("res://data/factions/independents.tres")
const MACHINISTS_UNION: FactionDef = preload("res://data/factions/machinists_union.tres")
const GALACTIC_PROTECTORATE: FactionDef = preload("res://data/factions/galactic_protectorate.tres")
const HOLY_COSMIC_EMPIRE: FactionDef = preload("res://data/factions/holy_cosmic_empire.tres")

## Every faction, in picker order. ⚠ Rush and Boom are no longer factions in play — they are the
## two SEAT colour palettes (user decision 2026-09-28: colour means which player, not faction).
const ALL: Array[FactionDef] = [DEMOCRATIC_ALLIANCE, SOLAR_FEDERATION, INDEPENDENTS, MACHINISTS_UNION, GALACTIC_PROTECTORATE, HOLY_COSMIC_EMPIRE, NEUTRAL, RUSH, BOOM]

## The seat colour palettes: seat 0 orange, seat 1 cyan, whatever faction each seat plays.
const SEAT_PALETTES: Array[FactionDef] = [RUSH, BOOM]


## The factions the picker offers. A function, not a static var: reading a resource's fields
## at class-load time can run before the resource's script is attached (see VSMap).
static func playable() -> Array[FactionDef]:
	var out: Array[FactionDef] = []
	for f: FactionDef in ALL:
		if f.playable:
			out.append(f)
	return out
