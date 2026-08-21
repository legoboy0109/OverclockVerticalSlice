# S5-07 — Windowed Visual/Feel Evidence

Captured 2026-08-21 by `tools/CaptureEvidence.tscn` on `kaden-x570aoruselite`
(Redot 26.2, Vulkan Forward+, RX 6900 XT, 1280×720). Frames come from the **real**
presentation stack — `BoardRenderer`, `EntitySpriteFeed`, `EntityGlow`,
`EntityTransforms`, `OwnershipMarker`, the shipped art and the shipped shader —
rendered to a real framebuffer and read back.

**This closes the standing "OWED — requires a windowed session" note** that every
Visual/Feel acceptance criterion has carried since Story 002. A display is available
on this machine; these were capturable all along.

Re-run with: `./redot tools/CaptureEvidence.tscn --disable-vsync`

---

## ★★ FINDING 1 — the Pillar-1 "can this actor still act?" read barely exists

**Measured on the neon trim, best case to worst case:**

| State | Luma on the glowing rim |
|---|---:|
| AP-available, breathe **peak** | 148.1 / 255 |
| AP-available, breathe **trough** | 138.9 / 255 |
| **AP-spent** (clamped to 0.08) | 135.6 / 255 |

- **Best case** (peak vs spent): **12.5/255** — 4.9% of range
- **Worst case** (trough vs spent): **3.3/255** — 1.3% of range

And the signal covers almost nothing: the pixels the pulse actually drives are
**6,147 px — 0.67% of the frame, 2.35% of everything drawn on the board.** Even on
that rim, peak-vs-spent is only **16.8/255**.

**Both axes fail and they compound.** Breathe cycles over 3 seconds, so a player
glancing at the board at an arbitrary moment has a good chance of catching the
trough, where the difference is ~1%.

Frames: `02-glow-ap-available-peak` · `02b-glow-ap-available-trough` · `03-glow-ap-spent`

## ★★ FINDING 2 — a destroyed unit does not visibly power down

§8.5 locks the destroyed beat as a "power-down/collapse". Measured on the dying
unit's own pixels:

| | Mean luma |
|---|---:|
| alive | 113.4 / 255 |
| destroyed (end of beat) | 104.5 / 255 |
| **change** | **8.9 / 255 (3.5%)** |

The cross-fade itself works — the destroyed art genuinely swaps in, visible as a pose
change across `01` → `06` → `07`, and this is **the first time the destroyed PNGs
shipped by S4-02 have ever been drawn**. But the actor does not read as *shutting
down*, because it barely dims.

Frames: `06-death-echo-mid` · `07-death-echo-late`

## ★★ ROOT CAUSE — the same one behind both

**The glow only ever ADDS light on top of already-bright accent art.** Removing added
light cannot make an actor look spent or dead when its base sprite stays fully
saturated. The maximum available signal is the emission range alone, which is small
against base art that is already bright neon.

This is structural, not a tuning value. `BREATHE_MIN`, `SPENT_CLAMP` and
`FLARE_DECAY_SEC` can all be retuned and the ceiling will not move much, because the
base art's own brightness sets the floor.

**What would actually work** is making "spent" and "destroyed" *multiply the sprite
down* — desaturate and darken the whole actor — rather than only ceasing to emit.
That is the genre-standard "greyed out = has acted" read, and it is an art-direction
change, not a code tweak.

> **Deliberately NOT fixed here.** The sprint's process commitment freezes design
> changes until the PROCEED/PIVOT/KILL verdict lands (Sprint 4 retro action 3). This
> is filed as input for **S5-03** and **S5-05**, which is where it belongs.

---

## What PASSES

| Check | Frame | Result |
|---|---|---|
| Glow reads as neon trim, not a blown-out panel | `01` | ✅ rims luminous, panel shapes intact |
| Real terrain + real entity art on a live board | `01` | ✅ |
| Ownership decals render on structures | `01`, `09` | ✅ chevron/flank-split visible per faction |
| Move lean tips the unit at its feet | `04` | ✅ visible, pivots at ground contact |
| Attack lunge + hit recoil | `05` | ✅ both visible in the same frame |
| Destroyed cross-fade swaps the art | `06`, `07` | ✅ (but see Finding 2 on dimming) |
| Marker policy ALL vs STRUCTURES_ONLY | `08` vs `09` | ✅ 4,316 px differ — the unit decals |
| Ownership stays legible **through** an overlay | `10` | ✅ MarkerLayer draws above OverlayTileMapLayer |
| Shader compiles in the real rasteriser | all | ✅ zero shader errors, clean exit |

## Observation for S5-03 — unit occlusion at density

At the capture's spacing, adjacent units substantially overlap one another (see `01`,
centre of the board). Units stand roughly two tile-heights tall, which the art bible
expects, but the practical consequence at real board density is that a unit can be
largely hidden behind its neighbour. Not a defect against any stated criterion —
flagging it as a legibility question for the human session.

---

## Honest limits of this evidence

- **These are captures, not a play session.** They prove the pipeline renders what it
  claims. They cannot tell you whether the motion *feels* right or survives
  repetition, which is what S5-07's sign-off and S5-03 are actually for.
- **The board is a fixture**, not a real match: 8 entities placed to exercise the
  states, not a position the AI would produce.
- **The motion frames are captured at 0.05× engine time scale** so a 0.05–0.35s tween
  can be caught mid-flight. The transforms themselves are unmodified — only the clock
  is slowed.
- **Two harness traps were hit and fixed** while producing these; both are written up
  in `.agent/notes.md`. One of them produced a frame that looked exactly like an
  S5-06 rendering bug and was not. If a future capture disagrees with a green headless
  suite, suspect the harness first and verify with a headless probe.

## Sign-off

| Role | Status |
|---|---|
| art-director (visual) | ⬜ pending |
| qa-lead (evidence completeness) | ⬜ pending |

Findings 1 and 2 should be read before signing — they are the reason this pass was
worth running, and they change what S5-03 is looking for.
