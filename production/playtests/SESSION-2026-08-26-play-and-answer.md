# Play session — six questions

> **This is the only file you need.** Play, then write what you thought in your own words under
> each question. Prose is fine. Partial answers are fine and still unblock the verdict.
> **No protocol to follow, no per-game table to fill in.** Everything measurable has already been
> measured; this is the part that needs a person.

## How to start it

```
./builds/linux/Overclock.x86_64
```

Then **New Skirmish** from the main menu. (Or `./redot` to run from the editor — same game.)

⛔ **The binary IS out of date — rebuild it before playing.** Updated 2026-08-26:
```
./redot --headless --export-release "Linux Release" "$PWD/builds/linux/Overclock.x86_64"
```
⚠ From an agent shell, prefix the launch with `DISPLAY=:0` or no window appears.

> ### ⚠ Three things changed since this file was written — the game is not the one you played
> - **Building works differently.** Build is no longer a HUD button. You make a **Builder** unit,
>   walk it where you want the structure, and it is **consumed** raising it. The HQ makes only
>   Builders now; the Barracks makes everything that fights.
> - **The keyboard works.** Choosing a verb by keyboard did nothing at all before, and the Build
>   picker was wired to nothing.
> - **The AI actually plays.** It was demolishing everything it built and ending games owning
>   nothing but its HQ — you were facing an empty board.
>
> ★★ **Question D is the one this affects.** Paying for an economic action now costs a whole unit
> rather than a click, which is much closer to the "tempo cost" the question is asking about.
> **The question is unchanged** — but an answer from the old build would not have been about
> this game.

---

# Part 1 — Someone else watches (~20 min)

**Needs one person who has not seen the game.** You play; they watch and answer. ⚠ **Do not
explain anything first** — whether the game explains itself *is* the measurement. If they ask a
question, note that they asked rather than answering it.

> **Skip this part if nobody is around.** Part 2 does not need an observer and unblocks the
> verdict on its own. Just write "no observer available" below.

### Q1 — Within about two minutes, unprompted, can they say which units are theirs?
*(Colour measurably separates the two sides. That is not the same as the mapping being communicated.)*

**Answer:**

### Q2 — Can they tell which units have already moved this turn?
*(Spent units are dimmed. Whether that reads as "used" rather than "further away" is interpretation.)*

**Answer:**

### Q3 — Do they read the structures as buildings, rather than as large units?
*(Silhouettes measurably separate. Category confusion would be a meaning failure, not an optical one.)*

**Answer:**

---

# Part 2 — You play (~40 min)

Play at least one game you would call **close**. Then answer in your own words.

### A — Does the swing feel alive?
Did you notice the lead changing hands? Did the game feel like yours to lose, or was it decided
early and you were just finishing it?

**Answer:**

### C — Does tempo read at a glance?
Could you tell your AP and Credit position without stopping to work it out? When you were about to
run short, did you see it coming?

**Answer:**

### D — ★★ Does spending Credits feel like a tempo cost?
When you paid AP *and* Credits for an economic action, did it feel like a **deliberate trade** —
giving up tempo now for something later — or like **fiddly bookkeeping** you were just servicing?

> **This is the most important question in the sprint.** Sprint 4 split one budget into two on the
> premise that this would feel deliberate. Every measurement since confirms the mechanism *works*.
> Nothing has tested whether it *feels* like anything. **A negative answer here is a real result
> and worth having** — it would mean the economy needs rethinking before wave 2 is built on it.

**Answer:**

---

## Anything else you noticed

Bugs, confusions, things that felt bad, things that felt good. Unstructured is fine.

**Notes:**
