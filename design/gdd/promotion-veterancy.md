# Promotion & Veterancy

> **Status**: **DRAFT** (2026-08-24) — Tier 1 of the faction corpus v2.
> **Author**: user (direction) + agents · **System #**: 21 (new)
> **Owning GDD for**: field promotion, rank effects, and rank loss
>
> ★ **The Holy Cosmic Empire is entirely built on this system.** Its direction reads: *"Units based
> on a strict hierarchy that promote on the field… promoted infantry are a high risk high reward
> option that require a lot of investment, which makes losses more impactful."* Every other faction
> can ship without promotion. That one cannot exist without it.
>
> ★ **Base-game machinery, faction access (CR-9).** Promotion is available in principle to any
> faction; the Empire is simply the one built around it. That is what stops it being a rules
> exception.

---

## Overview

**Promotion & Veterancy** lets a unit become permanently stronger through combat. A unit accrues
**merit** for actions that matter — landing kills, mainly — and at thresholds gains a **rank**. Each
rank grants a fixed, deterministic bonus.

The system's whole design tension is that **a promoted unit concentrates value into a single piece
that can still be killed.** That is the "high risk, high reward" the direction asks for, and it is
the reason promotion is interesting rather than merely a growth curve: it makes a player *attached*
to a unit, and attachment creates the tension of protecting something.

It also does something the game structurally needs. The PIVOT verdict found that **matches never
resolve because nobody is rewarded for fighting.** Promotion is a reward for *combat specifically* —
you cannot promote by building. It pushes in exactly the direction the measurement says the game
is missing.

**Design constraint held throughout: promotion must not create runaway snowball.** A unit that gets
stronger by winning fights is the classic rich-get-richer mechanic, and this game has just been
measured failing at exactly that shape of problem in its economy. Three rounds, hard-capped, with
sharply escalating requirements.

## Player Fantasy

**The feeling: "that one has been with me since the first turn."**

- **Attachment.** A veteran is not an asset; it is a *character*. Players who name a unit are
  playing the game right.
- **Risk that means something.** Committing a rank-3 veteran is a genuinely difficult decision in a
  way that committing a fresh unit never is.
- **Loss that lands.** Losing a veteran should be the worst moment in a match — and, per the
  Empire's thesis, that ache is the price of its power.
- **★ For the Empire specifically:** hierarchy as identity. Its army is not a pile of equal soldiers
  but a structure with a top, and its power comes from having invested in that top. The
  corresponding vulnerability — *"highly vulnerable to tech base disruption"* — is what keeps it
  honest.

## Detailed Rules

**PV-1 — Merit is earned by combat, and only by combat.** A unit gains merit for:
- **Destroying an enemy unit:** `MERIT_PER_KILL` (3)
- **Destroying an enemy structure:** `MERIT_PER_STRUCTURE` (2)
- **Landing a hit that does not kill:** `MERIT_PER_HIT` (1)

Nothing else grants merit. Not surviving, not moving, not building, not being repaired.

**PV-2 — Three ranks, hard cap.**

| Rank | Merit needed (cumulative) | Bonus |
|---|---:|---|
| 0 — Recruit | 0 | none |
| 1 — Veteran | **6** | `+1` attack |
| 2 — Elite | **16** | `+1` attack, `+2` max hp (**and current hp**) |
| 3 — Champion | **32** | `+2` attack, `+4` max hp, `+1` attack range |

> ★ **The escalation is the anti-snowball guard, and it is deliberate.** Rank 1 costs 6 merit
> (2 kills); rank 3 costs 32 (about 11 kills). By the time a unit could reach rank 3, most matches
> are over. **Rank 3 is meant to be rare and memorable, not a mid-game milestone.** If playtest shows
> Champions appearing routinely, raise the thresholds before touching the bonuses — the bonuses are
> the fantasy.

**PV-3 — Bonuses are deterministic and additive.** They fold into `effective_attack`,
`effective_max_hp` and `effective_attack_range` exactly as research bonuses already do. **No new
resolution path, no multipliers** — the same discipline `damage-types.md` follows, and for the same
reason: `combat-resolution.md`'s additive formula has an Approved floor-lock analysis behind it.

**PV-4 — Rank is per-unit state and dies with the unit.** There is no rank pool, no inheritance, no
replacement-unit-inherits-rank. **When a veteran dies, that investment is gone.** This is the
"losses are more impactful" half of the Empire's thesis and it must not be softened.

**PV-5 — A rank-up on gaining max hp also grants the current hp.** A unit promoting mid-fight gets
the hp immediately, not on next heal. *Rationale: a promotion that does nothing until later is an
anticlimax at the exact moment the game should feel best.*

**PV-6 — Promotion is automatic and immediate.** It happens the moment the merit threshold is
crossed, during the same action that earned it, after damage resolves. No player decision, no
ceremony turn, no cost. *Rationale: a promotion the player must remember to spend on is
bookkeeping.*

**PV-7 — ★ Rank loss through tech-base disruption.** This is the Empire's stated vulnerability made
mechanical. A faction may declare `rank_requires_support: true`, meaning its units' ranks are
sustained by a structure (its Research Lab or equivalent). If **no** supporting structure is
`COMPLETED` and alive at a player's start of turn, every unit of that faction **drops one rank** per
turn until support is restored.

- Rank drops, never below 0. Units are not destroyed.
- Merit is **retained** — restoring support lets units re-promote at their existing merit, which
  makes recovery real rather than punitive.
- **This is a faction-declared property, not a rule for everyone.** The Empire opts into a
  vulnerability in exchange for its power curve. That opt-in *is* CR-9 working correctly.

**PV-8 — ★ Faction access (D6): the Holy Cosmic Empire only, for now.** *(User decision,
2026-08-24 — resolves PVOQ-5.)* The machinery here is general and any faction *could* be granted it
(CR-9), but **only the Empire has it in the current design.** No other faction's units accrue merit
or hold a rank.

> ★ **Why exclusivity matters.** If every faction promotes, the Empire's identity reduces to
> *degree* — "we promote a bit better" — which is the weakest kind of asymmetry and precisely the
> reskin failure Pillar 4 exists to prevent. Sole access makes promotion **the** Empire, and makes
> the matchup question *"how do I fight an army that gets stronger?"* rather than *"whose veterans
> are better?"*
>
> **Practical consequence:** every merit hook, rank display and AI valuation is dead code for five
> of six factions. That is acceptable and deliberate — but it means promotion should be built
> **last** among the Tier-1 systems, since it benefits exactly one faction.

**PV-9 — Upkeep and rank.** ★ **Unresolved** — see `unit-upkeep.md` UOQ-3. A promoted unit is worth
more; whether it *costs* more per turn is a genuine design question with a real bearing on the
Empire's balance.

## Formulas

```
merit(unit) += MERIT_PER_KILL       on destroying an enemy unit
             + MERIT_PER_STRUCTURE  on destroying an enemy structure
             + MERIT_PER_HIT        on landing a non-killing hit

rank(unit) = max r in {0,1,2,3} such that merit(unit) >= RANK_THRESHOLD[r]

effective_attack(unit)        = base_attack + research_bonus + RANK_ATTACK[rank]
effective_max_hp(unit)        = base_max_hp + RANK_HP[rank]
effective_attack_range(unit)  = base_range + RANK_RANGE[rank]
```

| Constant | Value |
|---|---|
| `RANK_THRESHOLD` | `[0, 6, 16, 32]` |
| `RANK_ATTACK` | `[0, 1, 1, 2]` |
| `RANK_HP` | `[0, 0, 2, 4]` |
| `RANK_RANGE` | `[0, 0, 0, 1]` |
| `MERIT_PER_KILL` / `_STRUCTURE` / `_HIT` | 3 / 2 / 1 |

**Worked — an Empire medium infantry (the shipped Trooper: atk 3, hp 6, range 2):**

| Rank | Merit | Attack | Max hp | Range | Roughly |
|---|---:|---:|---:|---:|---|
| 0 | 0 | 3 | 6 | 2 | as shipped |
| 1 | 6 | **4** | 6 | 2 | 2 kills |
| 2 | 16 | **4** | **8** | 2 | ~5 kills |
| 3 | 32 | **5** | **10** | **3** | ~11 kills |

> ⚠ **Rescaled 2026-08-24 against the shipped roster** (Trooper hp is 6, not the 10 an earlier draft
> assumed). A rank-3 Champion medium infantry (atk 5, hp 10, range 3) is **a Heavy's health with
> better range than a Heavy and nearly a Sniper's attack, on a unit costing 4 Credits.** That is a
> lot — deliberately so, and the reason it costs 32 merit and dies as easily as anything else.
> ★ Note the hp bonuses matter *more* at these real values than the draft implied: +4 hp on a 6-hp
> unit is a **67% increase**, and it takes the unit from "dies to one Sniper hit" to "survives one".
> That survivability jump may be the more powerful half of promotion, not the attack.
> ★ **Check this against `damage-types.md`'s ±3 resistance band and against CR-10.** A Champion with
> a favourable resistance matchup is the single strongest thing that can exist in the game, and
> nothing currently bounds that stack.

## Edge Cases

- **A unit killing multiple enemies in one area attack:** merit for each kill. Multiple thresholds may be crossed in one action; the unit lands at the highest rank its merit supports.
- **Merit from a counterattack kill:** yes — the counter is that unit's action for the purpose of merit, even though it costs no AP.
- **Rank-up mid-combat:** applied after damage resolves and before the next target (PV-6), so a burst's later targets face the promoted stats. ★ Deterministic because `damage-types.md` DT-9 fixes area resolution order.
- **A unit at max hp promoting to rank 2:** max hp and current hp both rise (PV-5); it ends above its previous maximum, which is correct.
- **A unit at rank 3 gaining more merit:** merit accrues, rank stays capped. Retained merit matters for PV-7 recovery.
- **Rank loss below 0:** floors at 0.
- **Rank loss with support destroyed and rebuilt in the same turn:** support is evaluated once, at start of turn. Rebuilding later stops the *next* drop, not this one.
- **A stolen unit's rank** (Independents' pirate): ★ rank **transfers with the unit**. Stealing a veteran is a genuine coup, and that is a good outcome for the game.
- **A carried unit's merit:** it cannot fight, so it earns nothing. Correct.
- **A faction with `rank_requires_support` that has no support structure in its roster:** load fails — an unmeetable vulnerability is a data error.

## Dependencies

| System | Relationship |
|---|---|
| **Combat Resolution** (#6) | ★ Hard — merit is awarded on hit and kill. Needs `DamageEvent` (S5-06) and the destroy event, both of which exist |
| **Unit System** (#4) | ★ Hard — `merit` and `rank` become **per-unit mutable state**. Today unit stats are read from a shared immutable `UnitTypeDef`; per-instance stat modification is new |
| **Damage Types** (#18) | Soft — rank bonuses and resistances stack additively; see the Formulas warning |
| **Research/Tech** (#8) | Hard — rank bonuses fold into the same `effective_*` path research already uses; PV-7's support structure is typically the Research Lab |
| **Base & Production** (#7) | Hard — PV-7 checks a structure's `build_status` and liveness at start of turn |
| **Game State** (#2) | Hard — the PV-7 support check is a new start-of-turn step |
| **Unit Upkeep** (#15) | ★ Soft, unresolved — UOQ-3 |
| **Game HUD** (#10) | ★ Hard — rank must be visible on the unit and in inspection. **A player must be able to see which unit is their veteran at a glance**, or the attachment fantasy cannot form |
| **Board Renderer** | ★ Hard — rank needs a visual channel. Given Pillar 3 and the ownership decal work already done, this needs deliberate design rather than another colour |
| **AI Opponent** (#11) | ★★ Hard — must value its own veterans higher (protect them) and prioritise the enemy's (kill them). It currently values every unit of a type identically |

## Tuning Knobs

| Knob | Default | Safe range | Effect / failure at extremes |
|---|---|---|---|
| `RANK_THRESHOLD` | `[0,6,16,32]` | scaled ±50% | ★ **The primary anti-snowball dial.** Lower and Champions become routine and the game snowballs; higher and promotion never fires in a 30-round match and the Empire has no identity |
| `RANK_ATTACK` | `[0,1,1,2]` | ≤ `[0,1,2,3]` | Against a 2–6 attack band, +2 is already large. +3 makes a Champion strictly dominant |
| `RANK_HP` | `[0,0,2,4]` | ≤ `[0,2,4,6]` | hp bonuses are safer than attack bonuses — they extend a unit's life without accelerating its merit |
| `MERIT_PER_KILL` | 3 | 2–4 | Relative to `MERIT_PER_HIT = 1`, this sets whether chip damage or finishing blows promote |
| `rank_requires_support` | Empire only | per faction | ★ The Empire's opt-in vulnerability. If more factions take it, it stops being an identity and becomes a tax |

## Acceptance Criteria

| # | Criterion | Type |
|---|---|---|
| AC-1 | GIVEN a unit destroying an enemy unit, THEN its merit increases by `MERIT_PER_KILL` | Logic |
| AC-2 | GIVEN a unit landing a non-killing hit, THEN its merit increases by `MERIT_PER_HIT` | Logic |
| AC-3 | GIVEN a unit that builds, moves or is repaired, THEN its merit is unchanged | Logic |
| AC-4 | GIVEN merit crossing 6, THEN rank becomes 1 and `effective_attack` increases by 1 | Logic |
| AC-5 | GIVEN merit crossing 16 at full hp, THEN max hp **and** current hp both increase by 2 | Logic |
| AC-6 | GIVEN merit crossing 32, THEN `effective_attack_range` increases by 1 | Logic |
| AC-7 | GIVEN merit beyond 32, THEN rank remains 3 | Logic |
| AC-8 | GIVEN one action crossing two thresholds, THEN the unit ends at the highest rank its merit supports | Logic |
| AC-9 | GIVEN a promoted unit is destroyed, THEN no rank or merit persists anywhere in state | Integration |
| AC-10 | GIVEN a counterattack kill, THEN the counterattacking unit gains kill merit | Integration |
| AC-11 | GIVEN a burst promoting the attacker mid-resolution, THEN later targets in that same attack face the promoted stats, deterministically across repeated runs | Integration |
| AC-12 | GIVEN `rank_requires_support` and no living completed support structure at start of turn, THEN every unit of that faction drops exactly one rank and retains its merit | Integration |
| AC-13 | GIVEN support is restored, THEN units re-promote to the rank their retained merit supports | Integration |
| AC-14 | GIVEN rank loss at rank 0, THEN rank stays 0 and no unit is destroyed | Logic |
| AC-15 | GIVEN a captured unit with rank > 0, THEN its rank transfers to the new owner | Integration |
| AC-16 | GIVEN a faction with `rank_requires_support` and no support structure in its roster, THEN load fails | Config-Data |
| AC-17 | GIVEN a promoted unit on the board, THEN its rank is visually distinguishable and inspectable | Visual (advisory) |

## Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| PVOQ-1 | ★★ **Does promotion re-create the snowball the PIVOT just diagnosed?** The measured failure was a rich-get-richer economy. Promotion is rich-get-richer combat. The thresholds are the guard, but **this must be validated by the AI-vs-AI regression batch before the Empire ships** — the same tool that caught the economy defect will catch this one | economy-designer + systems-designer | Before the Empire ships |
| PVOQ-2 | ★ **Per-instance stats are an architectural change.** Unit stats today come from a shared immutable `UnitTypeDef`; rank makes two units of the same type genuinely different. This touches the stat read path, save/load, the renderer and the AI's valuation. **Needs an ADR** — and it is the same underlying change `transport-and-pilots.md` TPOQ-1 needs, so they should be designed together | technical-director | ADR before build |
| PVOQ-3 | **How is rank shown?** Pillar 3 is a hard gate the project has already nearly failed, and the board already carries faction hue, AP-state tint, glow and an ownership decal. Rank needs a channel that does not compete with those. Recommend a small rank pip on the ownership decal — it is already a per-entity ground element with room | art-director | With `/ux-design` |
| ~~PVOQ-4~~ | ✅ **RESOLVED 2026-08-24: no.** A promoted unit costs no more to keep. Taxing success cuts against the reward, and the Empire already pays for its curve twice over — it must *fight* to promote at all, and the whole investment is reversible by an attack on its Cathedral. That is sufficient cost. (Closes `unit-upkeep.md` UOQ-3 too) | ✅ closed |
| ~~PVOQ-5~~ | ✅ **RESOLVED 2026-08-24 (user): the Empire only, for now.** Machinery stays general (CR-9) so another faction can be granted it later without a rules change. ★ Consequence: promotion should be built **last** of the Tier-1 systems — it serves one faction of six | — | ✅ closed |
