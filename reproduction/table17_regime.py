"""
Table 17: Phase 1 regime partitioning by market state.

Reproduces §5.5 Table 17 from events-phase1.jsonl.
"""

from _common import fmt_money, load_jsonl, md_table

REGIMES = [
    ("P1: Stress",     "2026-03-03T17:49", "2026-03-04T06:00", "ETH $2,215 → $1,984"),
    ("P2: Recovery",   "2026-03-04T06:00", "2026-03-04T12:00", "Volatility subsides"),
    ("P3: Rally",      "2026-03-04T12:00", "2026-03-04T20:45", "BTC → $71.4K"),
    ("P4: Post-Rally", "2026-03-04T20:45", "2026-03-05T04:34", "Consolidation"),
    ("P5: Calm",       "2026-03-05T04:34", "2026-03-05T11:47", "Diverse portfolios stabilise"),
]


def main():
    phase1 = load_jsonl("events-phase1.jsonl")

    rows = []
    for name, start, end, character in REGIMES:
        sub = [e for e in phase1 if start <= e.get("iso", "") < end]
        n = len(sub)
        net = sum(e.get("dustPnl", 0) for e in sub)
        rows.append([
            name,
            f"{start[5:].replace('T', ' ')} – {end[5:].replace('T', ' ')}",
            str(n),
            fmt_money(net),
            character,
        ])

    print("# Table 17: Phase 1 regime partitioning\n")
    print(f"Source: events-phase1.jsonl ({len(phase1)} events).\n")
    print(md_table(
        ["Phase", "Period (UTC)", "Events", "Net $", "Character"],
        rows,
    ))


if __name__ == "__main__":
    main()
