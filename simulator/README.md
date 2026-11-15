# Simulator

![Python](https://img.shields.io/badge/Python-3.9+-3776ab?logo=python&logoColor=white)
![Arithmetic](https://img.shields.io/badge/arithmetic-exact_integers-2e7d32)

Part of [The Geometric Siphon](../README.md). Described in §6 of the paper and used in §5.12 to §5.14.

An exact simulator of a portfolio of concentrated liquidity positions rebalanced by a position manager with a shared balance. Pool arithmetic is an integer port of Uniswap V3 core, which Aerodrome Slipstream shares: tick and sqrt-price conversion, swap steps, mint and burn amounts, with Solidity's rounding at each step. The position manager's sizing and swap rules are ported from the contract studied in the paper.

This folder holds the reference implementation, an example and the check of Proposition 10. The parallel implementation and the parameter-grid experiments of the paper are not included. The replay of §6 runs against the on-chain dataset, which is not published.

## Files

| File | Contents | Needs |
|---|---|---|
| [`v3math.py`](./v3math.py) | Integer V3 pool arithmetic and the position manager's swap rule | standard library |
| [`siphon_ref.py`](./siphon_ref.py) | The portfolio model: tokens, pools, positions, rebalances, shared or isolated balances, the neutral rule | standard library |
| [`example.py`](./example.py) | Four positions in one pool under three settings | standard library |
| [`excursion_check.py`](./excursion_check.py) | Proposition 10: excursions out and back in integer arithmetic | pandas |
| [`excursion_analyse.py`](./excursion_analyse.py) | Comparison of those excursions with the closed form | pandas, numpy |

## Running

```bash
python3 example.py

python3 excursion_check.py     # writes out/excursion_rows.csv, 22,624 excursions
python3 excursion_analyse.py
```

`example.py` runs the same four positions, of sizes 1 : 2 : 3 : 4, three ways and prints their shares of the deployed value at the start and at the end:

| Setting | Outcome |
|---|---|
| The contract's swap, shared balance | shares move towards one another |
| An exact swap at no cost, shared balance | shares stay at 0.1, 0.2, 0.3, 0.4 |
| No swap, isolated balances | every position goes to zero |

`excursion_analyse.py` reports, for the 680 fee-free excursions that stay inside the range and recentre exactly on the tick grid, a median relative error of 3.1 × 10⁻¹⁷ against `1 − sinh²(ℓ/2) / sinh²(h/2)` evaluated to 50 digits.

## The model

One run is one depositor's portfolio.

- **Tokens.** Each token has a log price in ticks that follows a random walk with integer normal steps, so runs are reproducible from a seed.
- **Pools.** A pool is a pair of tokens with a tick spacing, a fee and outside liquidity held over the full range. Each step an arbitrageur sets every pool to its fair tick. Positions earn no fees.
- **Positions.** A position has liquidity on a range of fixed width in tick spacings and is rebalanced when the price comes within a set fraction of the half-width from a boundary.
- **Rebalance.** Burn, take the balance, swap, mint at the price after the swap, credit the leftover. The swap is one of: none; the contract's swap, optionally scaled; an exact conversion at the price before the swap with no fee and no impact.
- **Balance.** Shared across the portfolio's positions with no record of ownership; isolated per position, the setting of Theorems 1 and 3; or shared under the neutral rule of Proposition 12.

The docstring of `siphon_ref.py` gives the configuration keys.
