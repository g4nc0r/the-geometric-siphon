# Foundry verification suite

Unified Foundry project backing both papers in the *Geometric Siphon* line:

- *The Geometric Siphon: Emergent Capital Reallocation in Concentrated Liquidity Portfolios* (Ryan, SSRN [6374838](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6374838))
- *The Geometric Siphon II: Directional Properties* (Ryan, SSRN [6481498](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6481498))

The suite is **15 tests across 4 contracts**, mapping 1:1 to the theorems and to Paper I §6 / Paper II §2 reference tables. See `PROOF_OUTPUT.md` for the captured output and the test-to-paper-section mapping.

## What the suite verifies

| Theorem / claim | Source | Test contract | Tests | Pool |
|---|---|---|---|---|
| Theorem 1, geometric residual existence and scaling | Paper I §3.2 | `GeometricResidualProofClean` | 3 | `MockCLPool` |
| Theorem 1, same claims, against live Aerodrome Slipstream on Base | Paper I §6 | `GeometricResidualProof` | 4 | fork |
| Theorem 3, zero-swap extinction | Paper I §3.6 | `ZeroSwapExtinctionProof` | 4 | `MockCLPool` |
| Theorem 4, residual monotonicity | Paper II §2.1 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Theorem 5, directional asymmetry | Paper II §2.2 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Theorem 6, exit asymmetry | Paper II §2.3 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Architectural precondition (no cross-position absorption on a stock NFPM) | Paper I §7.1 | `GeometricResidualProof` | 1 | fork |

## Running

```bash
git submodule update --init --recursive   # first time only

forge build

# Mock-pool tests only, no network access required (10 tests)
forge test -vv --no-match-contract 'GeometricResidualProof$'

# Full suite, including the 5 live fork tests against Aerodrome Slipstream (15 tests)
RPC_BASE_ALCHEMY=https://mainnet.base.org forge test -vv

# Single test
forge test --match-test test_rangeChangeCreatesResidual -vvv

# Gas report
forge test --gas-report
```

Any working Base RPC URL is acceptable in `RPC_BASE_ALCHEMY`. The official public endpoint above is sufficient. The fork tests do not pin a specific block number, so they run against `latest`; numerical residual values shift between runs but the qualitative claims (existence, scaling, control case) hold deterministically.

## Architecture

- **`MockCLPool.sol`** implements the core Uniswap V3 amount equations as a minimal concentrated-liquidity pool (`getAmountsForLiquidity`, `getLiquidityForAmounts`, `movePriceToTick`) with a *linearised* `getSqrtRatioAtTick`. Sufficient to demonstrate the residual to within ≤1% rounding artefacts in the values reported in Paper I §6.3 and §6.7. Used by `GeometricResidualProofClean` and `ZeroSwapExtinctionProof`.
- **`MockCLPoolV2.sol`** has the same pool surface but uses the *exact* Uniswap V3 `TickMath` exponential constants verbatim from `v3-core`. The right reference for any quantitative claim. Used by `NewTheoremsProof`, where its captured values match Paper II §2 to the cent at every displacement level.
- **`test/GeometricResidualProof.t.sol`** is the fork-mode equivalent of the headline mock proof. Uses `vm.createSelectFork("base")` to attach to live Aerodrome Slipstream on Base, calls the unmodified `NonfungiblePositionManager` (`0x827922686190790b37229fd06084350E74485b72`), funds itself via `vm.deal`, and exercises the same mint/swap/withdraw/re-mint sequence on real on-chain V3 geometry. Provides the strongest evidence for Paper I §6's "running against unmodified Uniswap V3 contracts" claim and additionally verifies Paper I §7.1's architectural precondition (no cross-position dust absorption on a stock NFPM).

## Mathematical foundation

The geometric residual arises from the value-factor mismatch between the old and new ranges. For a position with liquidity `L` in range `[s_a, s_b]` at current sqrt price `s`, the value factor is

```
φ(s, s_a, s_b) = 2s − s²/s_b − s_a
```

and the closed-form residual fraction `D/V` is

```
Case A, token1-binding:   D/V = (s − s_a) · φ_new / [(s − s_a') · φ_old] − 1
Case B, token0-binding:   D/V = (1/s − 1/s_b) · φ_new / [(1/s − 1/s_b') · φ_old] − 1
```

where primed variables refer to the new range. See Paper I §3 for the derivation and Theorem 1 for the equivalence `D/V = 0 ⇔ R_old = R_new`.

## Layout

```
foundry/
├── src/
│   ├── MockCLPool.sol           linear-tick CL pool (Theorems 1, 3)
│   └── MockCLPoolV2.sol         exact V3 TickMath CL pool (Theorems 4-6)
├── test/
│   ├── GeometricResidualProofClean.t.sol  Theorem 1 verification (mock)
│   ├── GeometricResidualProof.t.sol       Theorem 1 verification + §7.1 precondition (fork)
│   ├── ZeroSwapExtinctionProof.t.sol      Theorem 3 verification (mock)
│   └── NewTheoremsProof.t.sol             Theorems 4-6 verification (mock with exact tick math)
├── lib/
│   └── forge-std/
├── foundry.toml
├── PROOF_OUTPUT.md
└── README.md
```

## Limitations

- **Stage 2 dust absorption (mock-side) is intentionally out of scope.** Verifying it on a mock pool requires implementing shared liquidity and fee accounting; the mock-pool tests isolate Stage 1 (geometric creation) only. The fork-mode `test_stockNfpmDoesNotAbsorbDust` instead verifies the converse: a *stock* NFPM cannot absorb cross-position dust at all, which is exactly the architectural precondition Paper I §7.1 cites.
- **`MockCLPool` uses linear tick math.** Order-of-magnitude correct, ≤1% off in the last digit. The fork test and `MockCLPoolV2` are the references for quantitatively accurate values.
- **No fees, no slippage in the mock tests.** The mock suites isolate the geometric component; swap-fee and slippage frictions are orthogonal and analysed separately in the paper.
- **Fork tests do not pin a block.** Numerical residuals shift between runs as the live pool state changes. Pin via `vm.createSelectFork("base", BLOCK_NUMBER)` if bit-for-bit reproducibility matters.

## Dependencies

- Foundry (`forge ≥ 1.5`)
- Solidity 0.8.26
- `forge-std` (cloned into `lib/forge-std`)

## Licence

MIT.
