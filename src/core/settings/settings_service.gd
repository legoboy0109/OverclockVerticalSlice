## SettingsService — the one live [GameSettings] instance, loaded at boot.
##
## An Autoload for the same reason Balance and UnitTypes are: the settings are
## read from several unrelated screens (main menu, pause menu, the settings screen
## itself, and the slice for reduced motion), and passing an instance down through
## every one of them would mean each screen needed a reference to something it does
## not otherwise care about.
##
## Loading happens HERE, once, at boot — before any screen exists — so a player's
## saved bindings are in the [InputMap] before the first frame that could read
## them. Loading lazily inside the settings screen would mean the game ran on
## default bindings until the player happened to open settings.
extends Node

## The live settings. Read it, mutate it through its own setters, then call
## [method GameSettings.save] to persist.
var settings: GameSettings = null


func _ready() -> void:
	settings = GameSettings.new()
	settings.load_saved()
	settings.apply_all()
