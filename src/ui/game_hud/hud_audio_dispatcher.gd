## HudAudioDispatcher — the single HUD-owned [code]play()[/code] chokepoint for
## every HUD audio event, resolving collisions against one total priority order
## (Game HUD Story 008, TR-hud-021, ADR-0016 §7).
##
## [b]Sole caller[/b]: no widget plays its own sound. The AP counter (Story 004),
## the victory/defeat overlay (Story 006), the Build button (Story 007) and #9's
## commit-flash all subscribe to the same [signal GameState.action_applied] for
## their [i]visuals only[/i] and stay audio-silent — so the AP-tick
## [code]play()[/code] is invoked exactly once across #9 and the HUD (AC-20),
## never doubled. This class is that one owner: every play routes through the
## single [method _play_cue] chokepoint.
##
## [b]Total priority order[/b] (highest first, ADR-0016 §7):
## [code]GameOver > turn-change stinger > completion cue (deduped) > AP-fill
## arpeggio[/code]. [enum Cue] is declared in exactly this order so a cue's enum
## value IS its collision rank ([constant Cue.GAME_OVER] = 0, highest). The
## ordinary per-commit [constant Cue.AP_TICK] is the least-significant cue, ranked
## last — it sounds alone on a plain spend and always defers to any higher cue.
##
## [b]Duck vs. hard-cut[/b]: in a collision the highest-priority requested cue
## plays at full volume; every lower requested cue is [i]ducked[/i] (played
## attenuated under [member HUDConfig.hud_audio_duck_ms]) — [b]except[/b]
## [constant Cue.GAME_OVER], which [i]hard-preempts[/i] (the others are cut, not
## ducked, so there is no stinger-then-fanfare double-beat on a game-ending
## transition). Simultaneous completion cues dedupe to one played cue that frame
## (AC-23); the on-board completion markers still update individually — that is
## the on-board glyph layer's concern (Story 005), not this dispatcher's.
##
## [b]Bound to the commit signal, never a value-change[/b]: the dispatcher only
## reacts to [signal GameState.action_applied] (via the [GameStateReader] broker,
## so it never holds a live [GameState]) — never to an [code]ap_changed[/code]
## value-change that could fire for non-commit reasons and double-trigger. Every
## trigger rides that one signal: the AP-tick on the commit itself; the turn
## stinger + AP-fill on a turn boundary (which folds [method GameState.start_turn]
## into [method GameState.apply_action]'s emitted [ActionResult]); the completion
## cues on [StructureCompletedEvent]/[TechCompletedEvent] in [member
## ActionResult.events]; the GameOver cue on a [GameOverEvent] / terminal
## [method GameStateReader.match_status].
##
## [b]Two channels[/b]: "sole caller" is a code-level chokepoint (this class owns
## every [code]play()[/code]), not a single [AudioStreamPlayer] — one player plays
## one stream at a time (a second [code]play()[/code] replaces rather than
## layers), so true ducking (quieter-but-audible) needs ≥2 players the dispatcher
## manages internally (ADR-0016 §7; engine-reference [code]modules/audio.md[/code]
## concurrent-sound pool). This dispatcher owns a HIGH channel (stinger/GameOver)
## and a LOW channel (completion/fill/tick); each sounds only its highest-priority
## assigned cue.
##
## [b]Assets are out of scope[/b] (OQ-6, audio-director / art-bible): this story
## delivers the [i]mechanism[/i] — the chokepoint, the priority resolution, the
## duck/cut decision, the two channels. No [AudioStream] resources are wired here,
## so with no stream assigned the actual engine [code]play()[/code] is skipped
## (the chokepoint call-count + channel volume are the observable contract). The
## duck attenuation LEVEL ([constant DUCK_VOLUME_DB]) is likewise a placeholder
## mix value pending audio-director sign-off; the duck DURATION is the real
## data-driven [member HUDConfig.hud_audio_duck_ms] knob.
##
## Usage:
## [codeblock]
## var audio := HudAudioDispatcher.new()
## audio.bind(reader)              # broker DI (mirrors HudReactiveControl)
## audio.configure(HudBalance.hud) # duck-window duration
## hud_layer.add_child(audio)      # _ready() subscribes + builds the 2 channels
## [/codeblock]
class_name HudAudioDispatcher
extends Node

## The HUD audio cues, declared in DESCENDING priority — a cue's enum value is
## its collision rank (lower value = higher priority). The first four are
## ADR-0016 §7's verbatim total order; [constant AP_TICK] (the ordinary
## per-commit tick) is appended last as the least-significant cue.
enum Cue { GAME_OVER, TURN_STINGER, COMPLETION, AP_FILL, AP_TICK }

## Full (un-ducked) channel volume, in decibels.
const _FULL_VOLUME_DB: float = 0.0

## Placeholder duck attenuation (decibels) — a lower-priority cue in a collision
## plays this much quieter, still audible (not cut). The FINAL mix level is owed
## to the audio-director (OQ-6, Out of Scope for this story); this value only
## has to be audibly below [constant _FULL_VOLUME_DB] to realise the mechanism.
## The duck DURATION is the data-driven [member HUDConfig.hud_audio_duck_ms].
const DUCK_VOLUME_DB: float = -12.0

## The injected read-only facade (never a live [GameState] — ADR-0016 §1). Set
## via [method bind]; used for the turn-boundary + terminal-status reads.
var _reader: GameStateReader = null

## The loaded [HUDConfig] (duck-window duration). Injected via [method configure].
var _config: HUDConfig = null

## Last-observed active player / round — a change since the previous commit marks
## a genuine turn boundary (start-of-turn stinger + AP-fill). [member _synced]
## guards the baseline so the first observed commit is never mistaken for one.
var _prev_active: int = -1
var _prev_round: int = -1
var _synced: bool = false

## The two internally-managed [AudioStreamPlayer] children (ADR-0016 §7). HIGH
## sounds stinger/GameOver; LOW sounds completion/fill/tick. Built once in
## [method _ready].
var _channel_high: AudioStreamPlayer = null
var _channel_low: AudioStreamPlayer = null

## Per-cue [code]play()[/code] invocation counts through the single chokepoint —
## the observable "audio entry point" the AC-20/AC-23 spies assert on.
var _play_counts: Dictionary = {}

## The most recently rendered plan (see [method resolve_plan]) — inspectable.
var _last_plan: Dictionary = {"primary": -1, "ducked": [], "suppressed": []}


## Injects the [param reader] broker (DI seam, mirrors [HudReactiveControl.bind]).
## Safe before or after tree entry: if already in-tree, subscribes + baselines
## now; otherwise [method _ready] does so on entry. Idempotent via the reader's
## own [code]is_connected[/code] guard.
func bind(reader: GameStateReader) -> void:
	_reader = reader
	if is_inside_tree():
		_reader.subscribe_action_applied(_on_action_applied)
		_sync_baseline()


## Injects the [param config] (duck-window duration). Call after [method bind];
## baselines the turn tracker from the reader if one is already bound.
func configure(config: HUDConfig) -> void:
	_config = config
	_sync_baseline()


func _ready() -> void:
	_ensure_channels()
	if _reader != null:
		_reader.subscribe_action_applied(_on_action_applied)
		_sync_baseline()


## Guarded unsubscribe on tree exit (mirrors [HudReactiveControl._exit_tree]) so
## connections never accumulate across a match restart within one process.
func _exit_tree() -> void:
	if _reader != null:
		_reader.unsubscribe_action_applied(_on_action_applied)


## Reacts to a successful commit: gather the cues this commit raised, resolve
## them against the total priority order, and render the resulting plan. This is
## the sole reaction path — the dispatcher never polls, never binds a
## value-change signal (ADR-0016 §7/§8).
func _on_action_applied(result: ActionResult) -> void:
	var cues: Array = _gather_cues(result)
	var plan: Dictionary = resolve_plan(cues)
	_render_plan(plan)


## Resolves the set of cues one commit raised against ADR-0016 §7's total
## priority order. Returns a plan [Dictionary]:
## [code]{ "primary": int, "ducked": Array[int], "suppressed": Array[int] }[/code].
## [br]• [code]primary[/code] — the single highest-priority requested cue (played
##   at full volume), or [code]-1[/code] if none were requested.
## [br]• If [code]primary[/code] is [constant Cue.GAME_OVER], every other cue is
##   SUPPRESSED (hard-cut, not played) and [code]ducked[/code] is empty.
## [br]• Otherwise every lower-priority requested cue is DUCKED (played
##   attenuated) and [code]suppressed[/code] is empty.
## [br]Duplicate cues collapse (a set), so N simultaneous [constant Cue.COMPLETION]
## cues dedupe to one (AC-23). Pure + deterministic: no engine state, no side
## effects — the headless-testable heart of the dispatcher.
static func resolve_plan(requested: Array) -> Dictionary:
	var uniq: Array[int] = []
	for c: int in requested:
		if not uniq.has(c):
			uniq.append(c)
	if uniq.is_empty():
		return {"primary": -1, "ducked": [], "suppressed": []}
	uniq.sort() # ascending Cue value == descending priority.
	var primary: int = uniq[0]
	var rest: Array[int] = uniq.slice(1)
	if primary == Cue.GAME_OVER:
		return {"primary": primary, "ducked": [], "suppressed": rest}
	return {"primary": primary, "ducked": rest, "suppressed": []}


## Inspects a commit and returns the cues it raises, in gather order (priority is
## applied later by [method resolve_plan]). See the class doc comment for how each
## trigger rides [signal GameState.action_applied].
func _gather_cues(result: ActionResult) -> Array[int]:
	var cues: Array[int] = []

	# GameOver + completion cues ride the commit's event stream.
	var game_over: bool = false
	var completion: bool = false
	for e: Event in result.events:
		if e is GameOverEvent:
			game_over = true
		elif e is StructureCompletedEvent or e is TechCompletedEvent:
			completion = true
	# Corroborate GameOver with the terminal status (a GameOver commit may land
	# match_status even if the event stream is inspected defensively).
	if _reader != null and _reader.match_status() == GameState.MatchStatus.GAME_OVER:
		game_over = true
	if game_over:
		cues.append(Cue.GAME_OVER)
	if completion:
		cues.append(Cue.COMPLETION)

	# A turn boundary (start_turn folded into this commit) raises BOTH the
	# turn-change stinger and the start-of-turn AP-fill arpeggio (ADR-0016 §7).
	# Detected the same way ApCounterWidget does: active_player/round changed
	# since the previous observed commit.
	var transition: bool = false
	if _reader != null:
		var active: int = _reader.active_player()
		var rnd: int = _reader.round_number()
		transition = _synced and (active != _prev_active or rnd != _prev_round)
		_prev_active = active
		_prev_round = rnd
		_synced = true
	if transition:
		cues.append(Cue.TURN_STINGER)
		cues.append(Cue.AP_FILL)
	elif result.ok:
		# An ordinary in-turn commit → the per-commit AP-tick.
		cues.append(Cue.AP_TICK)

	return cues


## Renders a resolved plan onto the two channels. The primary cue plays at full
## volume; ducked cues play attenuated; suppressed cues are silent. Because each
## [AudioStreamPlayer] sounds one stream, when several sounding cues map to the
## same channel only the highest-priority one is heard (ADR-0016 §7's two-channel
## model); the rest are subsumed. GameOver additionally silences the low channel
## outright (hard-preempt).
func _render_plan(plan: Dictionary) -> void:
	_last_plan = plan
	var primary: int = plan["primary"]
	if primary == -1:
		return

	var sounding: Array[int] = [primary]
	sounding.append_array(plan["ducked"])

	var high_cue: int = -1
	var low_cue: int = -1
	for c: int in sounding:
		if _is_high_channel(c):
			if high_cue == -1 or c < high_cue:
				high_cue = c
		elif low_cue == -1 or c < low_cue:
			low_cue = c

	# GameOver hard-preempts: cut (do not duck) the low channel.
	if primary == Cue.GAME_OVER:
		low_cue = -1
		_silence(_channel_low)

	if high_cue != -1:
		_play_cue(high_cue, _channel_high, _FULL_VOLUME_DB if high_cue == primary else DUCK_VOLUME_DB)
	if low_cue != -1:
		_play_cue(low_cue, _channel_low, _FULL_VOLUME_DB if low_cue == primary else DUCK_VOLUME_DB)


## The SOLE [code]play()[/code] chokepoint (the observable audio entry point).
## Records the invocation, sets the channel volume, and — only when an
## [AudioStream] is actually assigned (assets are OQ-6, Out of Scope) — starts
## engine playback. A ducked cue schedules a restore to full after the configured
## duck window.
func _play_cue(cue: int, channel: AudioStreamPlayer, volume_db: float) -> void:
	_play_counts[cue] = int(_play_counts.get(cue, 0)) + 1
	if channel == null:
		return
	channel.volume_db = volume_db
	# With no stream wired yet, a real play() would push an error — the mechanism
	# (chokepoint call + volume) is this story's deliverable; the stream lands
	# with the audio bible.
	if channel.stream != null:
		channel.play()
	if volume_db < _FULL_VOLUME_DB:
		_schedule_duck_restore(channel)


## Schedules a ducked channel's volume back to full after [member
## HUDConfig.hud_audio_duck_ms]. A no-op outside the tree or with a non-positive
## window (headless tests assert the immediate post-render volumes and never wait
## on this timer).
func _schedule_duck_restore(channel: AudioStreamPlayer) -> void:
	if not is_inside_tree() or _config == null or _config.hud_audio_duck_ms <= 0:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(_config.hud_audio_duck_ms / 1000.0)
	timer.timeout.connect(_on_duck_restore.bind(channel))


func _on_duck_restore(channel: AudioStreamPlayer) -> void:
	if channel != null:
		channel.volume_db = _FULL_VOLUME_DB


func _silence(channel: AudioStreamPlayer) -> void:
	if channel != null and channel.playing:
		channel.stop()


## True iff [param cue] sounds on the HIGH channel (stinger / GameOver).
func _is_high_channel(cue: int) -> bool:
	return cue == Cue.GAME_OVER or cue == Cue.TURN_STINGER


func _ensure_channels() -> void:
	if _channel_high == null:
		_channel_high = AudioStreamPlayer.new()
		_channel_high.name = "HudAudioChannelHigh"
		add_child(_channel_high)
	if _channel_low == null:
		_channel_low = AudioStreamPlayer.new()
		_channel_low.name = "HudAudioChannelLow"
		add_child(_channel_low)


func _sync_baseline() -> void:
	if _reader != null and not _synced:
		_prev_active = _reader.active_player()
		_prev_round = _reader.round_number()
		_synced = true


# --- Inspectable surface (Integration-testable getters) ----------------------

## How many times [param cue] has sounded through the chokepoint (AC-20/AC-23).
func play_count(cue: int) -> int:
	return int(_play_counts.get(cue, 0))

## The most recently rendered plan (see [method resolve_plan]).
func last_plan() -> Dictionary:
	return _last_plan

## The HIGH channel ([AudioStreamPlayer]: stinger / GameOver) — for volume/level
## assertions (the duck AC needs both channels' volumes read directly).
func channel_high() -> AudioStreamPlayer:
	return _channel_high

## The LOW channel ([AudioStreamPlayer]: completion / fill / tick).
func channel_low() -> AudioStreamPlayer:
	return _channel_low
