"""
Table 16: Hub-spoke topology (Group B, Phase 2).

Reproduces §5.4 Table 16. Snapshot: first 301 chronological events
across depositor 👑's four Group B positions (WETH/USDC CL50 hub +
3 spokes).
"""

from _common import fmt_money, load_jsonl, filter_outliers, md_table

GROUP_B_POSITIONS = [
    "WETH/USDC CL50",
    "USDC/CHECK CL100",
    "WETH/AERO CL200",
    "WETH/VVV CL100",
]


def main():
    phase2 = filter_outliers(load_jsonl("phase2-controlled-superset.jsonl"))

    group_b = sorted(
        [e for e in phase2 if e.get("name") in GROUP_B_POSITIONS and e.get("depositor") == "👑"],
        key=lambda e: e.get("ts", 0),
    )
    snapshot = group_b[:301]

    by_pos = {n: [] for n in GROUP_B_POSITIONS}
    for e in snapshot:
        by_pos[e.get("name", "")].append(e)

    rows = []
    for name in GROUP_B_POSITIONS:
        evts = by_pos[name]
        cum = sum(e.get("dustPnl", 0) for e in evts)
        role = "Donor" if cum < 0 else "Absorber"
        suffix = " (hub)" if name == "WETH/USDC CL50" else ""
        rows.append([
            f"{name}{suffix}",
            role,
            fmt_money(cum),
            str(len(evts)),
        ])

    print("# Table 16: Hub-spoke topology (Group B, 301 events)\n")
    print("Snapshot: first 301 chronological events across the 4 Group B "
          "positions in 👑 depositor.\n")
    print(md_table(
        ["Position", "Role", "Cumulative dust", "Events"],
        rows,
    ))
    print()
    hub_dust = sum(e.get("dustPnl", 0) for e in by_pos["WETH/USDC CL50"])
    spokes_dust = sum(e.get("dustPnl", 0) for n, evts in by_pos.items()
                      if n != "WETH/USDC CL50" for e in evts)
    print(f"Hub donated ${-hub_dust:,.0f}; spokes absorbed ${spokes_dust:,.0f}; "
          f"difference ${(-hub_dust) - spokes_dust:,.0f}.")


if __name__ == "__main__":
    main()
