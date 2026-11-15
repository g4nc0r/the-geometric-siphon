# Reproduction scripts

![Python](https://img.shields.io/badge/Python-3.9+_stdlib-3776ab?logo=python&logoColor=white)
[![Data DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19904831.svg)](https://doi.org/10.5281/zenodo.19904831)

Part of [The Geometric Siphon](../README.md).

Twelve scripts that compute the paper's tables from the event logs of the data deposit. Python 3.9 or later, standard library only. Table and section numbers are those of the November 2026 revision; they are set in one place, `TABLES` in `_common.py`.

The deposit holds the operator's rebalance log. The revision reads ranges, exit sides, displacements and swap amounts from chain events instead (paper §4.6), and those events are not in the deposit. The scripts therefore regenerate the tables that rest on the log's dust and value fields, and say in their output where a column of the printed table comes from chain events.

## Usage

Download the deposit and place this folder inside it, beside the JSONL files.

```bash
python3 run_all.py          # all twelve, about 15 seconds
python3 decomposition.py    # one table
```

## Coverage

| Script | Paper table | Source data | Agreement with the printed table |
|---|---|---|---|
| `decomposition.py` | Table 8 (§5.1), dust flow and slippage | `supplementary/slippage-decomposition.json`, `swap-verification.json` | exact |
| `stratified.py` | Table 9 (§5.2), stratified correlations | `events-phase1.jsonl` | exact |
| `size_sweep.py` | Table 10 (§5.3), position-size sweep | `phase2-controlled-superset.jsonl` | dust exact; end values within $5 |
| `size_sweep_bootstrap.py` | §5.3, permutation test | `phase2-controlled-superset.jsonl` | exact; the bootstrap intervals it also prints are not in the paper |
| `liquidity_share_buckets.py` | Table 17, mean D/V by liquidity share | `phase2-controlled-superset.jsonl` | differs, see below |
| `cross_group.py` | Table 18, cross-group decomposition | `supplementary/closed-form-decomposition-cache.json` | inputs only |
| `hub_spoke.py` | Table 19, hub-spoke topology | `phase2-controlled-superset.jsonl` | exact |
| `regime.py` | Table 20, Phase 1 regimes | `events-phase1.jsonl` | exact |
| `fx.py` | Table 21, stablecoin FX isolation | `supplementary/fiat-experiment-events.jsonl` | dust and liquidity share exact; two columns not regenerated |
| `zarp.py` | Table 22, USDC/ZARP trajectory | `phase2-controlled-superset.jsonl` | exact; swap column not regenerated |
| `may_directional.py` | Table 23, May 2026 column: rising against falling dust | `phase3-events.jsonl` | reproduces the May figures |
| `may_exit.py` | Table 23, May 2026 column: above against below exits | `phase3-events.jsonl` | reproduces the May figures |

## Where the output differs from the paper

- **Table 17.** Three of the six buckets match in count and mean, and the 0.05 to 0.10 bucket has the same mean with 30 events against 29. The 0.01 to 0.05 bucket holds 66 events against 98 printed and the 0.20 to 0.50 bucket 10 against 9, so the total is 576 against 606. The events behind the difference are not in the deposit.
- **Table 18.** The script decodes per-token dust from 581 receipts and reports how many parse. The paper's nine-row table also needs each receipt's depositor, which is not in the deposit.
- **Table 21, σ column.** The paper's values were computed at rebalance time and are not recoverable from the deposit. The script prints the bundled `sigma` values, which differ (73.6, 1.6, 4.6, 1.5, 0.2 against 98.8, 1.4, 5.0, 1.5, 0.1).
- **Tables 21 and 22, swap columns.** The paper counts internal swaps from pool Swap events. The logged swap amount is zero on every row of the deposit and is not evidence that no swap was made.
- **Table 22, extinction bound.** The paper's bound of 6 rebalances uses the zero-swap residual fractions, which need the pool state before each transaction. The script prints the bound at the realised mean α, 11.

## The two May 2026 scripts

`may_directional.py` and `may_exit.py` reproduce comparisons that the May 2026 version of the paper reported and the revision withdraws. They read displacement and exit side from the logged range fields. Until 24 May 2026 the logger read a position's old range after it had been updated, so those fields are wrong on most range-changing rebalances in the deposit. The revision's Tables 24 and 25 make the same comparisons on sides derived from chain events and reach different counts. The scripts are kept so that the May figures listed in Table 23 can be checked.

## Snapshot conventions

Several tables report values at a snapshot of the log. Each script applies its own.

| Script | Snapshot |
|---|---|
| `size_sweep.py` | First 33 chronological events across the three KellyClaude positions |
| `liquidity_share_buckets.py` | Phase 2 events through 2026-03-09 03:00 UTC, all depositors |
| `hub_spoke.py` | First 301 chronological events across depositor 👑's four Group B positions |
| `fx.py` | Fiat events through 2026-03-09 00:00 UTC, the end of the weekend window |
| `zarp.py` | First 14 chronological ZARP events |

The other scripts use the full files.

## `depositor_mapping.json`

Lookups from depositor label to paper group (A to E), one per phase. Use the one that matches the table.
