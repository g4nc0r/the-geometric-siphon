# Foundry verification suite

Foundry verification suite for the *Geometric Siphon* research line by K. R. Ryan. Section references in this README and in `PROOF_OUTPUT.md` correspond to the consolidated working manuscript at `papers/manuscript/`.

The suite is **16 tests across 5 contracts**, covering the six theorems and the architectural precondition. See `PROOF_OUTPUT.md` for the captured output and the test-to-section mapping.

## What the suite verifies

| Theorem / claim | Paper section | Test contract | Tests | Pool |
|---|---|---|---|---|
| Thm 1, geometric residual existence and scaling | §3.2 | `GeometricResidualProofClean` | 3 | `MockCLPool` |
| Thm 1, same claims on real Slipstream | §6, App D.8 | `GeometricResidualProof` | 3 | Aerodrome Slipstream (fork) |
| Thm 3, zero-swap extinction | §3.6 | `ZeroSwapExtinctionProof` | 4 | `MockCLPool` |
| Thm 4, residual monotonicity | §3.7 | `NewTheoremsProof` | 1 | `MockCLPoolV2` |
| Thm 5, directional asymmetry (mock + fork) | §3.8, App D.12 | `NewTheoremsProof` + `DirectionalExitForkProof` | 2 | `MockCLPoolV2` + Slipstream |
| Thm 6, exit asymmetry (mock + fork) | §3.9, App D.13 | `NewTheoremsProof` + `DirectionalExitForkProof` | 2 | `MockCLPoolV2` + Slipstream |
| Architectural precondition | §7.1, App D.8 | `GeometricResidualProof` | 1 | Aerodrome Slipstream (fork) |

## Running

```bash
git submodule update --init --recursive   # first time only

forge build

# Mock-pool tests only, no network access required (10 tests)
forge test -vv --no-match-contract '(GeometricResidualProof|DirectionalExitForkProof)$'

# Full suite, including the 6 live fork tests against Aerodrome Slipstream (16 tests)
RPC_BASE_ALCHEMY=https://mainnet.base.org forge test -vv

# Single test
forge test --match-test test_theorem1_rangeChangeCreatesResidual -vvv

# Gas report
forge test --gas-report
```

Any working Base RPC URL is acceptable in `RPC_BASE_ALCHEMY`. The public endpoint above supports Base archive queries. All six fork tests are pinned to Base block `43_175_000` (2026-03-10 10:42 UTC), inside the paper's Phase 2 data window. Both the qualitative claims and the captured numerical residuals are bit-reproducible at this pin.

## Architecture

- **`MockCLPool.sol`** implements the V3 amount equations as a minimal CL pool (`getAmountsForLiquidity`, `getLiquidityForAmounts`, `movePriceToTick`) with a linearised `getSqrtRatioAtTick`. Captured residuals are within ~1% of the figures reported in the paper. Used by `GeometricResidualProofClean` and `ZeroSwapExtinctionProof`.
- **`MockCLPoolV2.sol`** has the same surface but uses the exact Uniswap V3 `TickMath` exponential constants verbatim from `v3-core`. Captured values match §3.7--§3.9 to the cent. Used by `NewTheoremsProof`.
- **`test/GeometricResidualProof.t.sol`** runs against live Aerodrome Slipstream on Base via `vm.createSelectFork("base", FORK_BLOCK)`, calls the unmodified `NonfungiblePositionManager` (`0x827922686190790b37229fd06084350E74485b72`), funds itself via `vm.deal`, and exercises the same mint/swap/withdraw/re-mint sequence on real on-chain V3 geometry. Verifies Theorem 1 and §7.1's architectural precondition.
- **`test/DirectionalExitForkProof.t.sol`** verifies Theorems 5 and 6 on the same Slipstream pool, eliminating the integer-arithmetic floor that masks the strict inequalities in the mock-pool versions.

## Mathematical foundation

The geometric residual arises from the token-ratio mismatch between the old and new ranges (`R_old ≠ R_new`). For a position with liquidity `L` in range `[s_a, s_b]` at current sqrt price `s`, the value factor is

```
φ(s, s_a, s_b) = 2s − s²/s_b − s_a
```

and the closed-form (signed) residual fraction `ΔR/V` is

```
Case A, token1-binding:   ΔR/V = (s − s_a) · φ_new / [(s − s_a') · φ_old] − 1
Case B, token0-binding:   ΔR/V = (1/s − 1/s_b) · φ_new / [(1/s − 1/s_b') · φ_old] − 1
```

where primed variables refer to the new range. See §3 for the derivation and Theorem 1 for the equivalence `ΔR/V = 0 ⇔ R_old = R_new`. The empirical dust flow `D = ΔR − S` (after on-chain swap absorption) is what the reproduction scripts compute against.

## Layout

```
foundry/
├── src/
│   ├── MockCLPool.sol                       linear-tick CL pool (Theorems 1, 3)
│   └── MockCLPoolV2.sol                     exact V3 TickMath CL pool (Theorems 4-6)
├── test/
│   ├── GeometricResidualProofClean.t.sol    Theorem 1 (mock)
│   ├── GeometricResidualProof.t.sol         Theorem 1 + §7.1 precondition (fork)
│   ├── ZeroSwapExtinctionProof.t.sol        Theorem 3 (mock)
│   ├── NewTheoremsProof.t.sol               Theorems 4-6 (mock with exact tick math)
│   └── DirectionalExitForkProof.t.sol       Theorems 5-6 (fork, no integer floor)
├── lib/
│   └── forge-std/
├── foundry.toml
├── PROOF_OUTPUT.md
└── README.md
```

## Limitations

- **Stage 2 dust absorption is verified on the fork side, not the mock side.** Verifying it on a mock pool requires implementing shared liquidity and fee accounting. The mock-pool tests isolate Stage 1 (geometric creation). The fork-mode `test_stockNfpmDoesNotAbsorbDust` verifies the converse: a stock NFPM cannot absorb cross-position dust, which is the architectural precondition §7.1 cites.
- **`MockCLPool` uses linear tick math.** Order-of-magnitude correct, ≤1% off in the last digit. The fork tests and `MockCLPoolV2` are the references for quantitatively accurate values.
- **No fees, no slippage in the mock tests.** The mock suites isolate the geometric component; swap-fee and slippage frictions are orthogonal and analysed separately in the paper.
- **Fork tests are pinned to Base block `43_175_000`** (2026-03-10 10:42 UTC, mid-Phase 2). Captured numerical residuals are bit-reproducible at this pin. Re-running requires a Base archive RPC. The qualitative claims (existence, scaling, control case, `V_up > V_down`, `V_above > V_below`) hold at every block regardless.

## Dependencies

- Foundry (`forge ≥ 1.5`)
- Solidity 0.8.26
- `forge-std` (cloned into `lib/forge-std`)

## Licence

MIT.
