## OpponentSummaryWidget — who you are fighting, at a glance (holo-glass HUD, 2026-10-01).
##
## The opponent's faction name in their hue and how many units they field. Replaces the old
## OPPONENT panel's "AP 0 / CR 0", which read 0 for the whole of the player's turn (the
## opponent's pool is only refilled on their own turn) and so said nothing useful.
class_name OpponentSummaryWidget
extends HudReactiveControl

var _player: int = 1


func configure(opponent: int) -> void:
	_player = opponent
	queue_redraw()


func _on_action_applied(_result: ActionResult) -> void:
	queue_redraw()


## "THE LIGHTLESS" — the opponent's faction, upper-cased.
func faction_text() -> String:
	var f: FactionDef = _reader.faction_of(_player) if _reader != null else null
	return (f.display_name if f != null else "OPPONENT").to_upper()


func units_text() -> String:
	var n: int = _reader.unit_count(_player) if _reader != null else 0
	return "%d UNIT%s" % [n, "" if n == 1 else "S"]


func _draw() -> void:
	if _reader == null:
		return
	var hue: Color = UiTheme.player_hue(_player)
	draw_rect(Rect2(Vector2(0, 4), Vector2(9, 9)), hue)
	# Long names ("THE ACCORD OF INNER SYSTEMS") step the size down to fit rather than clip.
	var f: Font = UiTheme.label_font()
	var fs: int = UiTheme.SIZE_SMALL
	while fs > 9 and f.get_string_size(faction_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 18:
		fs -= 1
	draw_string(f, Vector2(18, 14), faction_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
	draw_string(UiTheme.label_font(), Vector2(18, 32), units_text(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		UiTheme.SIZE_LABEL, UiTheme.TEXT_MUTED)
