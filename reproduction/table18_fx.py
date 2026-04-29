"""
Table 18: Stablecoin FX isolation (Sunday weekend experiment).

Reproduces §5.6 Table 18. The paper's snapshot is fiat-experiment events
through 2026-03-09 00:00 UTC (end of Sunday 8 March, before Monday FX
markets reopened).
"""

from _common import fmt_money, load_supp_jsonl, md_table

CUTOFF_ISO = "2026-03-09T00"

FX_POSITIONS = [
    ("ZARP", "USDC/ZARP CL10"),
    ("VCHF", "VCHF/USDC CL10"),
    ("CADC", "CADC/USDC CL10"),
    ("KRWQ", "KRWQ/USDC CL10"),
    ("EURC", "EURC/USDC CL1"),
]


def avg_sigma_24h(events):
    sigmas = []
    for e in events:
        s = e.get("sigma")
        if isinstance(s, dict):
            sigmas.append(s.get("s24h") or 0)
    return sum(sigmas) / len(sigmas) if sigmas else 0


def main():
    fiat = load_supp_jsonl("fiat-experiment-events.jsonl")
    snap = [e for e in fiat if e.get("iso", "") < CUTOFF_ISO]

    rows = []
    total = 0.0
    for label, name in FX_POSITIONS:
        evts = [e for e in snap if e.get("name") == name]
        if not evts:
            continue
        first_vl = evts[0].get("positionToPoolRatio", 0)
        cum = sum(e.get("dustPnl", 0) for e in evts)
        total += cum
        avg_s = avg_sigma_24h(evts)
        sigma_str = f"{avg_s:.1f}" if avg_s else "-"
        cum_str = fmt_money(cum)
        # No DEX route existed for these fiat pools (paper §5.6).
        rows.append([label, f"{first_vl:.3f}", sigma_str, cum_str, "0"])

    print("# Table 18: Stablecoin FX isolation\n")
    print(f"Source: supplementary/fiat-experiment-events.jsonl, snapshot through "
          f"{CUTOFF_ISO} UTC ({len(snap)} events; markets closed Sun 8 March).\n")
    print(md_table(
        ["Position", "V/L_pool", "σ_24h", "Cumulative dust", "Swaps"],
        rows,
    ))
    print()
    print(f"Total fiat dust at snapshot: {fmt_money(total)}")


if __name__ == "__main__":
    main()
