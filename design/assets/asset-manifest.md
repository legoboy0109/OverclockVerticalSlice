# Asset Manifest

> Last updated: 2026-08-19 (infantry session — ASSET-002/003/004 base looks approved)
> Master index of every specced game asset. IDs are sequential across the whole project.

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 7 | 1 | 6 | 0 | 0 |

> "Needed" = specced, awaiting art production. Each unit/structure ships in **3 hue variants**
> (rush / boom / neutral) and — for units — 4 facings × the §8.5 state set; terrain ships one
> faction-agnostic sprite per wear-variant. Production quantity ≫ the 7 spec entries.

## Assets by Context

### Vertical Slice: Entities & Terrain
Spec file: `design/assets/specs/vs-entities-assets.md` · Source: `design/assets/entity-inventory.md`
Paste-ready prompts (hues pre-expanded): `design/assets/specs/generation-prompts.md`

| Asset ID | Name | Category | Hue variants | Status | Notes |
|----------|------|----------|--------------|--------|-------|
| ASSET-001 | HQ | Structure | rush/boom/neutral | In Progress | Largest sprite; atlas anchor / 4096-escalation risk. **Base look approved 2026-08-18: `art-source/generated/asset-001-hq/hq_rush_r7_c2.png`** (seed 3566038092, round-7 light-background recipe in generation-prompts.md addendum). **Supersedes `hq_rush_r5_c3`** — that one rendered its base-plate as light off-palette pavement and carried 7 lamp-post props, both only visible once composited at board scale. Post-work: ✅ shadow cleaned (`art-source/cleaned/hq_rush_r7_c2_clean.png`); remaining: downscale, boom/neutral via accent recolor, damaged/destroyed states. bg→alpha is now tooled (`tools/asset-pipeline/cutout.py`) |
| ASSET-002 | Scout | Infantry (4 facings) | rush/boom/neutral | In Progress | ★ **Body plan changed to a low four-legged WALKER** (user-approved 2026-08-19) — humanoid proportions never produced §3.1's locomotion-led read. **Base look approved: `art-source/generated/asset-002-scout/scout_rush_r9_c2.png`** (seed 1383706175). Sized by **width** ~74px. ✅ shadow cleaned (`art-source/cleaned/scout_rush_r9_c2_clean.png`). Post-work: boom/neutral accent recolor, facings, states |
| ASSET-003 | Trooper | Infantry (4 facings) | rush/boom/neutral | In Progress | ★ **Authored FIRST as the family's control group** — Scout and Heavy body plans were derived from its recipe. **Baseline approved: `art-source/generated/asset-003-trooper/trooper_rush_r7_c1.png`** (seed 3049366272), shadow-free. Upright biped, ~65px tall |
| ASSET-004 | Heavy | Infantry (4 facings) | rush/boom/neutral | In Progress | ★ **Body plan changed to a squat siege WALKER** (user-approved 2026-08-19) — "Trooper scaled up" read too close to the Trooper to pass the §5.2 grayscale role test. **Base look approved: `art-source/generated/asset-004-heavy/heavy_rush_r9_c2.png`** (seed 1840110820). ~74px tall; still the atlas-width driver. ⚠ shadow not removable (overlaps its own plating) but **invisible at board scale** — accepted; master `art-source/cleaned/heavy_rush_r9_c2_clean.png`. Post-work: variants |
| ASSET-005 | Production Outpost | Structure | rush/boom/neutral | In Progress | **Base look approved 2026-08-18: `art-source/generated/asset-005-production-outpost/outpost_rush_r5_c3.png`** (seed 1143338806, round-5 recipe in generation-prompts.md). ★ **Bay is a glowing OPEN TOP, not a front-face mouth** — approved deviation from the spec's §3.2 reading (see the spec's Bay Aperture note). Verified against the HQ at board scale: distinct silhouettes in colour *and* grayscale. Post-work: downscale, boom/neutral via accent recolor, damaged/destroyed states |
| ASSET-006 | Plain terrain tile | Environment | faction-agnostic | In Progress | Flush `TileMapLayer` floor; no glow. `clean` variant in `assets/art/terrain/` 2026-08-12 — procedural draw (flat geometry; SDXL rejected, see `art-source/generated/asset-006-plain-tile/`). Wear variants pending |
| ASSET-007 | Cover terrain tile | Environment | faction-agnostic | Needed | **Hybrid: floor cell + Y-sorted prop** (§8.8) |

**★ Unit spec amendment (2026-08-19, user-approved):** unit armour is **`#6E7C99` slate**, not the
`#232A38` terrain-tile family the specs originally named — units were invisible against the board and
failed the art bible's grayscale outline test. On-screen size raised from ~24–40px to ~60–74px. Role
separation is by **body plan**, not proportion adjectives. Full rationale in
`design/assets/specs/vs-entities-assets.md` (Unit Spec Amendment) and the art bible §5.1.

**★ Cleaned masters (2026-08-19):** every approved base look now has a cut-out, shadow-cleaned
master in **`art-source/cleaned/`** (tracked in git — unlike the raw generations). **All downstream
work — hue variants, facings, damage states, downscales — derives from the cleaned master, never
from the raw generation.** Settings and the one exception (Heavy) are in the shadow-cleanup table in
`design/assets/specs/generation-prompts.md`.

**Cross-cutting notes:** all actors share ONE `ShaderMaterial` (per-instance uniforms for hue/glow,
§8.7/§8.9, S4-01-confirmed). Ownership-by-hue VS wiring (Rush vs Boom) + engine faction-pin change is
the S4-03 follow-up (see the spec's Scope Reconciliation). Mass-Distribution-Bias silhouettes deferred
to Full Vision — VS variants are re-hues of one silhouette per role.
