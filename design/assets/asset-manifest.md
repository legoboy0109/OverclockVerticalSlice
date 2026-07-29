# Asset Manifest

> Last updated: 2026-07-29 (Sprint 4 · S4-02)
> Master index of every specced game asset. IDs are sequential across the whole project.

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 7 | 7 | 0 | 0 | 0 |

> "Needed" = specced, awaiting art production. Each unit/structure ships in **3 hue variants**
> (rush / boom / neutral) and — for units — 4 facings × the §8.5 state set; terrain ships one
> faction-agnostic sprite per wear-variant. Production quantity ≫ the 7 spec entries.

## Assets by Context

### Vertical Slice: Entities & Terrain
Spec file: `design/assets/specs/vs-entities-assets.md` · Source: `design/assets/entity-inventory.md`

| Asset ID | Name | Category | Hue variants | Status | Notes |
|----------|------|----------|--------------|--------|-------|
| ASSET-001 | HQ | Structure | rush/boom/neutral | Needed | Largest sprite; atlas anchor / 4096-escalation risk |
| ASSET-002 | Scout | Infantry (4 facings) | rush/boom/neutral | Needed | Low horizontal silhouette; fastest |
| ASSET-003 | Trooper | Infantry (4 facings) | rush/boom/neutral | Needed | Balanced-rectangle baseline; silhouette-test reference |
| ASSET-004 | Heavy | Infantry (4 facings) | rush/boom/neutral | Needed | Widest mass; atlas-width driver |
| ASSET-005 | Production Outpost | Structure | rush/boom/neutral | Needed | Open-bay "mouth"; pre-placed, no construction sprites |
| ASSET-006 | Plain terrain tile | Environment | faction-agnostic | Needed | Flush `TileMapLayer` floor; no glow |
| ASSET-007 | Cover terrain tile | Environment | faction-agnostic | Needed | **Hybrid: floor cell + Y-sorted prop** (§8.8) |

**Cross-cutting notes:** all actors share ONE `ShaderMaterial` (per-instance uniforms for hue/glow,
§8.7/§8.9, S4-01-confirmed). Ownership-by-hue VS wiring (Rush vs Boom) + engine faction-pin change is
the S4-03 follow-up (see the spec's Scope Reconciliation). Mass-Distribution-Bias silhouettes deferred
to Full Vision — VS variants are re-hues of one silhouette per role.
