# Captured test output

Part of the [Foundry verification suite](./README.md) of [The Geometric Siphon](../README.md).

The values the sixteen tests print under `forge test -vv`, transcribed test by test and kept under version control as the regression target. Coverage, commands and pool descriptions are in the [README](./README.md). Section and appendix numbers refer to the paper, and the test numbers are those of its Appendix D.

| | |
|---|---|
| Result | 16 tests passed, 0 failed |
| Compiler | Solidity 0.8.26, `via_ir`, optimiser 200 runs |
| Fork pin | Base block `43_175_000`, 10 March 2026, 10:42 UTC |
| Last reproduced | forge 1.8.6, 15 November 2026 |

| Contract | Pool | Tests | Passed |
|---|---|---|---|
| `GeometricResidualProofClean` | `MockCLPool` | 3 | 3 |
| `ZeroSwapExtinctionProof` | `MockCLPool` | 4 | 4 |
| `NewTheoremsProof` | `MockCLPoolV2` | 3 | 3 |
| `GeometricResidualProof` | Slipstream fork | 4 | 4 |
| `DirectionalExitForkProof` | Slipstream fork | 2 | 2 |
| | | 16 | 16 |

The fork pin sits inside the paper's Phase 2 data window (7 to 12 March 2026) and makes the captured fork values reproducible. The qualitative results hold at every block: the residual exists, the control case leaves rounding dust only, the residual scales with size, a stock position manager absorbs nothing, `V_up > V_down`, and `V_above > V_below`.

## Contents

- [Theorem 1, mock pool: Tests 1 to 3](#theorem-1-mock-pool)
- [Theorem 3, mock pool: Tests 4 to 7](#theorem-3-mock-pool)
- [Theorems 4 to 6, mock pool: Tests 8 to 10](#theorems-4-to-6-mock-pool)
- [Theorem 1 and §7.1, Base fork](#theorem-1-and-71-base-fork)
- [Theorems 5 and 6, Base fork: Tests 11 and 12](#theorems-5-and-6-base-fork)
- [Notes](#notes)

## Theorem 1, mock pool

Contract `GeometricResidualProofClean`, pool `MockCLPool`.

### Test 1: `test_theorem1_rangeChangeCreatesResidual` (§6, App D.1)

| Step | Value |
|---|---|
| Initial position | 1 WETH + 2,500 USDC, ±500 ticks around tick 73,135 |
| Price movement | +200 ticks |
| New range | ±1,000 ticks (wider) |
| Withdrawn | 75,920,850 raw units of token0 + 3,434.58 USDC |
| Re-deposited liquidity | 6,681,244,254 (from 23,525,142,796) |
| **Residual** | 1 wei token0 + 2,061,006,718 token1 ≈ **2,061 USDC** |

Assertion `assertTrue(residual0 > 0 || residual1 > 0)` passed.

### Test 2: `test_theorem1_noRangeChange_noResidual` (App D.2)

The same setup and the same +200 tick price move, re-minted into the identical range.

| | Value |
|---|---|
| **Residual** | 1 wei token0 + 29 base units of token1 (USDC) |

The residual is integer rounding from `mulDiv` floor division. Assertion `assertLt(residual1, 1e3)` passed. This is the direction `R_old = R_new ⇒ ΔR = 0` of Theorem 1.

### Test 3: `test_theorem1_largerPositionLargerResidual` (App D.3)

| Position size | Residual (raw sum, as logged) | Ratio |
|---|---|---|
| 0.5 WETH | 1,030,503,360 | 1.0× |
| 2.0 WETH | 4,122,013,419 | 4.00× |

Assertion `assertGt(largeResidual, smallResidual)` passed.

## Theorem 3, mock pool

Contract `ZeroSwapExtinctionProof`, pool `MockCLPool`. Here α is the fraction of the value withdrawn that is not redeployed, with both valued in token1 at the price of the rebalance.

### Test 4: `test_theorem3_singleSidedExitNoSwapLosesValue` (App D.4)

| Step | Value |
|---|---|
| Initial position | 1 WETH + 2,500 USDC, range [72800, 73000] |
| Price movement | +200 ticks (above upper bound) |
| Withdrawal | 0 WETH + 2,499,999,999 USDC (100% token1) |
| New range | [73000, 73400] (requires both tokens) |
| New liquidity | **0** (the mint minimum binds at zero) |
| **α** | **100%** |

Assertions `assertLt(valueFinal, valueInitial)` and `assertGt(alpha, 0.5e18)` passed.

### Test 5: `test_theorem3_residualScalesWithDisplacement` (App D.5)

A position in a 1,000-tick range. The price is displaced upwards and the position is rebalanced with no swap into a 500-tick range around the new price. At 100 and 300 ticks the price is still inside the old range; 600 ticks is an exit.

| Displacement | α |
|---|---|
| 100 ticks | 4.85% |
| 300 ticks | 50.06% |
| 600 ticks | 100% |

Assertions `assertGt(α₁₀₀, 0)`, `assertGt(α₃₀₀, α₁₀₀)` and `assertGt(α₆₀₀, α₃₀₀)` passed.

### Test 6: `test_theorem3_repeatedRebalancesGeometricDecay` (App D.6)

Five rebalance cycles in sequence, each with a 150-tick upward price drift and no swap, starting from a position offered 2 WETH + 5,000 USDC in a ±400-tick range. The value column is the position after each rebalance, at that cycle's price. The decay factor is the value redeployed over the value withdrawn at the same price, which is `1 − α` of that cycle.

| Cycle | Value (USD) | Decay factor |
|---|---|---|
| 0 | 9,120 | |
| 1 | 6,268 | 0.684 |
| 2 | 2,855 | 0.454 |
| 3 | 1,962 | 0.684 |
| 4 | 894 | 0.454 |
| 5 | 614 | 0.684 |

Total decay over five cycles: 93%. The two factors alternate because the new bounds are rounded to the tick grid, which puts the price at two alternating distances from them. Assertions `V[k+1] < V[k]` for all `k` and `totalDecay > 90%` passed.

### Test 7: `test_theorem3_fullyOutOfRangeNearTotalLoss` (App D.7)

| Step | Value |
|---|---|
| Initial position | ±200 ticks around tick 73,135, value $4,240 |
| Price movement | +2,000 ticks past upper bound |
| Withdrawal | 0 WETH + 4,255.319148 USDC |
| New liquidity | **0** |
| **α** | **100%** |

Assertion `assertGt(α, 0.95e18)` passed.

## Theorems 4 to 6, mock pool

Contract `NewTheoremsProof`, pool `MockCLPoolV2`, which uses the exact Uniswap V3 `TickMath` constants.

### Test 8: `test_theorem4_residualMonotonicity` (§3.7, App D.9)

Eight upward displacement levels on a 1,000-tick-wide position at base tick 78,244 (price about $2,500). The theorem's domain ends at the range boundary, +500 ticks. Beyond it the position is entirely token1 and the residual stays at the boundary value.

| Displacement (ticks) | Dust (USD) | Position |
|---|---|---|
| +100 | $1,822 | in range |
| +200 | $3,663 | in range |
| +300 | $5,522 | in range |
| +400 | $7,400 | in range |
| +500 | $9,297 | at the range boundary |
| +600 | $9,297 | beyond the range |
| +700 | $9,297 | beyond the range |
| +800 | $9,297 | beyond the range |

The test counts a violation where a level is below the one before it. Zero violations. Assertion `assertEq(monotoneViolations, 0)` passed.

### Test 9: `test_theorem5_directionalAsymmetry` (§3.8, App D.10)

A position offered 2 WETH + 5,000 USDC in the range [77700, 78700], worth $9,200 at the starting price. The sqrt price is displaced by the same amount δ upwards and downwards, with both prices inside the range, and the position is valued in token1 at each. The last column is the closed form of the gap, `4 L δ (1 − s / s_b)`.

| δ, share of s | V_up (USD) | V_down (USD) | Gap | Closed form |
|---|---|---|---|---|
| 0.50% | $9,237 | $9,153 | +$84 | $84 |
| 1.00% | $9,266 | $9,098 | +$168 | $168 |
| 1.50% | $9,285 | $9,033 | +$252 | $252 |
| 2.00% | $9,295 | $8,959 | +$336 | $336 |
| 2.25% | $9,297 | $8,919 | +$378 | $378 |

Assertions `assertGt(V_up, V_down)` and `assertApproxEqRel(V_up − V_down, closedForm, 0.1%)` passed at every level.

### Test 10: `test_theorem6_exitAsymmetry` (§3.9, App D.11)

The same position, taken a sqrt-price distance d above the upper bound and the same distance below the lower bound. Above the range it holds token1 only and below it token0 only. The last column is Corollary 6.1, `V_below = V_above (s_a − d)² / (s_a s_b)`.

| d, share of s | V_above (USD) | V_below (USD) | Closed form |
|---|---|---|---|
| 0.25% | $9,297 | $8,798 | $8,798 |
| 0.50% | $9,297 | $8,753 | $8,753 |
| 1.00% | $9,297 | $8,663 | $8,663 |
| 1.50% | $9,297 | $8,573 | $8,573 |
| 2.50% | $9,297 | $8,395 | $8,395 |

Assertions `assertGt(V_above, V_below)`, `assertApproxEqRel(V_below, closedForm, 0.1%)` and `V_below` strictly decreasing in d passed at every distance.

## Theorem 1 and §7.1, Base fork

Contract `GeometricResidualProof` (§6, App D.8). Four tests run the Theorem 1 scenarios against the WETH/USDC pool with tick spacing 100 on Base, through `vm.createSelectFork("base", FORK_BLOCK)`. They mint, swap, withdraw and re-mint through the unmodified Aerodrome Slipstream `NonfungiblePositionManager` (`0x827922686190790b37229fd06084350E74485b72`), with no mock pool and no helper contracts. The contract funds itself with WETH and USDC through `vm.deal`.

| Test | Captured | Checks |
|---|---|---|
| `test_theorem1_rangeChangeCreatesResidual` | 46 wei WETH + $329.36 USDC | A range change at a displaced price leaves a residual on the live contracts |
| `test_theorem1_noRangeChangeZeroResidual` | 468 wei WETH + 25 base units of USDC | A same-range rebalance leaves rounding dust only |
| `test_theorem1_largerPositionDonatesMore` | small $164.64, large $658.57 | A position four times larger leaves a residual 4.00 times larger |
| `test_section7_1_stockNfpmDoesNotAbsorbDust` | liquidity 981,276,404,164,067 → 981,276,404,164,066 | A stock position manager does not absorb another position's dust (§7.1) |

Fork residuals ($329) are smaller than mock-pool residuals ($2,061) because the fork tests move the pool price by a swap of 500 or 1,000 USDC, which on a deep WETH/USDC pool shifts the price by less than a tick. The mock test displaces by 200 ticks.

`test_section7_1_stockNfpmDoesNotAbsorbDust` checks the architectural precondition of §7.1. The mechanism requires a `dustBalance[depositor][token]` storage layout shared across a depositor's positions. A stock position manager has no such layout: every position is an independent NFT, and `mint()` consumes only the tokens it is given. The test creates two positions in the same range, leaves a residual through a range change on the first ($329.36 stranded), then rebalances the second into its own range and asserts that its liquidity does not grow. The decrease of 1 wei is rounding and is within `assertLe`.

## Theorems 5 and 6, Base fork

Contract `DirectionalExitForkProof` (App D.12 and D.13), on the same pool and at the same block as `GeometricResidualProof`.

Pool ordering: WETH (`0x4200…0006`) < USDC (`0x8335…2913`), so token0 is WETH and token1 is USDC. This is the ordering Theorems 5 and 6 are stated for.

### Test 11: `test_theorem5_directionalAsymmetryOnSlipstream`

| | Value |
|---|---|
| Position range | ±1,000 ticks |
| Up displacement | 2 ticks |
| `V_up` (USDC, 6 dp) | 4,414,837,879 ($4,414.84) |
| Down displacement | 1 tick |
| `V_down` (USDC, 6 dp) | 4,414,292,550 ($4,414.29) |
| **`V_up − V_down`** | 545,329 (**$0.55**) |

`V_up > V_down` on a volatile/stablecoin pair in V3 ordering, on the unmodified Slipstream contracts.

### Test 12: `test_theorem6_exitAsymmetryOnSlipstream`

| | Value |
|---|---|
| Position range | ±100 ticks (one tick spacing each side) |
| Ticks past upper bound | 101,429 |
| Ticks past lower bound | 1,161 |
| `V_above` (USDC, 6 dp) | 2,946,802,981 ($2,946.80), all USDC |
| `V_below` (USDC, 6 dp) | 2,597,775,879 ($2,597.78), all WETH at a depressed price |
| **`V_above − V_below`** | 349,027,102 (**$349.03**) |

`V_above > V_below` at exit, with the below-range position holding WETH at a strictly positive USD value.

Both tests use `vm.snapshot` and `vm.revertTo` to run the two directions from an identical pool state after the mint, so neither measurement depends on the other. Position values are computed from on-chain `positions(tokenId)` and the current `slot0().sqrtPriceX96` by the standard V3 amount-for-liquidity formulas, with token0 (WETH) valued at the pool's current price and token1 (USDC) at face value, with no off-chain oracle.

## Notes

- `GeometricResidualProofClean` and `ZeroSwapExtinctionProof` use `MockCLPool`, which approximates `sqrtPriceX96` linearly around tick 73,135. It shows the residual at the right order of magnitude and is not accurate to the last significant figure.
- `NewTheoremsProof` uses `MockCLPoolV2`, with the exact V3 `TickMath` constants taken verbatim from Uniswap V3 core.
- The mock pools carry no decimal offset between the tokens. Token0 is valued at the pool's raw price, `sqrtPriceX96² / 2¹⁹²`, through `_valueAtSqrtPrice` in `test/helpers/MockPositionTestBase.sol`.
- `GeometricResidualProof` runs against an unmodified Aerodrome Slipstream pool through `vm.createSelectFork`. It is the evidence for the statement in §6 that six tests run against unmodified Slipstream contracts.
- Absorption from a shared dust pool is not tested on the mock pool, which would need shared liquidity and fee accounting. The fork test `test_section7_1_stockNfpmDoesNotAbsorbDust` checks the converse, that a stock position manager absorbs nothing.
- To run against a different Base block, change `FORK_BLOCK` in `GeometricResidualProof.t.sol` and `BASE_BLOCK_PIN` in `DirectionalExitForkProof.t.sol`. The qualitative results hold at every block and only the captured values change.
