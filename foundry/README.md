# Foundry verification suite

[![Foundry tests](https://github.com/g4nc0r/the-geometric-siphon/actions/workflows/foundry.yml/badge.svg)](https://github.com/g4nc0r/the-geometric-siphon/actions/workflows/foundry.yml)
![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity&logoColor=white)
![Tests](https://img.shields.io/badge/tests-16-b7410e)
![Fork pin](https://img.shields.io/badge/Base_fork-block_43175000-0052ff)

Part of [The Geometric Siphon](../README.md). The proofs in real arithmetic are in [`../lean/`](../lean/).

Sixteen tests across five contracts check Theorems 1, 3, 4, 5 and 6 of the paper, and the architectural precondition of §7.1, in the integer arithmetic of a V3 pool. Ten run on mock pools with no network access. Six run against the unmodified Aerodrome Slipstream contracts on a fork of Base. The captured output is in [`PROOF_OUTPUT.md`](./PROOF_OUTPUT.md) and is the regression target.

Section and appendix numbers refer to the November 2026 revision of the paper.

## Coverage

| Result | Paper | Mock pool | Base fork |
|---|---|---|---|
| Theorem 1, geometric residual | §3.2 | 3 tests | 3 tests |
| Theorem 3, zero-swap extinction | §3.6 | 4 tests | |
| Theorem 4, residual monotonicity, upward displacement | §3.7 | 1 test | |
| Theorem 5, directional asymmetry | §3.8 | 1 test | 1 test |
| Theorem 6, exit asymmetry | §3.9 | 1 test | 1 test |
| Architectural precondition | §7.1 | | 1 test |

Not covered here:

- Theorem 2 is a statement in expectation over many rebalances. It is proved in Lean in a declared discrete model.
- Corollary 4.1, Theorem 4 for a downward displacement, is proved in Lean. The Theorem 4 test displaces the price upwards only.
- Propositions 7 to 12 concern the internal swap and the shared balance. Their proofs are in Lean, except Proposition 8, which is first order.
- Absorption from a shared dust pool is not tested. A mock would need shared liquidity and fee accounting. The fork test for §7.1 checks the converse, that a stock position manager with no shared balance absorbs nothing.

## Tests

The first column is the test number used in Appendix D of the paper.

| Paper | Test | Contract | Pool | Checks |
|---|---|---|---|---|
| Test 1 | `test_theorem1_rangeChangeCreatesResidual` | `GeometricResidualProofClean` | `MockCLPool` | A range change at a displaced price leaves a residual |
| Test 2 | `test_theorem1_noRangeChange_noResidual` | `GeometricResidualProofClean` | `MockCLPool` | The same range leaves rounding dust only |
| Test 3 | `test_theorem1_largerPositionLargerResidual` | `GeometricResidualProofClean` | `MockCLPool` | The residual scales linearly with position size |
| Test 4 | `test_theorem3_singleSidedExitNoSwapLosesValue` | `ZeroSwapExtinctionProof` | `MockCLPool` | Part (i): a single-sided exit with no swap loses value |
| Test 5 | `test_theorem3_residualScalesWithDisplacement` | `ZeroSwapExtinctionProof` | `MockCLPool` | Part (ii): the residual fraction grows with displacement |
| Test 6 | `test_theorem3_repeatedRebalancesGeometricDecay` | `ZeroSwapExtinctionProof` | `MockCLPool` | Part (iii): repeated zero-swap rebalances decay geometrically |
| Test 7 | `test_theorem3_fullyOutOfRangeNearTotalLoss` | `ZeroSwapExtinctionProof` | `MockCLPool` | A deep out-of-range rebalance loses nearly everything |
| Test 8 | `test_theorem4_residualMonotonicity` | `NewTheoremsProof` | `MockCLPoolV2` | The residual rises strictly with upward displacement |
| Test 9 | `test_theorem5_directionalAsymmetry` | `NewTheoremsProof` | `MockCLPoolV2` | `V(s+δ) > V(s−δ)`, and the gap equals `4Lδ(1 − s/s_b)` |
| Test 10 | `test_theorem6_exitAsymmetry` | `NewTheoremsProof` | `MockCLPoolV2` | `V_above > V_below`, and the ratio equals Corollary 6.1 |
| D.8 | `test_theorem1_rangeChangeCreatesResidual` | `GeometricResidualProof` | Slipstream fork | Test 1 on the live pool |
| D.8 | `test_theorem1_noRangeChangeZeroResidual` | `GeometricResidualProof` | Slipstream fork | Test 2 on the live pool |
| D.8 | `test_theorem1_largerPositionDonatesMore` | `GeometricResidualProof` | Slipstream fork | Test 3 on the live pool |
| D.8 | `test_section7_1_stockNfpmDoesNotAbsorbDust` | `GeometricResidualProof` | Slipstream fork | A stock position manager does not absorb another position's dust |
| Test 11 | `test_theorem5_directionalAsymmetryOnSlipstream` | `DirectionalExitForkProof` | Slipstream fork | Test 9 on the live pool |
| Test 12 | `test_theorem6_exitAsymmetryOnSlipstream` | `DirectionalExitForkProof` | Slipstream fork | Test 10 on the live pool |

## Running

```bash
git submodule update --init --recursive   # first time only
forge build

# Mock-pool tests, no network access (10 tests)
forge test -vv --no-match-contract '(GeometricResidualProof|DirectionalExitForkProof)$'

# Full suite, with the 6 fork tests (16 tests)
RPC_BASE_ALCHEMY=https://mainnet.base.org forge test -vv

# A single test
forge test --match-test test_theorem4_residualMonotonicity -vvv
```

Any Base RPC with archive support works in `RPC_BASE_ALCHEMY`. The six fork tests are pinned to Base block `43_175_000` (10 March 2026, 10:42 UTC), inside the paper's Phase 2 data window, so the captured residuals are reproducible. The continuous-integration workflow runs the ten mock-pool tests.

## Pools

| Pool | Tick arithmetic | Used by | Agreement with the paper |
|---|---|---|---|
| `src/MockCLPool.sol` | Linearised around tick 73,135 | Tests 1 to 7 | Within 1% of the reported figures |
| `src/MockCLPoolV2.sol` | Exact V3 `TickMath` constants, verbatim from `v3-core` | Tests 8 to 10 | To the cent |
| Aerodrome Slipstream WETH/USDC, Base | The deployed contracts | Fork tests | Captured at the pinned block |

Both mock pools implement the V3 amount equations as a minimal pool (`getAmountsForLiquidity`, `getLiquidityForAmounts`, `movePriceToTick`). They charge no fees and model no slippage, so they isolate the geometric residual.

The fork tests call the unmodified `NonfungiblePositionManager` at `0x827922686190790b37229fd06084350E74485b72` through `vm.createSelectFork("base", FORK_BLOCK)`, fund themselves with `vm.deal`, and mint, swap to move the price, withdraw and re-mint on the live pool. Fork residuals are smaller than mock residuals because the fork tests move the price by a swap of 500 or 1,000 USDC, which shifts it by less than a tick, where the mock tests displace by 200 ticks.

The mock pools carry no decimal offset between the tokens. The mock tests value token0 at the pool's raw price, `sqrtPriceX96² / 2¹⁹²`, so every value they report is the whole position in token1 units. Tests 9 and 10 displace the sqrt price by equal amounts in each direction and check the inequality and its closed form.

## The claim under test

A position with liquidity `L` in range `[s_a, s_b]` at sqrt price `s` has value `L φ` in token1 units, with

```
φ(s, s_a, s_b) = 2s − s²/s_b − s_a
```

A rebalance into `[s_a', s_b']` with no swap and no shared balance mints

```
L_new = min( x / (1/s − 1/s_b'),  y / (s − s_a') )
```

from the withdrawn amounts `x`, `y`. Theorem 1 gives the residual as a fraction of value,

```
ΔR / V = −(ω' − ω) / ω'  ≤  0
```

where `ω` is the fraction of the withdrawn value held in the binding token and `ω'` the fraction the new range requires in it. The residual is zero exactly when the two ranges require the same token ratio at the current price. The tests compute `L_new` in pool arithmetic and compare the value redeployed with the value withdrawn.

## Layout

```
foundry/
├── src/
│   ├── MockCLPool.sol                       linearised tick arithmetic (Theorems 1, 3)
│   └── MockCLPoolV2.sol                     exact V3 TickMath (Theorems 4 to 6)
├── test/
│   ├── GeometricResidualProofClean.t.sol    Theorem 1, mock
│   ├── ZeroSwapExtinctionProof.t.sol        Theorem 3, mock
│   ├── NewTheoremsProof.t.sol               Theorems 4 to 6, mock
│   ├── GeometricResidualProof.t.sol         Theorem 1 and §7.1, fork
│   ├── DirectionalExitForkProof.t.sol       Theorems 5 and 6, fork
│   ├── helpers/
│   └── interfaces/
├── lib/forge-std/                           submodule
├── foundry.toml
├── PROOF_OUTPUT.md                          captured forge output, by test
└── README.md
```

## Requirements

- Foundry, `forge` 1.5 or later
- Solidity 0.8.26, set in `foundry.toml`
- `forge-std`, as a git submodule under `lib/`

## Licence

MIT. See [`../LICENSE`](../LICENSE).
