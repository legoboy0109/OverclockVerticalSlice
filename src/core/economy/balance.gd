## Balance — Autoload, logic-free lookup for AP Economy's tuning config.
##
## Foundation-layer Autoload per ADR-0006, mirroring [code]MatchService[/code]'s
## thin "read-only lookup convenience" idiom (ADR-0001). Loads [EconomyConfig]
## once at boot and exposes it by reference. Never mutates, validates, or
## interprets anything — systems read [code]Balance.economy.*[/code] directly;
## only this Autoload decides where the `.tres` lives.
##
## Registered in `project.godot`'s `[autoload]` section so `AP`'s functions can
## read `Balance.economy` as a bare global reference, matching the GDD's
## documented `income(player)` signature (never `income(player, config)`).
extends Node

## The loaded [EconomyConfig] tuning-constants resource. No other fields. No
## methods beyond direct property access.
var economy: EconomyConfig = preload("res://data/balance/economy_config.tres")
