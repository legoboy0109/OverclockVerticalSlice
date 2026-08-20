# Sprint 5 — 2026-08-19 to 2026-09-02 (Vertical Slice Validation, cont.)

## Sprint Goal
Wire the completed art into the board, run the two gating playtests, and land the
PROCEED / PIVOT / KILL verdict that clears the Pre-Production → Production gate
(left at **CONCERNS** in Sprint 3, still open through Sprint 4).

## Capacity
- Total days: 10 (2-week sprint)
- Buffer (20%): 2 days reserved for unplanned work
- Available: ~8 days

> **★ = human-gated** (playtest sessions / windowed sign-off) — cannot be fully
> agent-completed. **The human-gated validation half has now rolled over twice**
> (s3-09/10/11 → S4-04/05/06 → S5-03/04/05). S5-04 is art-independent and runnable
> on the current build **today** — start it on day 1, in parallel, rather than
> queueing it behind the renderer. That queueing is what caused both rollovers.

## ⛔ Process commitments (from the Sprint 4 retrospective)

Source: `production/retrospectives/retro-sprint-4-2026-08-19.md`. These are carried here, not left
in a retro file, because **Sprint 3's equivalent fix died exactly that way** — it was written down,
faithfully implemented as a *label*, and the human-gated track still scored 0/4.

### ★ Day-1 gate: this sprint is not started until S5-04 has a booked session

**S5-04 needs no art and runs on the current build today.** It has been unblocked for three sprints
and has never run. A priority label has now failed three times, so the commitment is a **calendar
slot, not a flag**:

- [ ] **A specific play session for S5-04 is booked before any S5-01 code is written.** Owner: user
      (game-designer). Deadline: **S5 day 1–2.**

If that box is unchecked, the most likely outcome of Sprint 5 is a third rollover of the same two
playtests — which are the only things standing between this project and its PROCEED/PIVOT/KILL
verdict.

### Standing rules for this sprint

| # | Commitment | Owner | Status |
|---|---|---|---|
| 2 | **Never commit above available days.** The measure is **must + should vs the 8 *available* days**; nice-to-haves ride the 2-day buffer and are not commitments. Sprint 4 committed **9.0** (must 7 + should 2) against 8 — **+12.5% before any disruption** — and its full list of 10.5 exceeded even the 10-day total | producer | ✅ **applied** — Sprint 5 commits exactly **8.0** (must 5 + should 3) against 8 available; its 1.0 of nice-to-haves rides the buffer, for 9.0 of 10 total |
| 3 | **Mid-sprint design changes go to a post-gate backlog.** Accepting one mid-sprint requires an explicit re-plan that **descopes something and records the trade**. Sprint 4 absorbed ~4 days of economy-pivot work without cutting anything, taking committed load to **13.0 against 8 available (+62%)** | producer + creative-director | ⬜ enforce at kickoff |
| 4 | **Estimate human-gated art as an approval loop, not a production task.** Model decision rounds; treat calendar cost as distinct from effort cost. S4-02 was ~3 days of effort spread over 21 calendar days | art-director + producer | ⬜ applies to S5-10 and any art follow-up |

> **Why #3 has teeth this sprint:** the AP+Credits pivot is live and *unvalidated by play*. The
> temptation to keep tuning it before the verdict is exactly the failure mode — S5-04 is what tells
> us whether it works. **Freeze design changes until the verdict lands.**

## Tasks

### Must Have (Critical Path — clear the gate)
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-01 | Entity sprite renderer + live `GameState.entities()`→board feed (replace placeholder diamonds; closes scope §8 build-seam c) *(was S4-03)* | godot-gdscript-specialist | 2 | — | Real sprites y-sort on OccupantLayer; **`TileSet.tile_size` 256×128 with the layer scaled 0.5** (textures ship 2× per §8.3 — `TILE_WIDTH_PX`/`TILE_HEIGHT_PX` 128×64 remain the *on-screen* cell); **cover composed as floor cell + Y-sorted prop**, not one TileMapLayer cell; **bottom-centre = ground-contact pivot**, never bbox centre; facing map `n→e`, `s→w`; boot + integration tests green |
| S5-02 | Glow shader wiring — §8.9 emission mask + per-instance uniforms | godot-shader-specialist | 1 | S5-01 | One shared `ShaderMaterial` across all actors; `faction_hue` + `pulse_intensity` via `set_instance_shader_parameter`; breathe 0.25→0.85 slow sine, AP-spent clamp 0.08, attack flare 1.0 decaying, destroyed 0; **`state_timer` passed from GDScript, not the shader `TIME` built-in** (must freeze with the turn-based pause) |
| S5-03 | ★ Iso-legibility playtest (Pillar-3 hard gate) *(was S4-04)* | ux-designer / qa-tester | 0.5 | S5-01, S5-02 | ≥1 documented naive/silent-observer session; board readable at the shipping camera; silhouettes distinguishable **in grayscale**; ownership clear by hue → `production/playtests/` |
| S5-04 | ★ Swing-back playtest — tempo/comeback, pivot-aware *(was S4-05)* | game-designer / qa-tester | 1 | — | ≥1 documented session (DoD floor); ≥3 close + ≥3 decided games preferred; closeout-drag observation captured; **no decided game reverses**; two-budget (AP + Credits) tempo observed |
| S5-05 | VS REPORT + PROCEED/PIVOT/KILL verdict + re-run `/gate-check pre-production` *(was S4-06)* | creative-director + producer | 0.5 | S5-03, S5-04 | `REPORT.md` with verdict + velocity log; gate re-run outcome recorded |

### Should Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-06 | Unit state transforms — move lean, attack lunge, hit recoil, destroyed cross-fade | godot-gdscript-specialist | 1 | S5-02 | §8.5's move/attack/hit are **renderer transforms, not art** — tween on the single sprite; destroyed cross-fades `idle_01`→`destroyed_01` with `pulse_intensity`→0 over the 2–4 frame beat |
| S5-07 | ★ Advisory Visual/Feel sign-offs (BR-002/003/005, CAI-006, HUD-004/005/007) — windowed screenshots *(was S4-07)* | qa-lead / art-director | 1 | S5-01 | Evidence docs in `production/qa/evidence/` signed off. Also clears the S4-01 residual: windowed one-unit glow render in the live rasteriser |
| S5-08 | Colourblind ownership decision — non-hue markers or documented accept | art-director / creative-director | 1 | S5-03 | Rush vs Boom grayscale separation is **measured at Δ34/255 (13%)** — readable on structures, marginal on units. Decide: build §5.2-style non-hue markers (trim pattern / emblem), or accept with rationale recorded in the art bible. **Ceiling note:** the locked anchors differ by only 45 luma, so no remap can do better without breaking the S4-01 palette lock |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-09 | Wear-variant placement pass in the VS map | level-designer | 0.5 | S5-01 | Tile-variant kit placed per §6.4 density ceiling; wear asymmetry per §6.5 (concentration on one face / around chokepoints), not uniform scatter |
| S5-10 | Structure `damaged` tier | art-director | 0.5 | — | Structures currently ship `idle` + `destroyed` only; §8.5's damage tiers want a mid state |

## Carryover from Sprint 4
| Task | Reason | New Estimate |
|------|--------|--------------|
| S4-02 representative art | ✅ **COMPLETE 2026-08-19** — 7 assets × 3 hues, facings, glow masks, destroyed states, terrain wear kit; 62 runtime PNGs + import sidecars | — |
| S4-03 → S5-01 | Was blocked on S4-02 art; now unblocked | 2 (was 1.5; +0.5 for 2× texture + two-layer cover wiring) |
| S4-04/05/06 → S5-03/04/05 | **Second rollover** of the human-gated validation half | 2 |
| S4-07 → S5-07 | Was blocked on art | 1 |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Validation half rolls over a third time** | High | High | S5-04 is art-independent and runnable **now** — start day 1 in parallel, never queued behind the renderer. This is the specific failure that caused both prior rollovers |
| Unplanned design work recurs (the AP→AP+Credits pivot consumed Sprint 4's window) | Medium | High | Pivot is complete and committed. **Freeze new design changes until the verdict lands**; route new ideas to a post-gate backlog |
| Renderer integration surprises (2× textures, two-layer cover, pivot rules) | Low | Medium | Contract is documented in `assets/art/README.md` — read before implementing |
| Colourblind ownership unresolved at the gate | Medium | Medium | S5-08 forces the decision. The gap is **measured** (Δ34/255), not a guess, and the palette ceiling is known |
| Verdict lands PIVOT (muted swing-back / unreadable board) | Medium | Medium | Sanctioned outcome, not a failure → spawns a focused tuning/art follow-up, then re-gate |

## Dependencies on External Factors
- **S5-03 and S5-04 need a human**, and S5-03 prefers a naive observer. DoD floor is
  ≥1 documented session; think-aloud preferred, self-test acceptable.
- S5-07 needs a **windowed** (not headless) session — the dummy rasteriser cannot render.

## Definition of Done for this Sprint
- [ ] **Day-1 gate honoured** — an S5-04 session was booked *before* S5-01 code began
      (retro action 1; this is the commitment Sprint 4 failed)
- [ ] **No unplanned work absorbed silently** — anything accepted mid-sprint has a recorded
      descope trade (retro action 3)
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-5.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

---

## Sprint 4 close-out (recorded 2026-08-19)

Sprint 4 ran **2026-07-29 → 2026-08-12** and closed at **6/10 stories done**.

| Story | Outcome |
|---|---|
| S4-01 de-risk spikes | done (2026-07-29) |
| S4-02 representative art | done — **completed 2026-08-19, after the window** |
| S4-08 occupant pick-region | done |
| S4-09 committed-code follow-ups | done |
| S4-10 HUD chrome UX pass | done |
| S4-03/04/05/06/07 | not started → carried to Sprint 5 |

**What consumed the window:** an unplanned **AP → AP+Credits economy pivot** (Phases 1–6:
GDD rewrite, ADR propagation, config knobs, engine, HUD, tests), landed 2026-08-05..08.
It is complete and committed, but it was not in the sprint plan and it displaced the
entire validation half. Recording it here rather than absorbing it silently — the same
half has now rolled over twice, and that pattern is the first thing a Sprint 4
retrospective should address.

**Art track actuals (S4-02):** 39 SDXL generations for infantry plus earlier structure
rounds; two spec defects found and amended (unit armour was specced the same value as
the terrain tile; role separation needed body-plan changes, not proportion adjectives);
six new pipeline tools committed (`cutout` deshadow/pockets, `recolor`, `make_facings`,
`place_runtime`, `glow_mask`, `state_variant`, `draw_plain_tile`, `draw_cover_tile`).
