#!/usr/bin/env python3
"""S5-04 swing-back analysis — the measurable half of the tempo/comeback playtest.

    python3 tools/analyse_swing.py <batch.txt>

WHAT S5-04 ASKS
---------------
game-concept.md's Player Motivation section makes a specific, falsifiable pair of
claims:

  "In a CLOSE, UNDECIDED game, losing tempo is recoverable through smart
   stabilization -- the swing can still flip while the outcome is in doubt.
   OVERCLOCK deliberately has no rubber-band/comeback mechanic: once a game is
   ACTUALLY DECIDED, it is not designed to reverse."

That is two requirements pulling in opposite directions, and both are measurable
from turn-by-turn state:

  1. NO DECIDED GAME REVERSES  -- once decided, it stays decided. (Easy to pass.)
  2. THERE IS A WINDOW OF DOUBT -- a period where the game genuinely could go
     either way. (Easy to FAIL, and failing it silently looks identical to
     passing requirement 1.)

A game that is decided on turn 2 satisfies requirement 1 perfectly. It also has no
swing at all. Measuring only "did anything reverse" would score that as a pass,
which is why this script measures WHEN the decision happens, not just whether it
holds.

THE LEAD METRIC
---------------
Weighted toward the actual win condition rather than raw material, because a
player ahead on units but behind on HQ damage is losing.

    lead = (hq_mine - hq_theirs) / HQ_MAX * HQ_WEIGHT
         + (hp_mine - hp_theirs) / HP_SCALE
         + (units_mine - units_theirs) * UNIT_WEIGHT

DEFINITIONS
-----------
  decision turn   the last turn on which the eventual LOSER held a lead (or was
                  level). After it, the winner never trails again.
  window of doubt decision turn / total turns. 1.0 = decided on the final turn;
                  0.1 = decided in the first tenth and the rest is a formality.
  lead changes    how many times the sign of the lead flips. 0 = one side led
                  wire to wire.
  closeout drag   turns from the decision to the end. The GDD flags this as a
                  named risk: a long drag is unfun even when the result is right.
"""
import sys, re, statistics
from collections import defaultdict

HQ_MAX = 40.0
HQ_WEIGHT = 3.0
HP_SCALE = 40.0
UNIT_WEIGHT = 0.35
LEVEL_EPS = 0.05   # |lead| below this counts as level, not a lead


def load(path):
    games = defaultdict(list)
    ends = {}
    for line in open(path):
        line = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
        p = line.split(",")
        if line.startswith("SIM_END,"):
            ends[int(p[1])] = dict(handicap=int(p[3]), turn=int(p[5]), winner=int(p[6]))
        elif line.startswith("SIM,") and len(p) >= 16:
            # Column map, verbatim from simulate_matches.gd's print:
            #  0    1     2         3          4       5     6              7,8
            # SIM, game, favoured, handicap, variant, turn, active_player, hp0,hp1,
            #  9,10        11,12    13,14      15
            # units0,1 · hq0,hq1 · cred0,1 · ap0
            # ★ A first pass read these one column early -- hp took active_player --
            # and produced a confident, completely wrong swing report (every game
            # "100% in doubt"). Indices are pinned to the emitter here on purpose.
            games[int(p[1])].append(dict(
                turn=int(p[5]), hp=(int(p[7]), int(p[8])),
                units=(int(p[9]), int(p[10])), hq=(int(p[11]), int(p[12])),
                cred=(int(p[13]), int(p[14])), ap=int(p[15])))
    return games, ends


def lead_for(row, w):
    l = w
    o = 1 - w
    return ((row["hq"][l] - row["hq"][o]) / HQ_MAX * HQ_WEIGHT
            + (row["hp"][l] - row["hp"][o]) / HP_SCALE
            + (row["units"][l] - row["units"][o]) * UNIT_WEIGHT)


def analyse(games, ends):
    out = []
    for g, rows in sorted(games.items()):
        if g not in ends or not rows:
            continue
        e = ends[g]
        w = e["winner"]
        leads = [lead_for(r, w) for r in rows]
        n = len(leads)

        # decision turn: last index where the winner was NOT strictly ahead
        decision = 0
        for i, v in enumerate(leads):
            if v <= LEVEL_EPS:
                decision = i + 1

        flips = 0
        prev = 0
        for v in leads:
            s = 0 if abs(v) <= LEVEL_EPS else (1 if v > 0 else -1)
            if s != 0 and prev != 0 and s != prev:
                flips += 1
            if s != 0:
                prev = s

        out.append(dict(game=g, handicap=e["handicap"], turns=n, winner=w,
                        decision=decision, doubt=decision / n if n else 0.0,
                        flips=flips, drag=n - decision,
                        final_lead=leads[-1], peak_loser_lead=-min(leads)))
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-1000/b8.txt"
    games, ends = load(path)
    res = analyse(games, ends)
    if not res:
        print("no games found"); return

    print("=" * 78)
    print("S5-04 — SWING-BACK ANALYSIS")
    print("=" * 78)
    print(f"\n{len(res)} games\n")
    print(f"  {'game':>4} {'hcap':>4} {'turns':>6} {'decided':>8} {'doubt':>7} "
          f"{'flips':>6} {'drag':>5}  {'loser peak':>10}")
    for r in res:
        print(f"  {r['game']:>4} {r['handicap']:>4} {r['turns']:>6} "
              f"{r['decision']:>8} {r['doubt']*100:>6.0f}% {r['flips']:>6} "
              f"{r['drag']:>5}  {r['peak_loser_lead']:>10.2f}")

    doubts = [r["doubt"] for r in res]
    flips = [r["flips"] for r in res]
    drags = [r["drag"] for r in res]
    print("\n" + "-" * 78)
    print("\n[REQUIREMENT 1] No decided game reverses")
    never = sum(1 for r in res if r["decision"] <= 1)
    print(f"  games where the winner led wire-to-wire      : {never}/{len(res)}")
    print(f"  games with at least one lead change          : {sum(1 for f in flips if f > 0)}/{len(res)}")
    print(f"  mean lead changes per game                   : {statistics.mean(flips):.2f}")

    print("\n[REQUIREMENT 2] There is a window of doubt")
    print(f"  mean 'doubt' (decision turn / game length)   : {statistics.mean(doubts)*100:.0f}%")
    print(f"  median                                       : {statistics.median(doubts)*100:.0f}%")
    print(f"  games decided in the first quarter           : {sum(1 for d in doubts if d <= 0.25)}/{len(res)}")
    print(f"  games still in doubt past the halfway point  : {sum(1 for d in doubts if d >= 0.5)}/{len(res)}")

    print("\n[CLOSEOUT DRAG] turns between decision and end")
    print(f"  mean {statistics.mean(drags):.1f} · median {statistics.median(drags):.0f} "
          f"· worst {max(drags)}")
    print(f"  drag as share of game length: {statistics.mean([r['drag']/r['turns'] for r in res])*100:.0f}%")

    print("\n[BY HANDICAP] — do closer games stay in doubt longer?")
    byh = defaultdict(list)
    for r in res:
        byh[r["handicap"]].append(r)
    print(f"  {'hcap':>4} {'games':>6} {'mean doubt':>11} {'mean flips':>11} {'mean drag':>10}")
    for h in sorted(byh):
        rs = byh[h]
        print(f"  {h:>4} {len(rs):>6} {statistics.mean([r['doubt'] for r in rs])*100:>10.0f}% "
              f"{statistics.mean([r['flips'] for r in rs]):>11.2f} "
              f"{statistics.mean([r['drag'] for r in rs]):>10.1f}")

    print("\n[TWO-BUDGET TEMPO] Credits banked vs spent over the game")
    allc = []
    for g, rows in sorted(games.items()):
        for r in rows:
            allc.append(max(r["cred"]))
    if allc:
        q = len(allc) // 4
        print(f"  banked Credits, mean by game quarter: "
              f"Q1 {statistics.mean(allc[:q]):,.0f} · Q2 {statistics.mean(allc[q:2*q]):,.0f} · "
              f"Q3 {statistics.mean(allc[2*q:3*q]):,.0f} · Q4 {statistics.mean(allc[3*q:]):,.0f}")
    print()
    print("=" * 78)


if __name__ == "__main__":
    main()
