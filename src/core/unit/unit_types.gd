## UnitTypes — Autoload, logic-free registry of the VS unit roster.
##
## Core-layer Autoload per ADR-0007 (entity/stat schema), mirroring [code]Balance[/code]'s
## thin "read-only lookup convenience" idiom (ADR-0006). [code]preload()[/code]s each
## [UnitTypeDef] `.tres` once at boot and exposes it by reference. Never [code]load()[/code]
## a unit `.tres` outside this registry (control-manifest forbidden pattern, ADR-0007).
##
## Registered in `project.godot`'s `[autoload]` section so any system can read
## [code]UnitTypes.SCOUT[/code] etc. as a bare global reference.
extends Node

## The only thing an HQ produces (user decision 2026-08-25). Defenceless
## (`attack_range = 0` yields no legal targets at all), and CONSUMED by whatever it
## builds — so its cost is really a surcharge on every structure in the game.
const BUILDER: UnitTypeDef = preload("res://data/units/builder.tres")
const SCOUT: UnitTypeDef = preload("res://data/units/scout.tres")
const TROOPER: UnitTypeDef = preload("res://data/units/trooper.tres")
const HEAVY: UnitTypeDef = preload("res://data/units/heavy.tres")
const SNIPER: UnitTypeDef = preload("res://data/units/sniper.tres")
# ★ 2026-09-28, Unit Classes: the baseline roster's vehicles (Factory) and aircraft (Airfield).
const TANK: UnitTypeDef = preload("res://data/units/tank.tres")
const ARTILLERY: UnitTypeDef = preload("res://data/units/artillery.tres")
const FIGHTER: UnitTypeDef = preload("res://data/units/fighter.tres")
const BOMBER: UnitTypeDef = preload("res://data/units/bomber.tres")
const HELICOPTER: UnitTypeDef = preload("res://data/units/helicopter.tres")
const TRANSPORT: UnitTypeDef = preload("res://data/units/transport.tres")
# ★ Solar Federation (faction wave 2, 2026-09-28).
const CITIZEN_TROOPER: UnitTypeDef = preload("res://data/units/citizen_trooper.tres")
const PILOT: UnitTypeDef = preload("res://data/units/pilot.tres")
const MEDIC: UnitTypeDef = preload("res://data/units/medic.tres")
const VOLUNTEER: UnitTypeDef = preload("res://data/units/volunteer.tres")
const LANCE_TEAM: UnitTypeDef = preload("res://data/units/lance_team.tres")
const GUN_TRUCK: UnitTypeDef = preload("res://data/units/gun_truck.tres")
const ARMOURED_TRANSPORT: UnitTypeDef = preload("res://data/units/armoured_transport.tres")
const INTERCEPTOR: UnitTypeDef = preload("res://data/units/interceptor.tres")
const GUNSHIP: UnitTypeDef = preload("res://data/units/gunship.tres")
const PARATROOPER_TRANSPORT: UnitTypeDef = preload("res://data/units/paratrooper_transport.tres")
# ★ Independents (faction wave 3).
const PARTISAN: UnitTypeDef = preload("res://data/units/partisan.tres")
const PIRATE: UnitTypeDef = preload("res://data/units/pirate.tres")
const SABOTEUR: UnitTypeDef = preload("res://data/units/saboteur.tres")
const MARKSMAN: UnitTypeDef = preload("res://data/units/marksman.tres")
const MISSILE_TEAM: UnitTypeDef = preload("res://data/units/missile_team.tres")
const TECHNICAL: UnitTypeDef = preload("res://data/units/technical.tres")
const SCRAP_TANK: UnitTypeDef = preload("res://data/units/scrap_tank.tres")
const BUZZARD: UnitTypeDef = preload("res://data/units/buzzard.tres")
# ★ Machinist's Union (faction wave 4).
const MACHINIST: UnitTypeDef = preload("res://data/units/machinist.tres")
const FOREMAN: UnitTypeDef = preload("res://data/units/foreman.tres")
const GUARD: UnitTypeDef = preload("res://data/units/guard.tres")
const WALKER: UnitTypeDef = preload("res://data/units/walker.tres")
const SIEGE_MECH: UnitTypeDef = preload("res://data/units/siege_mech.tres")
const HAULER: UnitTypeDef = preload("res://data/units/hauler.tres")
const LANCER: UnitTypeDef = preload("res://data/units/lancer.tres")
const BATTERY: UnitTypeDef = preload("res://data/units/battery.tres")
const SKYWORKS_GUNSHIP: UnitTypeDef = preload("res://data/units/skyworks_gunship.tres")
const SKYWORKS_INTERCEPTOR: UnitTypeDef = preload("res://data/units/skyworks_interceptor.tres")
# ★ Galactic Protectorate (faction wave 5).
const SERVITOR: UnitTypeDef = preload("res://data/units/servitor.tres")
const DEMOLITIONS_SPECIALIST: UnitTypeDef = preload("res://data/units/demolitions_specialist.tres")
const LANCE_SPECIALIST: UnitTypeDef = preload("res://data/units/lance_specialist.tres")
const SUPPORT_SPECIALIST: UnitTypeDef = preload("res://data/units/support_specialist.tres")
const SENTINEL_MECH: UnitTypeDef = preload("res://data/units/sentinel_mech.tres")
const BREAKER_MECH: UnitTypeDef = preload("res://data/units/breaker_mech.tres")
const LANCE_TANK: UnitTypeDef = preload("res://data/units/lance_tank.tres")
const CINDER_TANK: UnitTypeDef = preload("res://data/units/cinder_tank.tres")
const STRAFER: UnitTypeDef = preload("res://data/units/strafer.tres")
const AUTONOMOUS_LIFTER: UnitTypeDef = preload("res://data/units/autonomous_lifter.tres")
const TALON: UnitTypeDef = preload("res://data/units/talon.tres")

## ★ Every unit type in the roster, in declaration order.
##
## Exists so a coverage check can enumerate the roster instead of transcribing it.
## ⚠ The art-coverage guard used to hold its OWN hand-written list of types, which
## meant it only ever guarded the types someone had remembered to add — the Builder
## shipped with no sprite and the suite stayed green, which is precisely the failure
## that list was written to prevent. Adding a `.tres` to this registry now
## automatically extends the guard.
const ALL: Array[UnitTypeDef] = [BUILDER, SCOUT, TROOPER, HEAVY, SNIPER, TANK, ARTILLERY, FIGHTER, BOMBER, HELICOPTER, TRANSPORT,
	CITIZEN_TROOPER, PILOT, MEDIC, VOLUNTEER, LANCE_TEAM, GUN_TRUCK, ARMOURED_TRANSPORT, INTERCEPTOR, GUNSHIP, PARATROOPER_TRANSPORT,
	PARTISAN, PIRATE, SABOTEUR, MARKSMAN, MISSILE_TEAM, TECHNICAL, SCRAP_TANK, BUZZARD,
	MACHINIST, FOREMAN, GUARD, WALKER, SIEGE_MECH, HAULER, LANCER, BATTERY, SKYWORKS_GUNSHIP, SKYWORKS_INTERCEPTOR,
	SERVITOR, DEMOLITIONS_SPECIALIST, LANCE_SPECIALIST, SUPPORT_SPECIALIST, SENTINEL_MECH, BREAKER_MECH, LANCE_TANK, CINDER_TANK, STRAFER, AUTONOMOUS_LIFTER, TALON]
