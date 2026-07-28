# Story 008: `HudAudioDispatcher` — Single-Owner `play()` + Total Priority Order + Ducking

> **Epic**: Game HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: 2026-07-28

## Context

**GDD**: `design/gdd/game-hud.md`
**Requirement**: `TR-hud-021`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016: Game HUD (primary, §7)
**ADR Decision Summary**: A single HUD-owned `HudAudioDispatcher` is the sole `play()` chokepoint for every HUD audio event, resolving collisions against one total priority order (`GameOver > turn-change stinger > completion cue (deduped) > AP-fill arpeggio`); lower-priority cues duck except `GameOver` which hard-preempts; audio binds to the commit signal, never a value-change.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: MEDIUM
**Engine Notes**: `AudioStreamPlayer.play()` is stable ≤4.3, but true *ducking* (quieter-but-audible, not replace) requires ≥2 `AudioStreamPlayer` children/bus sends managed internally (a single player replaces rather than layers) — godot-specialist guidance from ADR-0016, NOT yet spiked against the live 4.6 audio bus API. **Recommend a small spike or a `/story-readiness` check before this story starts.**

**Control Manifest Rules (this layer)**:
- Required: A single HUD-owned `HudAudioDispatcher` must be the sole `play()` chokepoint for every HUD audio event — no widget plays its own sound — source: ADR-0016
- Required: Audio collisions must resolve against a single total priority order (highest first): `GameOver > turn-change stinger > completion cue (deduped) > AP-fill arpeggio` — source: ADR-0016
- Forbidden: Never let each cue's owning system play its own sound independently; never bind audio to a value-change (`ap_changed`) instead of the commit signal — source: ADR-0016

---

## Acceptance Criteria

*From GDD `design/gdd/game-hud.md`, scoped to this story:*

- [ ] GIVEN a committed action, THEN the AP-tick sound's playback call is invoked exactly one time total across CAI and the HUD (call-count spy on the audio entry point); GIVEN a start-of-turn income fill, THEN the fill sound's playback is invoked exactly once (AC-20)
- [ ] GIVEN 2+ completion cues (Research-complete/Structure-complete) resolve in the same or adjacent frames, THEN at most one completion cue plays that frame (2nd+ ducked/suppressed) while every on-board completion marker still updates individually (AC-23)
- [ ] The dispatcher resolves collisions against the single total priority order, highest first: `GameOver > turn-change stinger > completion cue (deduped) > AP-fill arpeggio`
- [ ] A lower-priority cue in any collision is ducked (attenuated under `HUDConfig.hud_audio_duck_ms`), except `GameOver`, which hard-preempts (cut, not ducked) — no stinger-then-fanfare double-beat on a game-ending transition
- [ ] Audio binds to the **commit** signal (`action_applied`) never to a value-change (`ap_changed`) that could fire for non-commit reasons and double-trigger

---

## Implementation Notes

*Derived from ADR-0016 §7:*

- `HudAudioDispatcher` is the sole `.play()` chokepoint for every HUD audio event — no widget (Story 004 AP counter, Story 006 victory/defeat, Story 007 Build button) plays its own sound; each subscribes to the same signals for *visuals only* and stays audio-silent.
- "Sole caller" is a code-level chokepoint (one dispatcher class owns every `.play()` call), not literally one `AudioStreamPlayer` node — since one `AudioStreamPlayer` plays one stream at a time (a second `play()` replaces rather than layers), true ducking requires ≥2 `AudioStreamPlayer` children/bus sends the dispatcher manages internally (e.g. one for stinger/`GameOver`, one for fill/completion).
- Subscribes to: `action_applied` (AP-tick, bound to commit not value-change), `start_turn` (AP-fill arpeggio + turn-change stinger), `StructureCompletedEvent`/`TechCompletedEvent` (ride `action_applied`) → completion cues, `match_status → GameOver` → victory/defeat cue.
- The attack-commit sound is explicitly NOT owned here — Combat triggers it off the same `action_applied` event — this dispatcher must not duplicate it.
- Structure-complete reuses CAI's Build-stamp *asset* (feel reuse) but the *trigger* is Base & Production's build-timer hitting 0, not CAI's build-commit moment — asset reuse ≠ trigger ownership; do not wire this off CAI's commit signal.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The actual audio assets/mix (owed to art-bible/audio-director, OQ-6)
- The defeat-cue tone pass (flagged for creative-director sign-off — implement the mechanism; the asset/tone is a follow-up)

---

## QA Test Cases

- **AC-20 (Logic)**: Given both CAI's commit-flash handler and the HUD's AP-tick handler subscribe to the same `action_applied` event, When a commit resolves, Then a call-count spy on the audio entry point records exactly 1 invocation for the AP-tick sound.
- **AC-23 (Logic)**: Given a Research-complete and a Structure-complete land in the same frame, When the dispatcher resolves, Then exactly 1 completion cue plays while both on-board markers update independently.
- **AC (GameOver hard-preempt — Logic)**: Given a turn-change stinger and a `GameOver` cue collide on the same transition, When priority resolves, Then the stinger is cut (not ducked) and only the `GameOver` cue plays.
- **AC (duck — Integration)**: Given a turn-change stinger and an AP-fill arpeggio collide, When resolved, Then the AP-fill is ducked under `hud_audio_duck_ms` (not cut), both remaining audible at different volumes — assert both streams are non-null/playing simultaneously at different volume levels (requires ≥2 `AudioStreamPlayer`s).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/game-hud/hud_audio_dispatcher_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`HUDConfig.hud_audio_duck_ms`), and cross-epic **CAI Story 007** (shared `action_applied` signal for the AP-tick trigger) + Base & Production's `StructureCompletedEvent`/Research's `TechCompletedEvent` (shipped, ride `action_applied`). Conceptually needs Stories 004/006/007's trigger points defined (no shared files).
- Unlocks: None (last story in the epic)

---

## Completion Notes
**Completed**: 2026-07-28
**Criteria**: 5/5 passing, all COVERED (no deferred criteria).
**Deviations**: None blocking. Advisory (by design, per this story's Out of Scope):
- Audio stream **assets** are not wired — with no `AudioStream` assigned, the
  chokepoint records the play + sets channel volume but skips the engine
  `play()` (a null-stream `play()` would error). The mechanism is the
  deliverable; assets land with the audio bible (OQ-6).
- The duck attenuation **level** (`HudAudioDispatcher.DUCK_VOLUME_DB = -12.0`) is
  a documented placeholder mix value pending audio-director sign-off (OQ-6); the
  duck **duration** is the real data-driven `HUDConfig.hud_audio_duck_ms` knob.
**Test Evidence**: Integration — `tests/integration/game-hud/hud_audio_dispatcher_test.gd`
(13 tests, PASS). Full suite 788/788, 0 failures, 0 orphans, 72/72 suites.
**Code Review**: Complete — independent `godot-gdscript-specialist`
(APPROVE-WITH-SUGGESTIONS) + coordinator; all suggestions addressed (stale doc
reference removed, `Array[int]` typing applied, lint trade-off documented, two
coverage tests added: three-way LOW-channel collision + duck-restore).

**Implementation**:
- NEW `src/ui/game_hud/hud_audio_dispatcher.gd` (`HudAudioDispatcher` extends
  `Node`) — sole HUD `play()` chokepoint. `enum Cue{GAME_OVER, TURN_STINGER,
  COMPLETION, AP_FILL, AP_TICK}` (enum value = collision rank). Pure static
  `resolve_plan(requested)` → `{primary, ducked, suppressed}` (dedup + priority +
  GameOver-hard-cut-vs-duck). Subscribes `action_applied` via the `GameStateReader`
  broker; `_gather_cues` reads GameOver/completions from `result.events` and
  detects the turn boundary via `active_player`/`round` change (mirrors
  `ApCounterWidget`); two internally-managed `AudioStreamPlayer` channels (HIGH:
  stinger/GameOver, LOW: completion/fill/tick) per ADR-0016 §7. Guarded
  subscribe/`_exit_tree` unsubscribe; no orphans.
- NEW `tests/integration/game-hud/hud_audio_dispatcher_test.gd` (13 tests).
