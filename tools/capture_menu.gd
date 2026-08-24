## capture_menu.gd — screenshots the real main menu (default and quit-confirm).
## Usage: `./redot tools/CaptureMenu.tscn` (needs a display)
extends Node

const OUT: String = "res://production/qa/evidence/main-menu"
const VIEW: Vector2i = Vector2i(1600, 900)


func _ready() -> void:
	get_window().size = VIEW
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run()


func _run() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot("01-menu-default")

	menu.open_quit_confirm()
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot("02-quit-confirm")
	menu.close_quit_confirm()
	for i: int in 4:
		await get_tree().process_frame
	# --- the settings screen, opened the way the menu opens it ------------------
	var screen := SettingsScreen.new()
	menu.add_child(screen)
	for i: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot("03-settings")

	# Override two bindings so the "changed" marking and the live reset affordance
	# are both visible — the default state shows neither.
	Settings.settings.set_binding(&"board_act", GameSettings.Device.KEYBOARD, KEY_F1)
	Settings.settings.set_binding(&"board_build", GameSettings.Device.GAMEPAD, 11)
	screen._refresh_all()
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot("04-settings-overridden")
	Settings.settings.reset_to_defaults()
	Settings.settings.apply_all()
	print("done")
	get_tree().quit()


func _shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/%s.png" % [OUT, name]))
	print("  wrote ", name)
