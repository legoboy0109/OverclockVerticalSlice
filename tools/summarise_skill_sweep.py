"""S7-09 — summarise the play-strength sweep across degradation levels."""
import sys, re, glob, os, statistics
sys.path.insert(0, "tools")
from analyse_swing import load, analyse

rows = []
for d in [0,5,10,15,20,25,30,35,40,50]:
    path = f"{sys.argv[1]}/big_d{d}.txt"
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        continue
    games, ends = load(path)
    res = analyse(games, ends)
    if not res:
        continue
    # underdog wins: winner != favoured
    fav = {}
    for line in open(path):
        line = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
        p = line.split(",")
        if line.startswith("SIM_END,"):
            fav[int(p[1])] = (int(p[2]), int(p[6]))
    wins = sum(1 for g,(f,w) in fav.items() if w != f and w >= 0)
    n = len(res)
    rows.append(dict(
        d=d, n=n,
        flips=statistics.mean(r["flips"] for r in res),
        any_flip=sum(1 for r in res if r["flips"] > 0),
        doubt=statistics.mean(r["doubt"] for r in res) * 100,
        past_half=sum(1 for r in res if r["doubt"] > 0.5),
        peak=statistics.mean(r["peak_loser_lead"] for r in res),
        wins=wins, total=len(fav),
    ))

print(f"{'degrade':>8} {'n':>3} {'games w/ flip':>14} {'mean flips':>11} "
      f"{'mean doubt':>11} {'doubt>50%':>10} {'underdog wins':>14}")
print("-" * 76)
for r in rows:
    print(f"{r['d']:>7}% {r['n']:>3} {r['any_flip']:>7}/{r['n']:<6} {r['flips']:>11.2f} "
          f"{r['doubt']:>10.0f}% {r['past_half']:>7}/{r['n']:<2} {r['wins']:>8}/{r['total']:<5}")
