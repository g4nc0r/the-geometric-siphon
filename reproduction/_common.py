"""
Shared utilities for the reproduction scripts.

Each script reproduces one paper table from the bundled JSONLs and prints
markdown-formatted output.
"""

import json
import statistics
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent
SUPP_DIR = DATA_DIR / "supplementary"

# |dustPnl| threshold that flags the single outlier described in
# README.md Known Issues 1.
OUTLIER_THRESHOLD = 1e8


def load_jsonl(name):
    """Load a JSONL file from the deposit root."""
    p = DATA_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Missing dataset: {p}")
    out = []
    with open(p) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return out


def load_supp_json(name):
    """Load a JSON file from supplementary/."""
    p = SUPP_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Missing supplementary file: {p}")
    with open(p) as f:
        return json.load(f)


def load_supp_jsonl(name):
    """Load a JSONL file from supplementary/."""
    p = SUPP_DIR / name
    if not p.exists():
        raise FileNotFoundError(f"Missing supplementary file: {p}")
    out = []
    with open(p) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return out


def filter_outliers(events):
    """Drop the single |dustPnl| outlier flagged in README Known Issues 1."""
    return [e for e in events if abs(e.get("dustPnl", 0)) < OUTLIER_THRESHOLD]


def fmt_money(x, places=0):
    """Sign-aware USD formatter, e.g. 1234 → '+$1,234', -56 → '-$56'."""
    return f"{'+' if x >= 0 else '-'}${abs(x):,.{places}f}"


def is_same_range(e):
    """Strict tick-equality definition of same-range rebalance."""
    return (e.get("oldTickLower") == e.get("tickLower")
            and e.get("oldTickUpper") == e.get("tickUpper"))


def md_table(headers, rows):
    """Render a markdown-formatted table."""
    lines = ["| " + " | ".join(str(h) for h in headers) + " |"]
    lines.append("|" + "|".join(["---"] * len(headers)) + "|")
    for row in rows:
        lines.append("| " + " | ".join(str(c) for c in row) + " |")
    return "\n".join(lines)


def _load_token_classification():
    p = Path(__file__).resolve().parent / "token_classification.json"
    with open(p) as f:
        d = json.load(f)
    return (set(d["usd_stables"]),
            set(d["non_usd_fiats"]),
            set(d["crypto_volatiles"]))


def _load_v3_ordering():
    p = Path(__file__).resolve().parent / "v3_token_ordering.json"
    with open(p) as f:
        d = json.load(f)
    return d["pairs"]


_USD_STABLES, _NON_USD_FIATS, _CRYPTO_VOLATILES = _load_token_classification()
_V3_T0 = _load_v3_ordering()


def _split_pair(name):
    """Return (sym_a, sym_b) parsed from event name like 'WETH/USDC CL50', or (None, None).

    Assumes the deposit's canonical event-name shape: '{T_a}/{T_b} CL{n}'.
    Names without that shape return (None, None) and the event is treated as
    unclassified by `pair_kind`.
    """
    if not name or "/" not in name:
        return None, None
    parts = name.split()[0].split("/")
    if len(parts) != 2:
        return None, None
    return parts[0], parts[1]


def pair_kind(event):
    """
    Classify a Phase 3 event by its position pair, returning one of:

      "sv-vol-t0"     — T_0 is volatile (crypto or non-USD fiat), T_1 is USD-stable.
                         This is the proved domain of Theorems 5/6.
      "sv-stable-t0"  — T_0 is USD-stable, T_1 is volatile. Reversed-ordering control;
                         Theorem 5/6 inequalities should attenuate or sign-flip here.
      "vv"            — Both tokens volatile relative to USD. Theorems 5/6 do not apply.
      "ss"            — Both tokens are USD-stable (rare). Theorems 5/6 do not apply.
      None            — Unknown pair (not in v3_token_ordering.json).
    """
    a, b = _split_pair(event.get("name"))
    if a is None:
        return None
    key = "/".join(sorted([a, b]))
    t0 = _V3_T0.get(key)
    if t0 is None:
        return None
    t1 = b if t0 == a else a
    def _vol(s):
        return s in _CRYPTO_VOLATILES or s in _NON_USD_FIATS
    def _usd(s):
        return s in _USD_STABLES
    if _vol(t0) and _usd(t1):
        return "sv-vol-t0"
    if _usd(t0) and _vol(t1):
        return "sv-stable-t0"
    if _vol(t0) and _vol(t1):
        return "vv"
    if _usd(t0) and _usd(t1):
        return "ss"
    return None


def spearman(xs, ys):
    """Spearman rank correlation. No tied-rank correction; in the Phase 1
    samples used by this harness the deviation from a tie-aware Spearman is
    within the rounding shown in the paper."""
    n = len(xs)
    if n < 2:
        return None
    def rank(arr):
        idx = sorted(range(len(arr)), key=lambda i: arr[i])
        rk = [0] * len(arr)
        for r, i in enumerate(idx):
            rk[i] = r + 1
        return rk
    rx = rank(xs)
    ry = rank(ys)
    mx = statistics.mean(rx)
    my = statistics.mean(ry)
    num = sum((rx[i] - mx) * (ry[i] - my) for i in range(n))
    den_x = sum((rx[i] - mx) ** 2 for i in range(n)) ** 0.5
    den_y = sum((ry[i] - my) ** 2 for i in range(n)) ** 0.5
    return num / (den_x * den_y) if (den_x and den_y) else 0.0
