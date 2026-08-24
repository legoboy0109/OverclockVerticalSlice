# Visual Entity & Screen Inventory — Vertical Slice

> **Generated:** 2026-07-27 (Sprint 2 · S2-07, art-director-owned)
> **Scope:** Vertical Slice entity set only (per `production/vertical-slice/scope.md` §5).
> **Sources:** `design/registry/entities.yaml`, `design/art/art-bible.md` (§3 Shape Language,
> §4 Color System, §5 Unit Design, §6 Environment, §8 Asset Standards),
> `design/gdd/{base-production,unit-system,combat-resolution,movement-system}.md`,
> `design/gdd/game-state-turn-manager.md` (win condition).
> **Purpose:** bridge "the visual style is defined" (art bible) to "here is the VS production
> backlog." Each entity below is a **spec stub** — run `/asset-spec entity:[name]` to expand a
> stub into full per-asset `ASSET-NNN` specs (sprites, VFX, generation prompts, tech constraints).
>
> **★ SPECS WRITTEN 2026-07-29 (S4-02):** all 5 entities + 2 terrain tiles below are now expanded
> into full per-asset specs → `design/assets/specs/vs-entities-assets.md` (`ASSET-001`–`ASSET-007`),
> indexed in `design/assets/asset-manifest.md` (the live status tracker). VS ships **3 hue variants**
> (rush/boom/neutral — a re-hue of one shared silhouette per role; Mass-Distribution-Bias deferred).
> Recommended VS wiring is **Rush-vs-Boom** for ownership-by-hue (see the spec's Scope Reconciliation).

---

## VS Scoping Decisions (read before using this inventory)

1. **Symmetric slice → 2 faction-hue variants, shared silhouettes.** The VS is two sides at
   parity (scope §5), so ownership is coded by **faction hue only** — assign the two sides
   **Rush** (orange-red) and **Boom** (cyan-azure) hues per art-bible §4.2. The per-faction
   **Mass Distribution Bias** silhouettes (§5.2) — the art-director's flagged 3× silhouette cost
   driver — are a **Pillar-4 (faction asymmetry) concern, DEFERRED with faction asymmetry**.
   VS units share one silhouette per role across both sides; only the hue differs.
2. **Produce-roster resolution: pre-place a Production Outpost per side.** base-production has the
   HQ produce **Scout only**; Trooper/Heavy come from a Production Outpost (normally built, but
   build-outpost is out of the VS verbs). The VS **starts each side with a pre-placed Production
   Outpost**, so the full Scout/Trooper/Heavy roster is producible without the build verb and
   base-production's rules stay intact. *(This resolves the open question in scope §5 / `hud.md`
   Open Q #3 — the entity inventory is the record of that resolution.)*
3. **Deferred entities** (present in the registry, NOT in the VS): **Sniper** (not in scope §5's
   Scout/Trooper/Heavy roster; registry stats flagged UNVALIDATED), **Economy Outpost**,
   **Defensive Structure**, **Research Lab** (build-outpost / research out of slice).
4. **Infantry register lock** (§5.1): all VS units are **human soldiers in sealed powered armor**
   (XCOM/StarCraft-marine lineage), sealed helmet / no face-read, chunky exaggerated mass
   proportions, matte flat-value hard-surface plating. Vehicles/mechs are a later tier, out of VS.

---

## Entities

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | HQ | Structure (static, non-directional) | The faction headquarters: sole basic-unit producer and the win-condition target (destroy enemy HQ → game over). Largest structure sprite. | base-production.md, game-state-turn-manager.md (win), entities.yaml | **Needed** |
| 2 | Scout | Infantry unit | Cheap, fast, fragile melee harasser. Low/horizontal silhouette (§3.1). HQ's only producible type. | unit-system.md, combat-resolution.md, movement-system.md, base-production.md, entities.yaml | **Needed** |
| 3 | Trooper | Infantry unit | Efficiency-band backbone; range-2, balanced-rectangle silhouette (§3.1). Produced by Production Outpost. | unit-system.md, combat-resolution.md, movement-system.md, base-production.md, entities.yaml | **Needed** |
| 4 | Heavy | Infantry unit | Durable, slow anvil; range-2, widest/bottom-heavy silhouette (§3.1). Produced by Production Outpost. | unit-system.md, combat-resolution.md, movement-system.md, base-production.md, entities.yaml | **Needed** |
| 5 | Production Outpost | Structure (static, non-directional) | Second producer; unlocks the Trooper/Heavy roster (cap 4/turn). **Pre-placed per side in the VS.** | base-production.md, entities.yaml | **Needed** |

---

## Entity Spec Stubs

Each stub is `/asset-spec entity:[name]`-ready. Shared conventions (all entities): runtime **PNG
8-bit+alpha** (§8.1); author flat-vector hi-res **~2–3× display** then downscale (§8.3); **pivot at
ground-contact bottom-center** for Y-sort (§8.6); **isolated greyscale glow-mask pass** in addition
to base-color pass (§8.6/§8.9); naming per §8.2; faction tokens `rush`/`boom` (VS ownership hues).

### STUB — HQ (`structure_hq`)
- **Type:** Structure — static, **no facings** (§3.2, §8.2). Multi-tile footprint; **tallest/biggest
  per-sprite atlas item** (§8.3).
- **Registry:** hp 40, `production_cap 2`, `producible_types [scout]`, `can_counterattack false`,
  win-condition target.
- **Art-bible anchors:** §6 (environment/structure language, flat painted hard-surface), §3.2
  (structures static non-directional), §4.2 (faction hue for ownership; also reads as a
  §1-P2 non-hue landmark by footprint/silhouette), §2 (glow-state layer: idle/AP-available vs
  clamped; production-ready cue).
- **Sprites needed:** base + glow-mask; states: idle, (produce beat), damaged tiers, **destroyed
  power-down/collapse 2–4 frames (§8.5, no gibs)**. 2 hue variants (rush/boom).
- **Status:** Needed.

### STUB — Scout (`unit_scout`)
- **Type:** Infantry — **4 facings** `n/s/e/w` (`w` = h-flip of `e` where mirror-safe, §8.5);
  **~24–40px** display height (§8.3).
- **Registry:** hp 3, attack 2, `attack_range 1` (melee), `move_cost 1`, `produce_cost 2`,
  `min_range 1`, `can_counterattack false`.
- **Silhouette (§3.1):** low horizontal lean + locomotion appendage — must read as "Scout" from a
  flat black silhouette at tile scale (§5.2 solid-black test). Sealed-helmet chunky infantry (§5.1).
- **States (§8.5):** idle (AP-available, glow breathes), idle (AP-spent/clamped, glow only),
  move, attack, hit, destroyed (2–4f). base + glow-mask each. 2 hue variants.
- **Status:** Needed.

### STUB — Trooper (`unit_trooper`)
- **Type:** Infantry — 4 facings, ~24–40px.
- **Registry:** hp 6, attack 3, `attack_range 2`, `move_cost 2`, `produce_cost 4`,
  `can_counterattack false`.
- **Silhouette (§3.1):** balanced rectangle — the roster's silhouette baseline. Sealed-helmet
  chunky infantry (§5.1). Solid-black role read required (§5.2).
- **States:** as Scout. base + glow-mask; 2 hue variants.
- **Status:** Needed.

### STUB — Heavy (`unit_heavy`)
- **Type:** Infantry — 4 facings, ~24–40px (canvas allows widest footprint).
- **Registry:** hp 10, attack 5, `attack_range 2`, `move_cost 3`, `produce_cost 7`,
  `can_counterattack false`.
- **Silhouette (§3.1):** widest, bottom-heavy mass — reads as the anvil. Sealed-helmet chunky
  infantry (§5.1). Solid-black role read required (§5.2).
- **States:** as Scout. base + glow-mask; 2 hue variants.
- **Status:** Needed.

### STUB — Production Outpost (`structure_production_outpost`)
- **Type:** Structure — static, **no facings** (§3.2). Multi-tile footprint (smaller than HQ).
- **Registry:** hp 14, `build_cost 9`, `production_cap 4`, `producible_types [trooper, heavy, sniper]`
  (VS produces trooper/heavy only — Sniper deferred). **Pre-placed per side in the VS.**
- **Art-bible anchors:** §6 structure language, §3.2 static, §4.2 faction hue, §2 glow (production-
  ready cue). Because it is pre-placed (not built) in the VS, **no construction-stage sprites are
  needed** for the slice (`_construction`/`_complete` build-state tokens, §8.2, are deferred with
  the build verb).
- **Sprites needed:** base + glow-mask; states: idle, damaged tiers, destroyed (2–4f). 2 hue variants.
- **Status:** Needed.

---

## Also Required for the VS Build (referenced — not authored as entity stubs here)

These complete the VS visual production picture but sit in other specs/inventories:

### Environment / Terrain
| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| T1 | Base terrain tile | Environment | Default passable ground tile for the small hand-crafted VS map; dark-stage neutral (§6, §4.2). All tile variants share footprint (drop-in swaps, §8.3). | scope §5, grid-terrain.md, art-bible §6 | Needed |
| T2 | Cover terrain tile | Environment | At least one cover tile (`COVER_DR` −1 combat, per scope §5 / combat-resolution). | scope §5, combat-resolution.md | Needed |

### UI Screens (already specced — S2-05)
| # | Screen | Status | Spec |
|---|--------|--------|------|
| S1 | Game HUD | **Specced** (`/ux-review` APPROVED) | `design/ux/hud.md` |
| S2 | Main Menu | **Specced** (`/ux-review` APPROVED) | `design/ux/main-menu.md` |
| S3 | Pause | **Specced** (`/ux-review` APPROVED) | `design/ux/pause.md` |

### HUD / On-board glyphs & VFX (visual language in art-bible §2/§7; layout in hud.md)
| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| G1 | hp pips / numeric | On-board hp readout (pips < 10 hp, numeric for HQ) — neutral grey/white, never faction hue | hud.md §HUD Elements, art-bible §7 | Needed |
| G2 | has-acted glyph | Desaturate + corner ✓ (non-hue redundant) | hud.md, accessibility-requirements | Needed |
| G3 | AP-spend / commit VFX | Glow flare/tick on commit; snap-never-tween | art-bible §2, hud.md, interaction-patterns | Needed |
| G4 | Board overlays | Reachable / attack-target / deploy-tile tints (CAI-owned, stage-neutral not hue) | CAI GDD, art-bible §8.1 | Needed |

> Audio (AP fill/tick, turn stinger, victory/defeat) is representative/non-gating for the VS
> (game-hud story 008 trimmed) — descriptions live in `design/gdd/game-hud.md` §Audio; no
> generation prompts here.

---

## Next Steps

- `/asset-spec entity:hq` (and `scout`, `trooper`, `heavy`, `production-outpost`) — expand each
  stub into full `ASSET-NNN` sprite/VFX specs + generation prompts + tech constraints. This
  creates `design/assets/specs/*.md` and the master `design/assets/asset-manifest.md`.
- Before hex-lock: run the art-bible §4.2 Boom-cyan vs Dark-Stage side-by-side test
  (AD sign-off watch-item #3).
- Before committing the sprite pipeline: the §8.9 glow-shader 2D/uniform spike (watch-item #4).
