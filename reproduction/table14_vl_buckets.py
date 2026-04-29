"""
Table 14: V/L_pool transfer function (Phase 2 cross-position scatter).

Reproduces §5.2.2 Table 14. Snapshot: Phase 2 events up to 2026-03-09
03:00 UTC across all four active depositors. N=602 here vs 606 in the
paper (small snapshot-drift delta).
"""

from _common import load_jsonl, filter_outliers, md_table

CUTOFF_ISO = "2026-03-09T03"

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

    # Apply 9 March 03:00 UTC cutoff and require V/L data
    snap = [e for e in phase2 if e.get("iso", "") < CUTOFF_ISO and e.get("positionToPoolRatio") is not None]

    rows = []
    for label, pred in BUCKETS:
        matched = [e for e in snap if pred(e["positionToPoolRatio"])]
        if not matched:
            continue
        ratios = [e.get("dustPnl", 0) / e["preValue"] for e in matched
                  if e.get("preValue", 0) > 0]
        mean_dv = sum(ratios) / len(ratios) if ratios else 0
        rows.append([label, str(len(matched)), f"{mean_dv:+.4f}"])

    print("# Table 14: V/L_pool transfer function\n")
    print(f"Source: phase2-controlled-superset.jsonl, events with V/L_pool data "
          f"through {CUTOFF_ISO} UTC ({len(snap)} events).\n")
    print(md_table(["V/L_pool range", "N", "Mean D/V"], rows))


if __name__ == "__main__":
    main()
