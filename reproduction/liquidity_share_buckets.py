"""
Mean D/V by liquidity share L/L_p (Phase 2 cross-position scatter).

Snapshot: Phase 2 events up to the end of 8 March 2026 (UTC) across all four
active depositors. Three of the six buckets match the printed table in count
and mean, and the 0.05 to 0.10 bucket has the same mean with 30 events
against 29. The 0.01 to 0.05 bucket holds 66 events here against 98 printed,
and the 0.20 to 0.50 bucket 10 against 9, so the total is 576 against 606.
The events behind the difference are not in the deposit.
"""

from _common import heading, load_jsonl, filter_outliers, md_table

CUTOFF_ISO = "2026-03-09T00:00:00Z"

BUCKETS = [
    ("< 0.01",        lambda v: v < 0.01),
    ("0.01–0.05",     lambda v: 0.01 <= v < 0.05),
    ("0.05–0.10",     lambda v: 0.05 <= v < 0.10),
    ("0.10–0.20",     lambda v: 0.10 <= v < 0.20),
    ("0.20–0.50",     lambda v: 0.20 <= v < 0.50),
    ("0.50–1.00",     lambda v: 0.50 <= v <= 1.00),
]


def main():
    phase2 = filter_outliers(load_jsonl("phase2-controlled-superset.jsonl"))

    # Apply 9 March 03:00 UTC cutoff and require the liquidity share
    snap = [e for e in phase2 if e.get("iso", "") <= CUTOFF_ISO and e.get("positionToPoolRatio") is not None]

    rows = []
    for label, pred in BUCKETS:
        matched = [e for e in snap if pred(e["positionToPoolRatio"])]
        if not matched:
            continue
        ratios = [e.get("dustPnl", 0) / e["preValue"] for e in matched
                  if e.get("preValue", 0) > 0]
        mean_dv = sum(ratios) / len(ratios) if ratios else 0
        rows.append([label, str(len(matched)), f"{mean_dv:+.4f}"])

    print(heading("liquidity_share_buckets", "Mean D/V by liquidity share L/L_p") + "\n")
    print(f"Source: phase2-controlled-superset.jsonl, events with L/L_p "
          f"through {CUTOFF_ISO} UTC ({len(snap)} events).\n")
    print(md_table(["L/L_p range", "N", "Mean D/V"], rows))


if __name__ == "__main__":
    main()
