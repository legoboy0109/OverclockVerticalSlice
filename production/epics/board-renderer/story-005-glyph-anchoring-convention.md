# Story 005: On-Board Glyph Anchoring Convention — `GLYPH_OFFSETS`

> **Epic**: Board Renderer
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S–M (2–3h)
> **Manifest Version**: 2026-07-27
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: (ADR-driven — producer-side requirement is `TR-grid-008` in `design/gdd/grid-terrain.md`)
**Requirement**: `TR-grid-008` (owned); delivers `TR-cmdui-017` (CAI D-3 echo + glyph anchors), `TR-hud-010`/`TR-hud-011` (HUD glyph layer, hp-pip-never-occluded)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Isometric Board Rendering, Picking & Overlays (§5, primary)
**ADR Decision Summary**: Every on-board glyph anchors at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, where `GLYPH_OFFSETS` is an art/UX-authored data table; hp-pip-never-occluded is guaranteed by offset-table authoring discipline, not runtime arbitration.

**Engine**: Redot 26.2 (Godot 4.6-compatible) | **Risk**: LOW
**Engine Notes**: The anchor formula is pure arithmetic on `grid_to_screen` + a data table — no new engine API. Legibility/occlusion verification is inherently Visual/Feel (live-editor look) but involves no unconfirmed API. No camera-model decision is made here (OQ-8 is explicitly deferred; the transform is camera-model-agnostic).

**Control Manifest Rules (this layer)**:
- Required: `grid_to_screen(tile)` must double as the sprite placement anchor; author every unit/structure/prop sprite pivot at its ground-contact point (bottom-center) so no extra offset is needed — source: ADR-0013
- Required: Every on-board glyph must anchor at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`, with `GLYPH_OFFSETS` authored as data, not hardcoded literals; hp legibility wins any offset conflict (enforced by authoring discipline, not runtime arbitration) — source: ADR-0013

---

## Acceptance Criteria

*From ADR-0013 §5 + TR-grid-008/TR-hud-011, scoped to this story:*

- [ ] GIVEN a glyph class and a tile, WHEN its anchor point is computed, THEN it equals exactly `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]` — no other computation path exists
- [ ] GIVEN `GLYPH_OFFSETS` is authored as external data (not hardcoded literals in code), WHEN a designer/artist retunes an offset, THEN no code change is required (data-driven per coding-standards.md)
- [ ] GIVEN several glyphs simultaneously present on one crowded tile (e.g. hp pips + has-acted marker + AP-cost badge), WHEN rendered at 1080p and 1440p, THEN the hp pips are never visually occluded by any other glyph (enforced by offset-table authoring, not runtime arbitration)
- [ ] GIVEN the full glyph-class table placed on a test board (hp pips, has-acted, tech marker, structure hp, build-timer badge, research marker, AP-cost badge, damage number, cover glyph, turns numeral, target bracket, D-3 echo), WHEN rendered, THEN every glyph is legible (non-overlapping or intentionally-layered per priority) at both target resolutions

---

## Implementation Notes

*Derived from ADR-0013 §5 (transcribed):*

- Anchor convention (exact): every on-board glyph anchors at `grid_to_screen(tile) + GLYPH_OFFSETS[glyph_class]`.
- `GLYPH_OFFSETS` is a per-glyph-class fixed pixel-offset table — art/UX-authored **data**, not architecture-level values. This ADR defines that the anchor point exists and is `grid_to_screen(tile)`, not the specific offset numbers. Store as a data-driven resource (mirrors the `gameplay_config_storage` convention) — do not hardcode as GDScript literals.
- hp-pip-never-occluded (game-hud.md CR-5 / TR-hud-011) is enforced by offset-table *authoring discipline* (hp pips get first claim on non-overlapping screen space) — this story does NOT build any runtime arbitration/z-ordering system for glyphs; it is a data-authoring guarantee.
- Camera model (OQ-8) is explicitly out of scope and left open — the anchor formula is camera-model-agnostic by construction. Do not make a camera-model decision in this story.
- Glyph *caching* strategy (recompute-on-move vs per-frame reproject) depends on OQ-8's eventual answer and is deferred — this story defines the anchor-point formula and offset-table mechanism only, not an update strategy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Camera model decision (OQ-8, explicitly deferred)
- Any runtime glyph-overlap-arbitration system (not needed — authoring discipline suffices)
- The actual glyph art/visuals themselves — owned by HUD/CAI epics (this story builds only the anchor mechanism they call)

---

## QA Test Cases

- **AC (formula — Logic)**: Given a tile and a glyph_class with a known offset value, When the anchor function is called, Then it returns `grid_to_screen(tile) + offset` exactly (arithmetic assertion, no rendering).
- **AC (data-driven — Logic)**: Given `GLYPH_OFFSETS` loaded from an external resource file, When a value is changed in the file, Then the anchor computation reflects the new value with zero code change.
- **AC (hp-pip priority — Visual/Feel)**: Setup: place a test unit with hp pips + has-acted marker + AP-cost badge on one tile at 1080p. Verify: screenshot shows hp pips fully unobstructed. Pass condition: no overlap onto the hp pip region at 1080p and 1440p.
- **AC (legibility — Visual/Feel)**: Setup: render all 12 glyph classes across a small test board, one per tile (incl. edge tiles). Verify: each glyph is legible, correctly positioned, no off-board clipping. Pass condition: art/UX reviewer sign-off at both target resolutions.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/board-renderer/glyph_offset_anchor_test.gd` — must exist and pass (blocking); plus advisory `production/qa/evidence/board-renderer-glyph-legibility-evidence.md` (Visual/Feel legibility + hp-pip priority)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`grid_to_screen` is the base anchor point)
- Unlocks: the Game HUD on-board glyph layer (TR-hud-010/011) and CAI's D-3 echo (TR-cmdui-017)
