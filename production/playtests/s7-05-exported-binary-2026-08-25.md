# The first real exported binary

> **Date**: 2026-08-25 · **Story**: S7-05
> **Result**: ✅ **A runnable 69 MB Linux binary that boots the menu and a full match, zero errors**

---

## Why this was the last open item on the export track

S7-03 verified packaging via `--export-pack` + `--main-pack`, which proves resource packaging and
script resolution — the two things that were broken — but **runs on the editor binary**. Everything
claimed about exportability up to now rested on that.

## What was done

| Step | Detail |
|---|---|
| Templates | `Redot_v26.2-stable_export_templates.tpz`, **1233 MB**, from the Redot GitHub release matching the pinned engine exactly |
| Install | Unpacked to `~/.local/share/redot/export_templates/26.2.stable/` (1.7 GB on disk) — the directory existed and was empty |
| Export | `./redot --headless --export-release "Linux Release" builds/linux/Overclock.x86_64` |
| Artefact | **69,505,272 bytes** binary + a 5.4 MB `.pck` |

⚠ The version directory name must be **`26.2.stable`** — taken from the `version.txt` inside the
archive, not guessed from the engine string.

## Verification — the point of the exercise

```
Overclock.x86_64 --headless --quit-after 300                          -> exit 0, no errors
Overclock.x86_64 --headless res://scenes/vertical_slice.tscn ...      -> exit 0, no errors
```

Both run from a **different working directory**, so `res://` resolves out of the package rather
than the project tree.

★★ **This is what closes S7-01 and S7-02 for real.** The preset excludes `tests/`, so the binary is
built without the directory that used to define `Research` and `Structure`. It boots. The two
export-fatal defects found in S7-03 are confirmed fixed **in the artefact a player would actually
run**, not merely in a pack loaded by the editor.

## What this does NOT establish

- **Nothing was run on a Steam Deck.** The binary is x86_64 Linux, which the Deck runs natively,
  but the target-hardware measurements in `technical-preferences.md` remain desktop figures
  reasoned to the device.
- **Nothing was run windowed.** Headless only — no display in this session. Rendering, input and
  the four Deck-Verified gaps are all still unverified on a real screen.
- **No packaging beyond a bare binary + pck.** No embedded pck, no `.desktop` entry, no store
  wrapper, no signing.

## Housekeeping

`builds/` is gitignored — the artefact is reproducible from the preset and the templates, and a
69 MB binary has no business in the history. The templates live outside the repo entirely.
