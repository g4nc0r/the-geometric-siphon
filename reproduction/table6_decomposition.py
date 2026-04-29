"""
Table 6: Core decomposition of observed dust flow.

Reproduces §5.1 Table 6 from supplementary/slippage-decomposition.json
and supplementary/swap-verification.json.
"""

import statistics
from _common import load_supp_json, spearman, md_table


def main():
    sd = load_supp_json("slippage-decomposition.json")
    sv = load_supp_json("swap-verification.json")

    # 72 swap-decoded events
    D = [e["D"] for e in sd]
    S = [e["S"] for e in sd]
    dR = [d + s for d, s in zip(D, S)]  # ΔR = D + S
    abs_D = [abs(x) for x in D]
    abs_dR = [abs(x) for x in dR]

    rho1 = spearman(dR, D)
    rho2 = spearman(abs_dR, abs_D)

    n_swap = sum(1 for e in sv if e.get("hadSwap"))
    n_total = len(sv)
    n_no_swap = n_total - n_swap

    mean_S = statistics.mean(S)
    median_pct = statistics.median(e["pctOfSwap"] for e in sd)
    median_size = statistics.median(e["swapSize"] for e in sd)

    print("# Table 6: Core decomposition of observed dust flow\n")
    print(f"Source: supplementary/slippage-decomposition.json (72 swap-decoded "
          f"Phase 1 events).\n")
    print(md_table(
        ["Metric", "Value", "N"],
        [
            ["Spearman ρ(ΔR, D)",     f"**{rho1:.3f}**",  "72"],
            ["Spearman ρ(|ΔR|, |D|)", f"**{rho2:.3f}**",  "72"],
            ["Events with swap (Phase 1 manual subset)", "72", "-"],
            ["Events without swap (Phase 1 manual subset)", "20", "-"],
            ["Mean slippage S",      f"${mean_S:.2f}", "72"],
            ["Median swap price impact", f"**{median_pct:.2f}%**", "72"],
            ["Median swap size",     f"${median_size:.2f}", "72"],
        ],
    ))
    print()
    # Phase-1-wide swap fraction: 92 manually decoded + 646 in swap-verification
    # The paper's "536 events (73%)" combines the manual + auto subsets (72 + 464).
    auto_swap = sum(1 for e in sv if e.get("hadSwap"))
    auto_total = len(sv)
    combined_swap = 72 + auto_swap
    combined_total = 92 + auto_total
    # Gross flow: % attributable to swap events in the swap-verification file
    total_abs_d = sum(abs(e.get("dustPnl", 0)) for e in sv)
    swap_abs_d = sum(abs(e.get("dustPnl", 0)) for e in sv if e.get("hadSwap"))
    print(f"Across full Phase 1 dataset (738 events) the manual + auto split is:")
    print(f"  swap_events = 72 (manual) + {auto_swap} (swap-verification.json) = "
          f"{combined_swap} of {combined_total} ({100*combined_swap/combined_total:.1f}%)")
    print(f"Gross |D| from swap events: {100*swap_abs_d/total_abs_d:.1f}% of |D|.")


if __name__ == "__main__":
    main()
