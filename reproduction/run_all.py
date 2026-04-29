"""
Run all reproduction scripts in sequence.

Usage:
    python run_all.py
"""

import subprocess
import sys
from pathlib import Path

SCRIPTS = [
    "table6_decomposition.py",
    "table7_stratified.py",
    "table8_vl_sweep.py",
    "table9_directional.py",
    "table10_exit.py",
    "table14_vl_buckets.py",
    "table15_cross_group.py",
    "table16_hub_spoke.py",
    "table17_regime.py",
    "table18_fx.py",
    "table19_zarp.py",
]


def main():
    here = Path(__file__).resolve().parent
    failures = []
    for s in SCRIPTS:
        print("\n" + "=" * 78)
        print(f"  {s}")
        print("=" * 78)
        ret = subprocess.run(["python3", str(here / s)], cwd=here)
        if ret.returncode != 0:
            print(f"!! {s} exited with code {ret.returncode}", file=sys.stderr)
            failures.append(s)
    if failures:
        print(f"\n{len(failures)} script(s) failed: {', '.join(failures)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
