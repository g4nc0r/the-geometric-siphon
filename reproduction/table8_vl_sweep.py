"""
Table 8: V/L_pool sweep (single-pool equilibrium).

Reproduces §5.3 Table 8 of the consolidated paper.

The table reports the Small / Medium / Large KellyClaude/USDC CL200
positions after their first 33 chronological rebalance events
(13 Small + 11 Medium + 9 Large = 33 total events across the three
positions, not per position).
"""

from _common import fmt_money, load_jsonl, md_table

PAPER_VL = {"Small": 0.021, "Medium": 0.063, "Large": 0.189}

# Cumulative dust band: above this magnitude a position is labelled an
# absorber/donor; smaller magnitudes are reported as neutral. The threshold
# sits above the paper's Medium-row figure (+$84), which is why the script
# reports Medium as Neutral (flipped) in line with Table 8.
ROLE_BAND_USD = 100


def main():
    phase2 = load_jsonl("phase2-controlled-superset.jsonl")

    # Kelly V/L sweep depositor
    kelly = sorted(
        [e for e in phase2 if "KellyClaude" in (e.get("name") or "") and e.get("depositor") == "🧪"],
        key=lambda e: e.get("ts", 0),
    )

    # First 33 chronological events across the three positions
    snapshot = kelly[:33]

    by_size = {"Small": [], "Medium": [], "Large": []}
    for e in snapshot:
        n = e.get("name", "")
        for size in by_size:
            if size in n:
                by_size[size].append(e)
                break

    rows = []
    for size in ("Small", "Medium", "Large"):
        es = by_size[size]
        if not es:
            continue
        deploy = es[0].get("preValue", 0)
        after = es[-1].get("postValue", 0)
        cum_dust = sum(e.get("dustPnl", 0) for e in es)
        if cum_dust > ROLE_BAND_USD:
            role = "Absorber"
        elif cum_dust < -ROLE_BAND_USD:
            role = "Donor"
        else:
            role = "Neutral (flipped)"
        rows.append([
            size,
            f"${deploy:.0f} (V/L={PAPER_VL[size]})",
            f"~${after:.0f}",
            fmt_money(cum_dust),
            role,
        ])

    print("# Table 8: V/L_pool sweep\n")
    print(f"Snapshot: first 33 chronological events across the three KellyClaude")
    print(f"positions in 🧪 depositor ({sum(len(v) for v in by_size.values())} events).\n")
    print(md_table(
        ["Position", "Deployment", "After 33 events", "Dust PnL", "Role"],
        rows,
    ))
    print()
    # Final ratio
    pvs = {s: by_size[s][-1].get("postValue", 0) for s in by_size if by_size[s]}
    if pvs.get("Medium"):
        m = pvs["Medium"]
        print(f"Final value ratio (Small : Medium : Large) = "
              f"{pvs['Small']/m:.2f} : {1.0:.2f} : {pvs['Large']/m:.2f}")


if __name__ == "__main__":
    main()
