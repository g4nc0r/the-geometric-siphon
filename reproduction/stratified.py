"""
Stratified correlations of |D| with the liquidity share L/L_p and σ_1h, by
group.

N is the number of events with |D| > $0.50. Each correlation is taken over
the events of the group on which its variable is recorded: the liquidity
share is missing on 10 Phase 1 events and σ_1h on 36 of those above the
threshold.
"""

from _common import heading, load_jsonl, spearman, md_table


GROUP_MAP = [
    ("A", "⚗️"),
    ("B", "👑"),
    ("C", "🏦"),
    ("D", "🧬"),
    ("E", "🔬"),
]


def get_sigma_1h(e):
    # The deposit canonically uses `sigma.s1h`; the bare-`1h` key is a legacy
    # spelling kept here for backward compatibility with older event logs.
    s = e.get("sigma")
    if isinstance(s, dict):
        v = s.get("s1h")
        return v if v is not None else s.get("1h")
    return None


def main():
    phase1 = load_jsonl("events-phase1.jsonl")

    # Events with |D| > 0.50. The liquidity share and σ_1h are each used
    # where recorded.
    events = []
    for e in phase1:
        d = abs(e.get("dustPnl", 0))
        if d > 0.50:
            events.append((e.get("depositor", ""), d, e.get("positionToPoolRatio"), get_sigma_1h(e)))

    rows = []
    total_n = 0
    for label, emoji in GROUP_MAP:
        group = [(d, vl, s) for dep, d, vl, s in events if dep.startswith(emoji)]
        if not group:
            continue
        total_n += len(group)
        with_vl = [(d, vl) for d, vl, _ in group if vl is not None]
        with_s = [(d, s) for d, _, s in group if s is not None]
        rho_v = spearman([d for d, _ in with_vl], [v for _, v in with_vl])
        rho_s = spearman([d for d, _ in with_s], [v for _, v in with_s])
        rows.append([label, str(len(group)), f"{rho_v:+.3f}", f"{rho_s:+.3f}"])

    all_vl = [(d, vl) for _, d, vl, _ in events if vl is not None]
    all_s = [(d, s) for _, d, _, s in events if s is not None]

    print(heading("stratified", "Stratified correlations of |D| with L/L_p and σ_1h") + "\n")
    print(f"Source: events-phase1.jsonl, |D| > $0.50 ({total_n} events).\n")
    print(md_table(
        ["Group", "N", "L/L_p → |D|", "σ_1h → |D|"],
        rows,
    ))
    print()
    print(f"Aggregate ρ(L/L_p, |D|): {spearman([d for d, _ in all_vl], [v for _, v in all_vl]):+.3f}")
    print(f"Aggregate ρ(σ_1h, |D|):  {spearman([d for d, _ in all_s], [v for _, v in all_s]):+.3f}")


if __name__ == "__main__":
    main()
