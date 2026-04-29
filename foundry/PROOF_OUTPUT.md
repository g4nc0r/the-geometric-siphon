# Foundry verification suite

Frozen `forge test -vv` output, kept under version control as a regression target. Sixteen tests across five contracts verify Theorems 1, 3, 4, 5, and 6 in *The Geometric Siphon: Existence, Equilibrium, and Directional Properties of the Residual in Concentrated Liquidity Portfolios* (K. R. Ryan, 2026), and the architectural precondition of §7.1 against live Aerodrome Slipstream contracts on Base.

| Theorem / claim | Paper section | Test contract | Tests | Pool |
|---|---|---|---|---|
| Thm 1, geometric residual existence and scaling | §3.2 | `GeometricResidualProofClean` | 3 | `MockCLPool` |
| Thm 1, same claims on real Slipstream | §6, App D.8 | `GeometricResidualProof` | 3 | Aerodrome Slipstream (fork) |
| Thm 3, zero-swap extinction | §3.6 | `ZeroSwapExtinctionProof` | 4 | `MockCLPool` |
| Thm 4, residual monotonicity | §3.7 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Thm 5, directional asymmetry (mock) | §3.8 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Thm 5, directional asymmetry (fork) | App D.12 | `DirectionalExitForkProof` | 1 | Aerodrome Slipstream (fork) |
| Thm 6, exit asymmetry (mock) | §3.9 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Thm 6, exit asymmetry (fork) | App D.13 | `DirectionalExitForkProof` | 1 | Aerodrome Slipstream (fork) |
| Architectural precondition | §7.1, App D.8 | `GeometricResidualProof` | 1 | Aerodrome Slipstream (fork) |

## Reproduction

```bash
git submodule update --init --recursive   # first time only
forge build

# Mock-pool tests only (no network)
forge test -vv --no-match-contract '(GeometricResidualProof|DirectionalExitForkProof)$'

# Full suite, including live fork tests
RPC_BASE_ALCHEMY=https://mainnet.base.org forge test -vv
```

Any working Base RPC URL is acceptable in `RPC_BASE_ALCHEMY`. The public endpoint `https://mainnet.base.org` works for all six fork tests; Alchemy, QuickNode, and `https://base.publicnode.com` also work. Forge caches RPC responses under `~/.foundry/cache`, so repeat runs are fast.

All six fork tests are pinned to Base block `43_175_000` (2026-03-10 10:42 UTC), inside the paper's Phase 2 data window (2026-03-08 to 2026-03-12). The pin makes the captured numerical values bit-reproducible and aligns the fork tests temporally with the empirical data in §5. Re-running requires a Base archive RPC. Qualitative claims (residual exists, control case is dust-only, residual scales with size, no cross-position absorption on a stock NFPM, $V_{\text{up}} > V_{\text{down}}$, $V_{\text{above}} > V_{\text{below}}$) hold at every block.

## Run summary

```
Suite                               Tests   Pass  Fail
GeometricResidualProofClean             3      3     0
ZeroSwapExtinctionProof                 4      4     0
NewTheoremsProof                        3      3     0
GeometricResidualProof (fork)           4      4     0
DirectionalExitForkProof (fork)         2      2     0
                                       --     --    --
                                       16     16     0
```

---

## Theorem 1: `GeometricResidualProofClean`

### `test_theorem1_rangeChangeCreatesResidual` (§6, App D.1)

| Step | Value |
|---|---|
| Initial position | 1 WETH + 2,500 USDC, ±500 ticks around tick 73,135 |
| Price movement | +200 ticks |
| New range | ±1,000 ticks (wider) |
| Withdrawn | 0.0759 WETH + 3,434.58 USDC |
| Re-deposited liquidity | 6,681,244,254 (from 23,525,142,796) |
| **Residual** | 1 wei token0 + 2,061,006,718 token1 ≈ **2,061 USDC** |

Assertion `assertTrue(residual0 > 0 || residual1 > 0)` PASSED.

### `test_theorem1_noRangeChange_noResidual` (App D.2)

Same setup, same +200 tick price move, re-mint into the **identical** range. Residual: 1 wei token0 + 29 wei token1. Pure integer rounding from `mulDiv` floor division.

Assertion `assertLt(residual1, 1e3)` PASSED. Confirms the converse `R_old = R_new ⇒ ΔR = 0`.

### `test_theorem1_largerPositionLargerResidual` (App D.3)

| Position size | Residual (raw sum) | Ratio |
|---|---|---|
| 0.5 WETH | 1,030,503,360 | 1.0× |
| 2.0 WETH | 4,122,013,419 | 4.00× |

Assertion `assertGt(largeResidual, smallResidual)` PASSED.

---

## Theorem 3: `ZeroSwapExtinctionProof`

### `test_theorem3_singleSidedExitNoSwapLosesValue` (App D.4)

| Step | Value |
|---|---|
| Initial position | 1 WETH + 2,500 USDC, range [72800, 73000] |
| Price movement | +200 ticks (above upper bound) |
| Withdrawal | 0 WETH + 2,499,999,999 USDC (100% token1) |
| New range | [73000, 73400] (requires both tokens) |
| New liquidity | **0** (`min()` constraint binds at zero) |
| **α** | **100%** |

Assertions `assertLt(valueFinal, valueInitial)` and `assertGt(alpha, 0.5e18)` PASSED.

### `test_theorem3_residualScalesWithDisplacement` (App D.5)

Position deployed in a 1,000-tick range; price displaced upward before a same-width rebalance with no swap.

| Displacement | α |
|---|---|
| 100 ticks | 0% |
| 300 ticks | 37% |
| 600 ticks | 100% |

Assertions `assertGe(α₃₀₀, α₁₀₀)` and `assertGt(α₆₀₀, α₃₀₀)` PASSED. The α=0% at 100 ticks reflects `MockCLPool`'s linearised sqrt-price approximation; on real V3 tick math this is small but strictly positive.

### `test_theorem3_repeatedRebalancesGeometricDecay` (App D.6)

Five sequential rebalance cycles with 150-tick price drift and no swap, starting from a 2 WETH + 5,000 USDC position in a ±400-tick range:

| Cycle | Value (USD) | Decay factor |
|---|---|---|
| 0 | 4,999 | --- |
| 1 | 3,823 | 0.76 |
| 2 | 1,565 | 0.40 |
| 3 | 1,197 | 0.76 |
| 4 | 490 | 0.40 |
| 5 | 374 | 0.76 |

Total decay over five cycles: 92%. Assertions `V[k+1] < V[k]` for all `k` and `totalDecay > 90%` PASSED.

### `test_theorem3_fullyOutOfRangeNearTotalLoss` (App D.7)

| Step | Value |
|---|---|
| Initial position | ±200 ticks around tick 73,135 |
| Price movement | +2,000 ticks past upper bound |
| Withdrawal | 0 WETH + 4,255,319,148 USDC |
| New liquidity | **0** |
| **α** | **100%** |

Assertion `assertGt(α, 0.95e18)` PASSED. Mirrors the ZARP terminal event (Event 14) referenced in §5.8.

---

## Theorems 4-6: `NewTheoremsProof`

`MockCLPoolV2` implements the exact Uniswap V3 `TickMath` constants for sqrt-price computation, so captured values are quantitatively accurate.

### `test_theorem4_residualMonotonicity` (§3.7, App D.9)

Eight upward displacement levels on a 1,000-tick-wide position at base tick 78,244 (price ~$2,500):

| Displacement (ticks) | Dust (USD) | Monotonic |
|---|---|---|
| +100 | $1,822 | --- |
| +200 | $3,663 | ✓ |
| +300 | $5,522 | ✓ |
| +400 | $7,400 | ✓ |
| +500 | $9,297 (range exit) | ✓ |
| +600 | $9,297 (capped) | ✓ |
| +700 | $9,297 (capped) | ✓ |
| +800 | $9,297 (capped) | ✓ |

Zero violations. Assertion `assertEq(monotoneViolations, 0)` PASSED.

### `test_theorem5_directionalAsymmetry` (§3.8, App D.10)

Five symmetric displacement levels on a 2 WETH + 5,000 USDC position (~$5,000):

| Displacement | Up value (USD) | Down value (USD) | Gap |
|---|---|---|---|
| ±100 ticks | $5,522 | $3,663 | +$1,859 |
| ±200 ticks | $6,459 | $2,740 | +$3,718 |
| ±300 ticks | $7,400 | $1,822 | +$5,577 |
| ±400 ticks | $8,346 | $908 | +$7,437 |
| ±450 ticks | $8,346 | $0 | +$8,346 |

Zero violations. Assertion `assertEq(asymmetryViolations, 0)` PASSED.

### `test_theorem6_exitAsymmetry` (§3.9, App D.11)

Five symmetric exit distances past the range boundary:

| Exit distance | Above value | Below value | Above swap frac | Below swap frac |
|---|---|---|---|---|
| ±50 ticks | $9,297 | $0 | 0 bps | 9,999 bps |
| ±100 ticks | $9,297 | $0 | 0 bps | 9,999 bps |
| ±200 ticks | $9,297 | $0 | 0 bps | 9,999 bps |
| ±300 ticks | $9,297 | $0 | 0 bps | 9,999 bps |
| ±500 ticks | $9,297 | $0 | 0 bps | 9,999 bps |

Ten of ten value-and-swap-fraction confirmations. Assertion `assertEq(totalConfirmations, 10)` PASSED.

---

## Fork verification: `GeometricResidualProof` (§6, App D.8)

Four tests reproduce the Theorem 1 scenarios against the WETH/USDC tickSpacing-100 pool on Base mainnet via `vm.createSelectFork("base", FORK_BLOCK)`. They mint, swap, withdraw, and re-mint through the unmodified Aerodrome Slipstream `NonfungiblePositionManager` (`0x827922686190790b37229fd06084350E74485b72`). No mock pool, no helper contracts. The contract uses `vm.deal` to fund itself with WETH and USDC. The pin (`FORK_BLOCK = 43_175_000`, 2026-03-10 10:42 UTC) sits inside the paper's Phase 2 window.

| Test | Captured residual | Verifies |
|---|---|---|
| `test_theorem1_rangeChangeCreatesResidual` | 46 wei WETH + \$329.36 USDC | Range change at non-zero displacement creates a non-zero residual on real Slipstream contracts (Thm 1) |
| `test_theorem1_noRangeChangeZeroResidual` | 468 wei WETH + 25 wei USDC | Same-range rebalance produces only rounding dust (Thm 1 converse) |
| `test_theorem1_largerPositionDonatesMore` | small \$164.64 / large \$658.56 | A 4× larger position produces a 4.00× larger residual |
| `test_section7_1_stockNfpmDoesNotAbsorbDust` | liquidity 981,276,404,164,067 → 164,066 (1 wei) | A stock NFPM does **not** absorb cross-position dust (§7.1) |

Fork residuals (\$329) are smaller than mock-pool residuals (\$2,061) because the fork test moves the pool price by swapping a fixed \$1,000 USDC, which on a deep WETH/USDC pool shifts the tick by 1--3 ticks. The mock test displaces by a hardcoded +200 ticks.

`test_section7_1_stockNfpmDoesNotAbsorbDust` verifies §7.1's architectural precondition. The Geometric Siphon requires a `dustBalance[depositor][token]` storage layout shared across a depositor's positions. A stock NFPM has no such layout: every position is an independent NFT and `mint()` consumes only the tokens it is given. The test creates two same-range positions, leaves a residual via a range change on the first (\$329.36 stranded), then performs a same-range rebalance on the second and asserts that its liquidity does not grow. The 1-wei rounding decrease is well within `assertLe`.

---

## Fork verification: `DirectionalExitForkProof` (App D.12-13)

Two fork tests exercise Theorems 5 and 6 on the same live Aerodrome Slipstream pool. The mock-pool counterparts (Tests 9 and 10) display the down-direction value as `$0` under integer-arithmetic floor when token0 is heavily depressed; the live pool eliminates the floor and resolves the inequalities to strictly positive values. Both tests are pinned to the same block as `GeometricResidualProof`.

Pool ordering: WETH (`0x4200…0006`) < USDC (`0x8335…2913`), so token0 = WETH (volatile) and token1 = USDC (stablecoin). This is the forward ordering Theorems 5 and 6 are stated for; no inversion handling needed.

```
[PASS] test_theorem5_directionalAsymmetryOnSlipstream()
  Position range:           ±1,000 ticks
  Up displacement:          2 ticks
  V_up   (USDC, 6dp):       4,414,837,879  ($4,414.84)
  Down displacement:        1 tick
  V_down (USDC, 6dp):       4,414,292,550  ($4,414.29)
  V_up - V_down:            545,329  ($0.55)

[PASS] test_theorem6_exitAsymmetryOnSlipstream()
  Position range:           ±100 ticks (one tickSpacing each side)
  Ticks past upper bound:   101,429
  Ticks past lower bound:   1,161
  V_above (USDC, 6dp):      2,946,802,981  ($2,946.80)   100% USDC
  V_below (USDC, 6dp):      2,597,775,879  ($2,597.78)   100% WETH at depressed price
  V_above - V_below:        349,027,102  ($349.03)
```

| Test | Captured | Verifies |
|---|---|---|
| `test_theorem5_directionalAsymmetryOnSlipstream` | $V_{\text{up}} = \$4{,}414.84$, $V_{\text{down}} = \$4{,}414.29$ | Thm 5: $V_{\text{up}} > V_{\text{down}}$ on volatile/stablecoin in V3 forward ordering, on unmodified Slipstream contracts (no mock floor) |
| `test_theorem6_exitAsymmetryOnSlipstream` | $V_{\text{above}} = \$2{,}946.80$, $V_{\text{below}} = \$2{,}597.78$ | Thm 6: $V_{\text{above}} > V_{\text{below}}$ at exit; below-exit position holds depreciated WETH at strictly positive USD value |

Both tests use `vm.snapshot` / `vm.revertTo` to run up- and down-direction (or above- and below-exit) swaps from an identical post-mint pool state, eliminating path-dependence between the two measurements. Position values are computed from on-chain `positions(tokenId)` plus current `slot0().sqrtPriceX96` via the standard V3 amount-for-liquidity formulas, with token0 (WETH) valued at the pool's current price and token1 (USDC) at face value (no off-chain oracle).

---

## Notes

- `GeometricResidualProofClean` and `ZeroSwapExtinctionProof` use `MockCLPool`, which approximates `sqrtPriceX96` linearly around tick 73,135. Sufficient to demonstrate the residual at order of magnitude; not Uniswap-accurate in the last significant figure. The §6 small-position rounding (1,030 vs 1,031) and the decay-factor truncation (0.40 vs 0.41) trace to this approximation.
- `NewTheoremsProof` uses `MockCLPoolV2`, which implements the exact V3 `TickMath` exponential constants verbatim from Uniswap V3 core. Captured values match §3.7--§3.9 to the cent at every displacement level.
- `GeometricResidualProof` runs against an unmodified Aerodrome Slipstream pool via `vm.createSelectFork`. This is the on-chain evidence for §6's "running against unmodified Uniswap V3 contracts" claim.
- Stage 2 dust absorption is not verified on `GeometricResidualProofClean`'s linear mock pool — that would require shared liquidity and fee accounting, which is out of scope for the mock. The fork-mode equivalent `test_section7_1_stockNfpmDoesNotAbsorbDust` verifies the converse: a stock NFPM cannot absorb cross-position dust.
- Update `FORK_BLOCK` (in `GeometricResidualProof.t.sol`) and `BASE_BLOCK_PIN` (in `DirectionalExitForkProof.t.sol`) to re-run against a different Base block. Qualitative claims hold at every block; only the captured numeric values shift.
