"""
Table 9: Directional asymmetry — per-portfolio replication (Theorem 5).

The siphon mechanism operates within each portfolio's depositor-keyed dust
pool. Phase 3 contains five independent portfolios (one per `depositor`),
each with its own connector-token structure. The right unit of analysis
is therefore the portfolio, not the pooled event stream: each portfolio
is a separate replication of Theorem 5's predicted directional asymmetry.

For each portfolio, this script reports the mean dust on rising and falling
events in the theorem domain (T_0 ∈ {non-USD-fiats ∪ crypto-volatiles},
T_1 ∈ {USDC, USDT, DAI}), with bootstrap 95% CIs on the difference.
The headline statistic is the sign test across portfolios:
under H_0 (no directional asymmetry), each portfolio is independently
50% likely to show rising > falling, so 5/5 portfolios in the predicted
direction has p = 1/32 ≈ 0.031.
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

    print("# Table 9: Per-portfolio directional asymmetry\n")
    print(f"Source: phase3-events.jsonl ({len(phase3):,} events after outlier filter)\n")
    print(f"Phase 3 contains {len(by_portfolio)} independent portfolios; the table reports "
          f"each portfolio's directional asymmetry in the theorem domain (T_0 volatile, "
          f"T_1 USD-stable), with bootstrap 95% CIs on the (rising − falling) mean.\n")

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
        print(f"Per-portfolio sign test: {n_predicted}/{n_portfolios} portfolios in predicted "
              f"direction (rising > falling), one-sided p = {p_sign:.4f}.")


if __name__ == "__main__":
    main()
