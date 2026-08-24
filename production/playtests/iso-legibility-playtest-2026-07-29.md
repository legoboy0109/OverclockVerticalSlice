# Iso-Legibility Playtest — Board Readability (S4-04 · Pillar 3 HARD GATE)

> **Status**: TEMPLATE — **BLOCKED on the real-art build.** Run only once S4-02 art exists and S4-03
> renders it (real sprites replacing the placeholder diamonds). A placeholder slice **cannot**
> validate Pillar 3 (scope §5).
> **Story**: S4-04 (Sprint 4 — Vertical Slice Validation). Feeds the S4-06 REPORT + re-gate.
> **Build**: the VS with real sprites at the **shipping fixed iso camera** — test at **1080p AND 1440p**.
> **Run on**: a windowed Redot 26.2 build. Faction pins are already Rush-vs-Boom (commit `9950067`).

---

## Why this is a HARD gate (not advisory)

Pillar 3 — **Readable Board, Deep Decisions** — is the load-bearing promise: the player reads the
whole board at a glance so every decision is an informed one. This is the **one playtest that can
flip the vertical-slice verdict to PIVOT** (unreadable board → focused art rework) rather than
PROCEED. It is also the reason the slice needed real art at all (scope §5: "a placeholder-art slice
cannot validate Pillar 3").

---

## The three acceptance checks (scope §5 + art bible)

1. **Role legibility in grayscale (§5.2 solid-black silhouette test).** Scout / Trooper / Heavy / HQ /
   Production Outpost each identifiable from **outline alone**, fully desaturated, at the shipping iso
   camera + actual tile scale. *VS scope note:* the VS shares one silhouette per role across factions
   (Mass Distribution Bias deferred), so this is the **role** test (Scout vs Trooper vs Heavy), not
   the faction-from-silhouette test.
2. **Ownership clear by hue.** Rush (orange `#FF5A2E`) vs Boom (cyan `#22C7F0`) instantly separable in
   full color at iso distance — including when both sides' units overlap on adjacent diagonal tiles
   (the y-sort stack), and against every stage tile incl. max-elevation `#33405A` (S4-01 validated
   this numerically — confirm it in the real render).
3. **Terrain legibility (§6.3).** Plain vs Cover distinguishable by silhouette+value ("elevation lifts
   the floor; cover breaks the floor with an object silhouette"); nothing — prop or terrain — is
   mistakable for a unit or for cover (§6.4).

---

## Known VS limitation to OBSERVE (deferred Mass Distribution Bias)

The VS ships **hue-only ownership** (shared silhouettes; §5.2 MDB deferred). Consequence: **ownership
is not distinguishable in pure grayscale/monochrome** — both sides share a silhouette, only hue
differs. Rush-vs-Boom hue *is* colorblind-safe as a pair (§4.2 — ~180° apart, opposite the red-green
axis), so protan/deutan players should still read ownership; but a fully monochrome view loses it.
**Capture whether this bites any tester.** A real ownership-in-grayscale miss is a **known, accepted
VS deferral** (the full game restores MDB for colorblind/grayscale ownership), *not* a new bug — but
log it for the Faction Identity epic.

---

## How to run

- Real-art VS build (S4-03) at the shipping fixed iso camera. Test at **both 1080p and 1440p**.
- **≥1 naive / silent-observer session** (someone who hasn't seen the game) — think-aloud preferred.
  The naive read is the whole point: can a fresh viewer parse the board unaided?
- **Grayscale check:** desaturate the screen (OS/monitor grayscale, or screenshot → desaturate) and
  re-run the role-legibility read.
- **Colorblind check (if available):** protanopia / deuteranopia / tritanopia sim (OS filter or
  Coblis on a screenshot) for the ownership read.

---

## Role / silhouette legibility matrix (grayscale)

| Entity | Role read from outline alone? (Y/N) | @1080p | @1440p | Confusable with? | Notes |
|--------|-------------------------------------|--------|--------|------------------|-------|
| Scout | | | | | low horizontal lean |
| Trooper | | | | | balanced rectangle (baseline) |
| Heavy | | | | | wide, bottom-heavy anvil |
| HQ | | | | | largest; central spire |
| Production Outpost | | | | | open-bay "mouth", smaller than HQ |

## Ownership legibility (full color)

- Rush vs Boom instantly separable at iso distance? [Y/N]
- Holds when both sides overlap on adjacent diagonal tiles (y-sort stack)? [Y/N]
- Holds against every stage tile incl. max-elevation `#33405A`? [Y/N]
- Colorblind sim — ownership still readable? protan [Y/N] · deutan [Y/N] · tritan [Y/N]
- Grayscale — ownership readable? [expected NO in VS — record it, see the deferral note]

## Terrain / board legibility

- Plain vs Cover distinguishable by silhouette + value (§6.3)? [Y/N]
- Cover never mistaken for a unit or a prop; props never mistaken for cover (§6.4)? [Y/N]
- Elevation (if the VS map has any) reads as a whole-tile value lift, not confused with cover? [Y/N/NA]
- The overlay layer (reachable / attack tiles — §4.3 non-hue) still legible over the real art? [Y/N]

## Naive-observer read (the core evidence)

- Identified the two sides without being told? [Y/N — how long]
- Told the unit roles apart (which is fast/fragile vs the anvil)? [Y/N]
- Read board state (whose turn, who still has AP, what's cover)? [Y/N]
- First-glance confusion points: [list]
- Verbatim think-aloud quotes: [ ]

---

## Findings → categorized

- **Design/art changes** (a silhouette not reading, a hue too near the stage, cover ambiguous): →
  `art-director` / re-spec the affected `ASSET-NNN` in `design/assets/specs/vs-entities-assets.md`.
- **Balance**: n/a for legibility.
- **Bugs** (render / y-sort / overlay defects): → `/bug-report`.
- **Polish**: minor friction, non-blocking.

---

## Verdict (feeds S4-06 REPORT + re-gate) — Pillar-3 HARD GATE

- **PASS / PROCEED** — roles read in grayscale, ownership reads by hue, terrain unambiguous at the
  shipping camera. Pillar 3 validated.
- **CONCERNS** — mostly readable with specific fixable issues (one weak silhouette, one ambiguous
  tile). Named art follow-up, then re-check.
- **PIVOT (art rework)** — the board is not readable at the shipping camera (silhouettes blur,
  ownership unclear, terrain ambiguous). Not a KILL — spawns focused silhouette/hue/tile art rework,
  then re-gate.

**Definition of Done check:**
- [ ] ≥1 naive / silent-observer session documented
- [ ] Board readable at the shipping camera at **1080p AND 1440p**
- [ ] Role silhouettes distinguishable in grayscale (§5.2)
- [ ] Ownership clear by hue (Rush vs Boom)
- [ ] Known MDB-deferral (ownership-in-grayscale) limitation observed + noted

**Verdict**: [PASS / CONCERNS / PIVOT]  ·  **One-line rationale**: [ ]
