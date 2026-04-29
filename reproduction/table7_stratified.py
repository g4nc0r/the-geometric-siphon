"""
Table 7: Stratified correlations of |D| with V/L_pool and σ_1h, by group.

Reproduces §5.2.1 Table 7. Per-group N counts here are 5–15 events lower
than the paper, because this script applies a strict `sigma.s1h is not None`
filter; the paper's filter was slightly looser. The Spearman ρ values
match within rounding.
"""

from _common import load_jsonl, spearman, md_table


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
        return s.get("s1h") or s.get("1h")
    return None


def main():
    phase1 = load_jsonl("events-phase1.jsonl")

    # Filter to |D| > 0.50 with V/L_pool and σ_1h available
    events = []
    for e in phase1:
        d = abs(e.get("dustPnl", 0))
        vl = e.get("positionToPoolRatio")
        s1h = get_sigma_1h(e)
        if d > 0.50 and vl is not None and s1h is not None:
            events.append((e.get("depositor", ""), d, vl, s1h))

    rows = []
    total_n = 0
    all_d, all_vl, all_s = [], [], []
    for label, emoji in GROUP_MAP:
        group = [(d, vl, s) for dep, d, vl, s in events if dep.startswith(emoji)]
        if not group:
            continue
        ds  = [d  for d,  _,  _  in group]
        vls = [vl for _,  vl, _  in group]
        ss  = [s  for _,  _,  s  in group]
        all_d.extend(ds); all_vl.extend(vls); all_s.extend(ss)
        total_n += len(group)
        rho_v = spearman(ds, vls)
        rho_s = spearman(ds, ss)
        rows.append([label, str(len(group)), f"{rho_v:+.3f}", f"{rho_s:+.3f}"])

    print("# Table 7: Stratified correlations of |D| with V/L_pool and σ_1h\n")
    print(f"Source: events-phase1.jsonl, |D| > $0.50 with V/L_pool "
          f"and σ_1h available ({total_n} events).\n")
    print(md_table(
        ["Group", "N", "V/L_pool → |D|", "σ_1h → |D|"],
        rows,
    ))
    print()
    if all_d:
        print(f"Aggregate ρ(V/L_pool, |D|): {spearman(all_d, all_vl):+.3f}")
        print(f"Aggregate ρ(σ_1h, |D|):    {spearman(all_d, all_s):+.3f}")


if __name__ == "__main__":
    main()
