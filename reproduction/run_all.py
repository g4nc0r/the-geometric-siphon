"""
Run all reproduction scripts in sequence.

Usage:
    python run_all.py
"""

import subprocess
import sys
from pathlib import Path

SCRIPTS = [
    "decomposition.py",
    "stratified.py",
    "size_sweep.py",
    "size_sweep_bootstrap.py",
    "liquidity_share_buckets.py",
    "cross_group.py",
    "hub_spoke.py",
    "regime.py",
    "fx.py",
    "zarp.py",
    "may_directional.py",
    "may_exit.py",
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
