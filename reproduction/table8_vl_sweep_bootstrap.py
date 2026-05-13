"""
Table 8 supplement: bootstrap and permutation analyses on the V/L_pool sweep.

Same 33-event slice as `table8_vl_sweep.py`. Reports per-position bootstrap
CIs on the dust-mediated growth multiplier (1 + cumulative_dust /
deployment) and a permutation test on the per-event Spearman rank
correlation between preValue and dustPnl. Theorem 2 predicts a strictly
negative correlation; the permutation null reshuffles dustPnl across the
33 events while holding preValue fixed.
"""

import random

from _common import load_jsonl, md_table, spearman


B = 10_000
SEED = 20260514


def percentile(xs, q):
    s = sorted(xs)
    k = (len(s) - 1) * q / 100.0
    lo = int(k)
    hi = min(lo + 1, len(s) - 1)
    frac = k - lo
    return s[lo] * (1 - frac) + s[hi] * frac


def main():
    phase2 = load_jsonl("phase2-controlled-superset.jsonl")
    kelly = sorted(
        [e for e in phase2 if "KellyClaude" in (e.get("name") or "") and e.get("depositor") == "🧪"],
        key=lambda e: e.get("ts", 0),
    )
    snap = kelly[:33]

    by_size = {"Small": [], "Medium": [], "Large": []}
    for e in snap:
        for s in by_size:
            if s in e.get("name", ""):
                by_size[s].append(e)
                break

    obs = {}
    for s, es in by_size.items():
        deploy = es[0].get("preValue", 0)
        cum = sum(e.get("dustPnl", 0) for e in es)
        obs[s] = {"deploy": deploy, "cum_dust": cum, "growth": 1.0 + cum / deploy}

    rng = random.Random(SEED)

    # Bootstrap per-position growth multipliers (independent within position).
    growth_samples = {"Small": [], "Medium": [], "Large": []}
    for _ in range(B):
        for s, es in by_size.items():
            deploy = obs[s]["deploy"]
            dust_seq = [e.get("dustPnl", 0) for e in es]
            resampled = sum(rng.choice(dust_seq) for _ in dust_seq)
            growth_samples[s].append(1.0 + resampled / deploy)

    # Permutation test on rho(preValue, dustPnl); one-sided H1: rho < 0.
    pre_vals = [e.get("preValue", 0) for e in snap]
    dust_vals = [e.get("dustPnl", 0) for e in snap]
    obs_rho = spearman(pre_vals, dust_vals)

    dust_shuf = list(dust_vals)
    extreme = 0
    null_rhos = []
    for _ in range(B):
        rng.shuffle(dust_shuf)
        r = spearman(pre_vals, dust_shuf)
        null_rhos.append(r)
        if r <= obs_rho:
            extreme += 1
    p_value = (extreme + 1) / (B + 1)  # add-one smoothing

    print("# Table 8 supplement: bootstrap and permutation analyses\n")
    print(f"Source: phase2-controlled-superset.jsonl, first 33 chronological events "
          f"across the three KellyClaude/USDC CL200 positions in `🧪` "
          f"(13 Small + 11 Medium + 9 Large). B = {B}, seed = {SEED}.\n")

    print("## Per-position dust-mediated growth multiplier\n")
    rows = []
    for s in ("Small", "Medium", "Large"):
        d = obs[s]
        lo = percentile(growth_samples[s], 2.5)
        hi = percentile(growth_samples[s], 97.5)
        excludes_unity = "yes" if (lo > 1.0 or hi < 1.0) else "no"
        rows.append([
            s,
            f"${d['deploy']:.0f}",
            f"${d['cum_dust']:+.0f}",
            f"{d['growth']:.2f}x",
            f"[{lo:.2f}, {hi:.2f}]",
            excludes_unity,
        ])
    print(md_table(
        ["Position", "Deploy", "Cum. dust", "Growth", "95% bootstrap CI", "CI excludes 1.0"],
        rows,
    ))

    print()
    print("## Permutation test: rho(preValue, dustPnl)\n")
    print(f"Observed rho = {obs_rho:.4f}")
    print(f"Null 95% band = [{percentile(null_rhos, 2.5):.4f}, {percentile(null_rhos, 97.5):.4f}]")
    print(f"Permutations with rho <= observed: {extreme} / {B}")
    print(f"One-sided permutation p-value (H1: rho < 0) = {p_value:.5f}")


if __name__ == "__main__":
    main()
