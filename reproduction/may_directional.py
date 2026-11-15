"""
May 2026 version: per-portfolio dust on rising and falling rebalances.

Reproduces the directional comparison of the May 2026 version of the
paper, which the November 2026 revision withdraws (Appendix F). The
comparison reads `normDisplacement` from the logged range fields. Until
24 May 2026 the logger read a position's old range after it had been
updated, so that field is wrong on most range-changing rebalances in the
bundled Phase 3 file (paper §4.6).

The revision's own table uses displacement derived from chain events,
which are not in the deposit, and finds rising above falling in 2 of 5
portfolios. The revision also explains why neither comparison tests
Theorem 5: dust flow at a rebalance with a swap is a different quantity
from the value of a displaced position.

For each portfolio the script reports the mean dust on rising and falling
events on pairs with T_0 volatile and T_1 USD-stable, with bootstrap 95%
CIs on the difference, and the count of portfolios with rising above
falling.
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


def bootstrap_diff_ci(rising, falling, n_iter=N_BOOT):
    if not rising or not falling:
        return None, None
    diffs = []
    for _ in range(n_iter):
        a = sum(random.choice(rising) for _ in range(len(rising))) / len(rising)
        b = sum(random.choice(falling) for _ in range(len(falling))) / len(falling)
        diffs.append(a - b)
    diffs.sort()
    return diffs[int(n_iter * 0.025)], diffs[int(n_iter * 0.975)]


def main():
    phase3 = filter_outliers(load_jsonl("phase3-events.jsonl"))
    by_portfolio = defaultdict(list)
    for e in phase3:
        by_portfolio[e.get("depositor", "?")].append(e)
    portfolios = sorted(by_portfolio.keys(), key=lambda w: -len(by_portfolio[w]))

    print(heading("changes", "the May 2026 directional comparison, from logged fields", prefix="May 2026 column of Table") + "\n")
    print(f"Source: phase3-events.jsonl ({len(phase3):,} events after outlier filter)\n")
    print(f"Phase 3 contains {len(by_portfolio)} portfolios. Mean dust on rising and falling "
          f"rebalances, pairs with T_0 volatile and T_1 USD-stable, displacement from the logged "
          f"range fields, with bootstrap 95% CIs on the (rising − falling) mean.\n")

    rows = []
    n_portfolios = 0
    n_predicted = 0
    for w in portfolios:
        events = by_portfolio[w]
        sub = [e for e in events if pair_kind(e) == "sv-vol-t0"]
        rising = [e.get("dustPnl", 0) for e in sub
                  if (e.get("normDisplacement") or 0) > 0.1]
        falling = [e.get("dustPnl", 0) for e in sub
                   if (e.get("normDisplacement") or 0) < -0.1]
        if not rising or not falling:
            rows.append([w, f"{len(events):,}", "—", "—", "—", "—", "—", "—", "—"])
            continue
        ar, af = mean(rising), mean(falling)
        diff = ar - af
        ci_lo, ci_hi = bootstrap_diff_ci(rising, falling)
        rows.append([
            w,
            f"{len(events):,}",
            f"{len(rising):,}",
            f"{len(falling):,}",
            fmt_money(ar, places=2),
            fmt_money(af, places=2),
            fmt_money(diff, places=0),
            fmt_money(ci_lo, places=0),
            fmt_money(ci_hi, places=0),
        ])
        n_portfolios += 1
        if diff > 0:
            n_predicted += 1

    print(md_table(
        ["Portfolio", "Events", "N_r", "N_f", "V_r", "V_f", "Diff",
         "CI Lo", "CI Hi"],
        rows,
    ))
    print()
    if n_portfolios:
        p_sign = sum(comb(n_portfolios, k)
                     for k in range(n_predicted, n_portfolios + 1)) / 2 ** n_portfolios
        print(f"Rising above falling in {n_predicted} of {n_portfolios} portfolios on the logged fields "
              f"(one-sided sign-test p = {p_sign:.4f}). The revision finds 2 of 5 on chain-derived "
              f"displacement.")


if __name__ == "__main__":
    main()
