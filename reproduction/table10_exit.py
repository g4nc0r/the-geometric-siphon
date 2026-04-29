"""
Tables 10 and 11: Exit asymmetry per portfolio + reversed-ordering negative
control (Theorem 6).

Same per-portfolio framing as `table9_directional.py`. Theorem 6 predicts
V_below < V_above on volatile/stablecoin pairs in V3 ordering, so within
each portfolio the mean dust on above-exits should exceed the mean on
below-exits (above − below > 0). Per-portfolio bootstrap CIs are reported
along with a sign test across portfolios.

The script also prints the reversed-ordering negative control for the
largest portfolio (the only one with enough reversed-ordering exits to
test): Theorem 6 predicts the inequality should sign-flip when V3 token
roles are reversed, so V_below should become positive.
"""

import random
from collections import defaultdict
from math import comb

from _common import load_jsonl, filter_outliers, md_table, pair_kind, fmt_money

# Fixed seed for bit-reproducible bootstrap.
random.seed(20260430)
N_BOOT = 5000


def mean(xs):
    return sum(xs) / len(xs) if xs else None


def bootstrap_diff_ci(above, below, n_iter=N_BOOT):
    if not above or not below:
        return None, None
    diffs = []
    for _ in range(n_iter):
        a = sum(random.choice(above) for _ in range(len(above))) / len(above)
        b = sum(random.choice(below) for _ in range(len(below))) / len(below)
        diffs.append(a - b)
    diffs.sort()
    return diffs[int(n_iter * 0.025)], diffs[int(n_iter * 0.975)]


def main():
    phase3 = filter_outliers(load_jsonl("phase3-events.jsonl"))
    by_portfolio = defaultdict(list)
    for e in phase3:
        by_portfolio[e.get("depositor", "?")].append(e)
    portfolios = sorted(by_portfolio.keys(), key=lambda w: -len(by_portfolio[w]))

    print("# Table 10: Per-portfolio exit asymmetry\n")
    n_above = sum(1 for e in phase3 if e.get("exitSide") == "above")
    n_below = sum(1 for e in phase3 if e.get("exitSide") == "below")
    print(f"Source: phase3-events.jsonl, exit events ({n_above + n_below:,} total).\n")
    print(f"Theorem 6 predicts V_below < V_above on volatile/stablecoin pairs in V3 "
          f"ordering. Within each portfolio's theorem domain, the mean dust on "
          f"above-exits should exceed the mean on below-exits.\n")

    rows = []
    n_portfolios = 0
    n_predicted = 0
    for w in portfolios:
        events = by_portfolio[w]
        sub = [e for e in events if pair_kind(e) == "sv-vol-t0"]
        above = [e.get("dustPnl", 0) for e in sub if e.get("exitSide") == "above"]
        below = [e.get("dustPnl", 0) for e in sub if e.get("exitSide") == "below"]
        if len(above) < 3 or len(below) < 3:
            rows.append([w, f"{len(events):,}", f"{len(above)}", f"{len(below)}",
                         "—", "—", "—", "—", "—"])
            continue
        am, bm = mean(above), mean(below)
        diff = am - bm
        ci_lo, ci_hi = bootstrap_diff_ci(above, below)
        rows.append([
            w,
            f"{len(events):,}",
            f"{len(above):,}",
            f"{len(below):,}",
            fmt_money(am, places=2),
            fmt_money(bm, places=2),
            fmt_money(diff, places=0),
            fmt_money(ci_lo, places=0),
            fmt_money(ci_hi, places=0),
        ])
        n_portfolios += 1
        if diff > 0:
            n_predicted += 1

    print(md_table(
        ["Portfolio", "Events", "N_a", "N_b", "V_a", "V_b", "Diff",
         "CI Lo", "CI Hi"],
        rows,
    ))
    print()
    if n_portfolios:
        p_sign = sum(comb(n_portfolios, k)
                     for k in range(n_predicted, n_portfolios + 1)) / 2 ** n_portfolios
        print(f"Per-portfolio sign test: {n_predicted}/{n_portfolios} portfolios in predicted "
              f"direction (above > below), one-sided p = {p_sign:.4f}.")

    # Table 11: reversed-ordering negative control on P1.
    print()
    print("# Table 11: P1 reversed-ordering negative control\n")
    print("Theorem 6 predicts the V_below < V_above inequality reverses when V3 token "
          "roles are flipped. P1 is the only portfolio with enough reversed-ordering "
          "exits to test this directly.\n")
    rows = []
    for w in portfolios:
        sub = [e for e in by_portfolio[w] if pair_kind(e) == "sv-stable-t0"]
        above = [e.get("dustPnl", 0) for e in sub if e.get("exitSide") == "above"]
        below = [e.get("dustPnl", 0) for e in sub if e.get("exitSide") == "below"]
        if not above and not below:
            continue
        am = mean(above) if above else None
        bm = mean(below) if below else None
        rows.append([
            w,
            f"{len(above)}",
            f"{len(below)}",
            fmt_money(am, places=2) if am is not None else "—",
            fmt_money(bm, places=2) if bm is not None else "—",
        ])
    print(md_table(
        ["Portfolio", "N_a", "N_b", "V_a", "V_b"],
        rows,
    ))


if __name__ == "__main__":
    main()
