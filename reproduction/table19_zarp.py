"""
Table 19: USDC/ZARP CL10 14-event extinction trajectory.

Reproduces §5.8 Table 19 from phase2-controlled-superset.jsonl
(equivalent supplementary/fiat-experiment-events.jsonl gives the same
result for ZARP). The "14 events" are the chronological pre-extinction
events; events 15–21 in the bundled log are post-extinction tail with
V ≈ $2 and are excluded by the paper's 14-row table.
"""

import math

from _common import fmt_money, load_jsonl, md_table


def main():
    phase2 = load_jsonl("phase2-controlled-superset.jsonl")
    zarp = sorted(
        [e for e in phase2 if "ZARP" in (e.get("name") or "")],
        key=lambda e: e.get("ts", 0),
    )[:14]

    rows = []
    for i, e in enumerate(zarp, 1):
        iso = e.get("iso", "")[:16].replace("T", " ")
        pre = e.get("preValue", 0)
        post = e.get("postValue", 0)
        d = e.get("dustPnl", 0)
        vl = e.get("positionToPoolRatio", 0) or 0
        # Compute α only for donation events
        if d < 0 and pre > 0:
            alpha = (-d) / pre
            alpha_s = f"{alpha:.2f}"
        else:
            alpha_s = "-"
        pl_raw = e.get("poolLiquidity", 0) or 0
        try:
            pl = float(pl_raw)
        except (TypeError, ValueError):
            pl = 0
        # Paper displays L_pool scaled by 1e15 (raw 1.35e17 prints as "135M",
        # raw 1.34e18 prints as "1,341M"). The factor reflects the underlying
        # token decimals and L precision in the V3 amount equations.
        pl_s = f"{pl/1e15:,.0f}M" if pl else "-"
        rows.append([
            str(i),
            iso,
            f"{pre:.0f}" if pre >= 10 else f"{pre:.2f}",
            f"{post:.0f}" if post >= 10 else f"{post:.2f}",
            fmt_money(d),
            f"{vl:.3f}",
            alpha_s,
            pl_s,
        ])

    print("# Table 19: USDC/ZARP CL10 14-event extinction trajectory\n")
    print("Source: phase2-controlled-superset.jsonl, ZARP subset, first 14 events.\n")
    print(md_table(
        ["Event", "Time (UTC)", "Pre ($)", "Post ($)", "Dust D",
         "V/L_pool", "α", "L_pool"],
        rows,
    ))
    print()

    # Aggregate stats
    donated = sum(e.get("dustPnl", 0) for e in zarp if e.get("dustPnl", 0) < 0)
    absorbed_evts = [e for e in zarp if e.get("dustPnl", 0) > 0]
    absorbed = sum(e.get("dustPnl", 0) for e in absorbed_evts)
    net = donated + absorbed
    initial = zarp[0].get("preValue", 0)
    print(f"Total donated:  ${donated:+,.0f}")
    print(f"Total absorbed: ${absorbed:+,.0f} across {len(absorbed_evts)} events")
    print(f"Net flow:       ${net:+,.0f} ({abs(net)/initial*100:.1f}% of initial ${initial:.0f})")

    donations = [e.get("dustPnl", 0) for e in zarp if e.get("dustPnl", 0) < 0]
    pre_values = [e.get("preValue", 0) for e in zarp if e.get("dustPnl", 0) < 0]
    if donations:
        alphas = [-d / pv for d, pv in zip(donations, pre_values) if pv > 0]
        alpha_bar = sum(alphas) / len(alphas)
        alpha_min = min(alphas)
        terminal = zarp[-1].get("postValue", 0)
        k_star = math.ceil(math.log(initial / terminal) / math.log(1 / (1 - alpha_bar)))
        k_loose = math.ceil(math.log(initial / terminal) / math.log(1 / (1 - alpha_min)))
        print(f"\nExtinction bounds (Theorem 3 part iv):")
        print(f"  ᾱ across {len(alphas)} donation events: {alpha_bar:.3f}")
        print(f"  α_min: {alpha_min:.3f}")
        print(f"  K* (tight) = ⌈ln({initial:.0f}/{terminal:.2f}) / ln(1/{1-alpha_bar:.2f})⌉ = {k_star}")
        print(f"  K* (loose) = ⌈ln({initial:.0f}/{terminal:.2f}) / ln(1/{1-alpha_min:.2f})⌉ = {k_loose}")


if __name__ == "__main__":
    main()
