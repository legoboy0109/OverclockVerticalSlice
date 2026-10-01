## Balance — the economy tuning in force (ADR-0006: every system reads `Balance.economy`).
##
## ★ 2026-09-28 (match settings): `economy` is the config for the CURRENT match. A player-chosen
## AP-per-turn is applied to a per-match COPY ([method apply_match]), never to the shared preload,
## so one match's choice can never leak into the next, into the simulator, or into a test.
## It is deliberately not on GameState: GameState.clone() deep-copies, and the AI clones
## constantly — the config would be copied thousands of times a turn for nothing.
extends Node

## The designer's values, as shipped. Never modified.
var base_economy: EconomyConfig = preload("res://data/balance/economy_config.tres")

## The values in force for the current match.
var economy: EconomyConfig = base_economy


## Starts a match's economy: a fresh copy of the shipped values with the player's AP choice
## and upkeep rule.
func apply_match(ap_per_turn: int, upkeep_enabled: bool = true) -> void:
	economy = base_economy.duplicate()
	economy.flat_ap_per_turn = ap_per_turn
	economy.upkeep_enabled = upkeep_enabled


## Back to the shipped values (tests, the simulator, leaving a match).
func reset() -> void:
	economy = base_economy
