#!/usr/bin/env python3
"""balance_sweep.py — run AI-vs-AI sims for every faction pair and summarise.

Each job is one `SimulateMatches.tscn --only-handicap=0` batch (12 mirrored openings) for one
ordered faction pair on one map, so both seats of every pairing are covered. Jobs run in
parallel; raw stdout per job is kept in --out so a summary can be re-derived without re-running.

  python3 tools/balance_sweep.py run --out <dir> [--maps vertical_slice,crossroads] [-j 12] [-- extra sim args]
  python3 tools/balance_sweep.py summarise <dir>

Why a durable script: the previous rotation runners lived in job-tmp and were lost each session.
"""
import argparse
import collections
import concurrent.futures as cf
import itertools
import os
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
FACTIONS = {
    "democratic_alliance": "Accord",
    "galactic_protectorate": "Trappist",
    "holy_cosmic_empire": "Order",
    "independents": "Lightless",
    "machinists_union": "Ross",
    "solar_federation": "Wolf",
}


def _run_job(out: pathlib.Path, f0: str, f1: str, map_id: str, extra: list) -> str:
    log = out / f"{map_id}__{f0}__{f1}.log"
    if log.exists() and "SIM_DONE" in log.read_text(errors="replace"):
        return f"skip {log.name}"
    cmd = [str(ROOT / "redot"), "--headless", "--path", str(ROOT), "tools/SimulateMatches.tscn", "--",
           "--only-handicap=0", f"--factions={f0},{f1}", f"--map={map_id}", *extra]
    t = time.time()
    with open(log, "w") as fh:
        subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT, cwd=ROOT)
    return f"done {log.name} in {time.time() - t:.0f}s"


def run(args: argparse.Namespace) -> None:
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    jobs = [(a, b, m) for m in args.maps.split(",") for a, b in itertools.permutations(FACTIONS, 2)]
    print(f"{len(jobs)} jobs, {args.j} at a time -> {out}", flush=True)
    with cf.ThreadPoolExecutor(args.j) as ex:
        futs = [ex.submit(_run_job, out, a, b, m, args.extra) for a, b, m in jobs]
        for n, f in enumerate(cf.as_completed(futs), 1):
            print(f"[{n}/{len(jobs)}] {f.result()}", flush=True)


def summarise(args: argparse.Namespace) -> None:
    out = pathlib.Path(args.dir)
    wins = collections.Counter()
    games = collections.Counter()
    pair = collections.defaultdict(lambda: [0, 0])  # (a,b) -> [a wins, games]
    turns, capped, unfinished = [], 0, 0
    research = collections.defaultdict(collections.Counter)  # faction -> tech -> seats
    seats = collections.Counter()
    labs = collections.Counter()
    ntech = collections.Counter()
    produced, built, ability = collections.Counter(), collections.Counter(), collections.Counter()
    by_map = collections.defaultdict(lambda: collections.Counter())
    for log in sorted(out.glob("*.log")):
        map_id, f0, f1 = log.stem.split("__")
        names = (FACTIONS[f0], FACTIONS[f1])
        text = log.read_text(errors="replace")
        if "SIM_DONE" not in text:
            unfinished += 1
        for line in text.splitlines():
            p = line.split(",")
            if p[0] == "SIM_END":
                turn, winner, cap = int(p[5]), int(p[6]), int(p[7])
                turns.append(turn)
                capped += cap
                for s in (0, 1):
                    games[names[s]] += 1
                if winner in (0, 1):
                    wins[names[winner]] += 1
                    by_map[map_id][names[winner]] += 1
                key = tuple(sorted(names))
                pair[key][1] += 1
                if winner in (0, 1) and names[winner] == key[0]:
                    pair[key][0] += 1
            elif p[0] == "SIM_RESEARCH":
                fac = names[int(p[2])]
                seats[fac] += 1
                labs[fac] += int(p[4]) > 0
                techs = [t for t in ",".join(p[5:]).split("|") if t]
                ntech[fac] += len(techs)
                for t in techs:
                    research[fac][t] += 1
            elif p[0] == "SIM_PRODUCED":
                produced[p[1]] += int(p[2])
            elif p[0] == "SIM_BUILT":
                built[p[1]] += int(p[2])
            elif p[0] == "SIM_ABILITY":
                ability[p[1]] += int(p[2])
    n = len(turns)
    print(f"games {n}  avg turns {sum(turns) / max(n, 1):.1f}  capped {capped}  unfinished logs {unfinished}")
    print("\nWIN RATE (all maps)")
    for f in sorted(games, key=lambda f: -wins[f] / games[f]):
        print(f"  {f:10s} {100 * wins[f] / games[f]:5.1f}%  ({wins[f]}/{games[f]})")
    print("\nPER MAP wins/games-per-faction")
    for m, c in by_map.items():
        print(f"  {m}: " + ", ".join(f"{f} {c[f]}" for f in sorted(c, key=lambda f: -c[f])))
    print("\nMATCHUPS (row faction's win %)")
    for (a, b), (aw, g) in sorted(pair.items()):
        print(f"  {a:10s} v {b:10s} {100 * aw / g:5.1f}%  n={g}")
    print("\nRESEARCH (seats that completed each tech / seats), labs, avg techs")
    for f in sorted(research):
        print(f"  {f} — seats {seats[f]}, lab {labs[f]}, techs/seat {ntech[f] / seats[f]:.2f}")
        for t, c in research[f].most_common():
            print(f"      {c:4d}  {t}")
    for title, c in (("PRODUCED", produced), ("BUILT", built), ("ABILITIES", ability)):
        print(f"\n{title}")
        for k, v in c.most_common():
            print(f"  {v:6d}  {k}")


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--out", required=True)
    r.add_argument("--maps", default="vertical_slice,crossroads")
    r.add_argument("-j", type=int, default=max(1, (os.cpu_count() or 2) - 2))
    r.add_argument("extra", nargs="*", help="extra SimulateMatches args (after --)")
    s = sub.add_parser("summarise")
    s.add_argument("dir")
    a = ap.parse_args()
    run(a) if a.cmd == "run" else summarise(a)


if __name__ == "__main__":
    sys.exit(main())
