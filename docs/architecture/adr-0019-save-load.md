# ADR-0019: Save & Load — Explicit JSON Snapshots of GameState

## Status
Accepted (2026-09-29)

## Context
The user chose, on 2026-09-29: an **autosave at the start of each of the player's turns** with a
**Continue** entry on the main menu, **three manual slots** (Save from the pause menu, Load from the
main menu), and **"Save & Quit to Menu"** replacing the destructive Quit.

All authoritative match state already lives in the `GameState` Resource tree (`GridState`,
`PlayerState`, `UnitState`, `StructureState`), every field `@export` for `duplicate_deep()`. Shared
game data (unit/structure/tech/faction/map types) is referenced by identity — `StructureState.is_hq()`
compares against the `StructureTypes.HQ` object itself. Two pieces of per-match state live outside
it: `Balance.economy` (the AP-per-turn copy) and the selected map (`VSMap`). There is no mid-match
RNG (ADR-0003), and the AI keeps no state between turns.

## Decision
- **D1 — Explicit JSON, not Godot resource files.** `SaveGame` (src/core/save/save_game.gd) writes
  `user://saves/<slot>.json`. `ResourceSaver` would be one call, but loading a `.tres` can instantiate
  any script it names, so a shared or tampered save becomes a way to run code. JSON is inert.
- **D2 — Only five classes are ever built from a save** (`_CLASSES`: GameState, GridState,
  PlayerState, UnitState, StructureState), and **shared data is stored by `res://data/` path** and
  re-resolved through `load()`. This returns the same cached object the rest of the game holds, so
  identity checks keep working. Any reference outside `res://data/`, or of the wrong type, rejects
  the **whole** save.
- **D3 — Fields are discovered, not listed.** Every `@export` property is written, found through
  `get_property_list()`. A field added later is saved automatically; a field missing from an older
  save keeps its default. `VERSION` guards against saves from a *newer* build.
- **D4 — Settings outside the state travel with it:** `ap_per_turn` (re-applied via
  `Balance.apply_match`) and the map path (`VSMap.select`). A loaded match also sets
  `MatchSettings.current` (not written to disk) so that Restart replays *that* matchup.
- **D5 — Atomic writes:** each save is written to `<slot>.json.tmp`, then renamed into place.
- **D6 — Hand-over:** the menu sets `SaveGame.pending`; `VerticalSliceRoot._build_match()` consumes
  it in place of `MatchSetup.build`. Autosave runs when the AI hands the turn back (and at match
  start); a finished match deletes the autosave. Saving mid-AI-turn is safe: every commit leaves
  the state whole, and a match loaded on the AI's turn hands straight back to it.
- **D7 — Tests never touch the player's saves:** under `OVERCLOCK_TESTS=1`, `SaveGame.dir()` is
  `user://test_saves`.

## Consequences
- ✅ The round-trip test plays a real match, saves, loads, and plays both copies on. They stay
  identical, compared by an independent walker (not the save encoder). A break-it check (dropping
  two fields from saves) was caught.
- ⚠ Save size grows with the board and is written every player turn. It is not yet measured on
  a late, crowded Highlands game; revisit if it ever shows up as a hitch.
- ⚠ A new *kind* of state object (a sixth class) needs adding to `_CLASSES`, and the round-trip
  test will fail until it is.
- UI-only state (selection, cursor, open menus, the action log) is not saved. A loaded match opens
  deselected.

## ADR Dependencies
- **ADR-0003** (deterministic simulation): no mid-match RNG, so a snapshot of `GameState` is a
  complete save; the play-on test relies on this determinism.
- **ADR-0005** (map authoring): the grid is saved as built, and the map is referenced by path.
- **ADR-0007** (structure identity): `is_hq()` compares by object identity, which D2 preserves.

## Engine Compatibility
Redot 26.2 (Godot 4.6 API). Uses `JSON`, `FileAccess`, `DirAccess.rename_absolute` (atomic
replace on the same volume), `Object.get_property_list()` usage flags
(`PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE`), and `Script.get_global_name()`.
JSON numbers load as floats; D3's decoder casts back to each property's declared type.

## GDD Requirements Addressed
- `design/ux/main-menu.md` — Continue / Load Game entries (previously "persistence deferred").
- `design/ux/pause.md` — Save Game; Quit becomes Save & Quit (the confirm gate existed only because
  the slice had no save).
- User decisions of 2026-09-29, recorded in `design/decision-log.md` ("Save / load").
