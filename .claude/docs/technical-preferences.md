# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Redot 26.2 (Godot 4.x-compatible fork) — binary at `./redot`
- **Language**: GDScript (primary). C# may be added incrementally for
  performance-critical systems (deep AI search, large-map pathfinding) if
  profiling shows GDScript is a bottleneck — Redot supports mixing both.
- **Rendering**: Forward+ (default renderer; 2D top-down has no need for Mobile/Compatibility's reduced feature set)
- **Physics**: Godot Physics 2D (standard for grid-based tactics; Jolt targets 3D and is not relevant here)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam / Epic)
- **Input Methods**: Keyboard/Mouse (primary), Gamepad (secondary)
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: Mouse-driven grid tactics. No hover-only interactions — every core action must be reachable by click (and, where practical, a keyboard shortcut) so a gamepad/cursor port stays feasible. Keep the board readable at 1080p and 1440p.

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

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.6 ms/frame
- **Draw Calls**: < 500 (generous for 2D top-down; TileMap batching should keep this low)
- **Memory Ceiling**: [TO BE CONFIGURED — set when target hardware is known; 2D tactics is light]

> Defaults for a 2D top-down tactics game; re-tune against real target hardware
> once the prototype exists. Turn-based means no hard real-time constraint —
> 60 FPS is for smooth camera/UI feel, not simulation deadlines.

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
