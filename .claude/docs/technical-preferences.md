# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Redot 26.2 (Godot 4.x-compatible fork) — binary at `./redot`
- **Language**: GDScript (primary). C# may be added incrementally for
  performance-critical systems (deep AI search, large-map pathfinding) if
  profiling shows GDScript is a bottleneck — Redot supports mixing both.
- **Rendering**: Forward+ (default renderer; 2D isometric has no need for Mobile/Compatibility's reduced feature set)
- **Physics**: Godot Physics 2D (standard for grid-based tactics; Jolt targets 3D and is not relevant here)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam / Epic) + **Steam Deck**
- **★ Target Hardware Floor**: **Steam Deck** (decided 2026-08-25, S7-08) — 1280×800, Zen 2 4c/8t, RDNA 2 8 CU, 16 GB *shared* LPDDR5, 15 W
- **Quality Target**: 1920×1080 and 2560×1440 desktop
- **Input Methods**: Keyboard/Mouse (primary), Gamepad (**required**, not secondary)
- **Primary Input**: Keyboard/Mouse on desktop; **gamepad on the floor target**
- **Gamepad Support**: **Full — required.** Was "Partial"; the Deck floor makes it a hard requirement, not a nice-to-have
- **Touch Support**: None (the Deck's touchscreen is not a design target; its trackpads present as a mouse)
- **Platform Notes**: Mouse-driven grid tactics. No hover-only interactions — every core action must be reachable by click (and, where practical, a keyboard shortcut). Keep the board readable at **1280×800 first**, then 1080p and 1440p.

> ### ★ Why the Deck is the floor, and what it costs
> The game packages to **5.1 MB** and peaks at **145 MB** headless, so nothing about this choice
> is about whether it runs. The Deck was chosen because it is **the tightest constraint that
> actually improves the product**: it forces the board and text to stay readable small, and it
> turns "partial gamepad support" into an obligation. Turn-based tactics is also a genre that
> sells on the device.
>
> ★ **Most of the legibility work is already done against it** — the S5-03 iso-legibility gate
> was measured at **1280×720**, slightly *tighter* than the Deck's 1280×800.

> ### ⛔ Known gaps against Steam Deck Verified — recorded, not yet fixed
> These are cert criteria, and each is cheap now and expensive at submission.
> 1. **Controller glyphs.** The on-screen legend names keyboard keys (`[Arrows]`, `[Enter]`,
>    `[Esc]`) regardless of the active device. Verified requires controller glyphs when a
>    controller is in use. The bindings all exist (S6-17/20/23/25); only the *display* is wrong.
> 2. ◐ **Text legibility at 1280×800 — partly addressed 2026-08-25 (S8-07).**
>    `GameSettings.recommended_ui_scale()` now returns **1.15** for a floor-class display
>    (≤1366 wide) when the player has not chosen a scale, lifting the menu's 22 px body text to
>    ~25 px against the Standard tier's 20 px floor. It writes no override, so a player still
>    inherits future default changes, and an explicit choice always wins.
>    ★ **Layout is not the constraint** — the HUD was measured at 1280×800 across the full
>    1.00–1.50 settings range with **zero plate collisions**, and
>    `tests/integration/settings/ui_scale_floor_layout_test.gd` keeps it that way.
>    ⛔ **Still open:** the value is reasoned, not observed. **No Deck has run this build**, so
>    whether 1.15 is actually comfortable on a 7″ panel is unverified. Layout tolerates far more,
>    so it can be raised on evidence without touching anything else.
> 3. **Idle power draw.** `low_processor_usage_mode` is not set. A turn-based game renders a
>    static board at full rate while the player thinks — on a handheld that is battery and heat
>    spent on nothing. ⚠ **But it is not the one-line fix it looks like**: the board is never
>    fully static — the glow shader pulses continuously and unit motion runs on tweens, so
>    sleeping the main loop would make both choppy. The real fix is conditional (throttle only
>    while genuinely idle, or lower `max_fps` when no animation is in flight) and wants measuring
>    on the device. **Recorded as a gap, deliberately not fixed blind.**
> 4. **Native Linux build.** An export preset now exists (S7-03) and the Deck runs Linux
>    natively; whether to ship native or via Proton is undecided.

## Naming Conventions

- **Classes**: PascalCase (e.g., `UnitController`)
- **Variables/functions**: snake_case (e.g., `move_speed`, `end_turn()`)
- **Signals/Events**: snake_case, past tense (e.g., `turn_ended`, `unit_moved`)
- **Files**: snake_case matching class (e.g., `unit_controller.gd`)
- **Scenes**: PascalCase matching root node (e.g., `UnitController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_ACTION_POINTS`)

> Use static typing in GDScript (`var hp: int = 10`) — it catches bugs and is
> meaningfully faster in the tight loops a turn-based AI hits.

## Performance Budgets

Measured on 2026-08-25 and set against the Steam Deck floor. **Every figure below has a
number behind it** — these are budgets with headroom, not aspirations.

| Budget | Value | Basis |
|---|---|---|
| **Target Framerate** | **60 FPS** on the Deck at 1280×800 | Deck LCD is 60 Hz; OLED does 90 but 60 is the honest floor |
| **Frame Budget** | **16.6 ms/frame** | 1/60 |
| **Draw Calls** | **< 500** | Generous for 2D isometric; TileMap batching keeps this far lower |
| **★ Memory Ceiling** | **1 GB resident**, soft alert at **700 MB** | Measured **145 MB** headless with no textures resident; expect ~400–600 MB rendering. The ceiling is ~7× current usage — a tripwire for a leak or an asset mistake, not a target to grow into |
| **VRAM / texture budget** | **512 MB** | The Deck shares its 16 GB, so texture memory is taken from the same pool the OS needs |
| **Package size** | **< 2 GB** | Currently **5.1 MB**. Recorded so a future asset wave has a stated limit |

> ★ **Turn-based means there is no simulation deadline.** 60 FPS buys smooth camera and UI feel,
> nothing else — a turn can take as long as it takes. ⚠ The corollary matters on a handheld:
> **the frame budget is not the power budget.** A static board rendered 60 times a second costs
> the same battery as a busy one, which is what gap 3 above is about.
>
> ⚠ **These are unverified on real hardware.** No Deck has run this build; the numbers are
> measured on a desktop and reasoned to the target. **Re-measure on the device before trusting
> any of them**, and before quoting a minimum spec on a store page.

## Testing

- **Framework**: GDUnit4 (addon) — run via `./redot --headless --script tests/gdunit4_runner.gd`
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, turn/combat resolution, AI decision logic, gameplay systems

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist (Redot is Godot-4-compatible — the Godot agent set applies)
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved. When C# is added later, route .cs files to godot-csharp-specialist.

> **Redot note**: These `godot-*` agents target Godot 4 APIs, which Redot is
> compatible with. For anything Redot-specific or post-Godot-4.3, agents must
> cross-reference `docs/engine-reference/godot/VERSION.md` and verify via WebSearch.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | Primary |
