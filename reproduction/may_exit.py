"""
May 2026 version: per-portfolio dust on above-range and below-range exits,
and the reversed-ordering comparison.

Reproduces the exit comparison of the May 2026 version of the paper, which
the November 2026 revision withdraws (Appendix F). The comparison reads
`exitSide` from the logged range fields, which are wrong on most
range-changing rebalances in the bundled Phase 3 file (paper §4.6): the
file records 2,428 exits where chain events give 5,774.

The revision's own tables use exit sides derived from chain events, which
are not in the deposit. There every interval spans zero and the
reversed-ordering pairs do not change sign. The revision also explains why
neither comparison tests Theorem 6.
"""

import random
from collections import defaultdict
from math import comb

from _common import heading, load_jsonl, filter_outliers, md_table, pair_kind, fmt_money

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

    print(heading("changes", "the May 2026 exit comparison, from logged fields", prefix="May 2026 column of Table") + "\n")
    n_above = sum(1 for e in phase3 if e.get("exitSide") == "above")
    n_below = sum(1 for e in phase3 if e.get("exitSide") == "below")
    print(f"Source: phase3-events.jsonl, logged exit events ({n_above + n_below:,} total).\n")
    print(f"Mean dust on above-range and below-range exits, pairs with T_0 volatile and "
          f"T_1 USD-stable, exit side from the logged range fields.\n")

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
        print(f"Above-range exits above below-range exits in {n_predicted} of {n_portfolios} portfolios "
              f"on the logged fields (one-sided sign-test p = {p_sign:.4f}).")

    # Reversed-ordering pairs (T_0 USD-stable).
    print()
    print("## Reversed-ordering pairs, from logged fields\n")
    print("Mean dust on exits of pairs with T_0 USD-stable. The largest portfolio is the "
          "only one with more than a handful of such exits.\n")
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
