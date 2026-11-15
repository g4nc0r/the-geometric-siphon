# Lean formalisation

[![Lean build](https://github.com/g4nc0r/the-geometric-siphon/actions/workflows/lean.yml/badge.svg)](https://github.com/g4nc0r/the-geometric-siphon/actions/workflows/lean.yml)
![Lean](https://img.shields.io/badge/Lean-4.32.2-5e81ac)
![mathlib](https://img.shields.io/badge/mathlib-pinned-5e81ac)
![Axiom checks](https://img.shields.io/badge/axiom_checks-92-2e7d32)
![sorry](https://img.shields.io/badge/sorry-none-2e7d32)

Part of [The Geometric Siphon](../README.md). The fixed-point checks are in
[`../foundry/`](../foundry/).

Machine-checked proofs of the theorems, propositions and corollaries of
*The Geometric Siphon*, written in Lean 4 against mathlib. The scope is the
idealised real-arithmetic model of the paper. The Foundry suite remains the
check against fixed-point pool arithmetic.

The library root is `GeometricSiphon.lean`. The shared definitions (φ, R and
L_new of paper §3.1) live in `GeometricSiphon/Defs.lean`, which every other
file imports. File names follow the mathlib convention of descriptive content
names; the mapping to the paper's numbering is recorded below and in each
file's doc comments. All statements refer to the November 2026 revision of
the paper.

| Paper result | Section | Files |
|---|---|---|
| [Theorem 1](#theorem-1-geometric-residual-32), Corollaries 1.1, 1.2 | §3.2 | `GeometricResidual`, `ResidualShare` |
| [Theorem 2](#theorem-2-single-pool-convergence-34), Corollaries 2.1, 2.2 | §3.4 | `Convergence`, `ConvergenceDiscrete`, `ConvergenceVariance` |
| [Theorem 3](#theorem-3-zero-swap-extinction-36), Corollary 3.1 | §3.6 | `Extinction`, `SharedBalance` |
| [Theorem 4](#theorem-4-residual-monotonicity-37), Corollary 4.1 | §3.7 | `Monotonicity`, `MonotonicityDown`, `Excursion` |
| [Theorems 5 and 6](#theorems-5-and-6-directional-and-exit-asymmetry-38-39) | §3.8, §3.9 | `DirectionalExit` |
| [Proposition 7](#proposition-7-partial-swap-extinction-310), Corollary 7.1 | §3.10 | `PartialSwap` |
| Proposition 8, Corollary 8.1 | §3.10 | [not formalised](#scope-what-is-not-formalised) |
| [Proposition 9](#proposition-9-displacement-identity-311), Corollaries 9.1, 9.2 | §3.11 | `ResidualShare` |
| [Proposition 10](#proposition-10-retained-excursion-311) | §3.11 | `Excursion` |
| [Proposition 11](#proposition-11-netting-312), Corollary 11.1 | §3.12 | `SharedBalance` |
| [Proposition 12](#proposition-12-neutral-accounting-312), Corollary 12.1 | §3.12 | `SharedBalance` |

## Coverage

### Theorem 1 (Geometric residual), §3.2

`GeometricSiphon/GeometricResidual.lean` - the vanishing condition:

- `geometric_residual` - for a rebalance between ranges both strictly
  containing the current price, isolated case,
  `ΔR = 0 ↔ R(s, sa, sb) = R(s, sa', sb')`.
- `residual_nonpos` - `ΔR ≤ 0` unconditionally: the isolated-case rebalance
  never creates value.
- `residual_zero_iff`, `vnew_le_vold` - the abstract core.

`GeometricSiphon/ResidualShare.lean` - the value-fraction form and the two
corollaries:

- `frac0`, `frac1` - the fractions of a position's value held in token0 and
  token1; `frac0_add_frac1`, `frac0_eq_ratio`, `frac1_eq_ratio` tie them to
  the token ratio (`R s² / (1 + R s²)` and `1 / (1 + R s²)`).
- `geometric_residual_share_token1`, `geometric_residual_share_token0` - the
  theorem as stated in the paper, `ΔR / V = -(ω' - ω) / ω'` with `ω ≤ ω'`,
  for token1 missing (`R_old ≥ R_new`) and token0 missing (`R_old ≤ R_new`).
- `mint_share_token0`, `mint_share_token1` - the abstract core, for
  arbitrary holdings minted into a range.
- `zero_residual_locus` - Corollary 1.1: the new ranges with zero residual
  are those with `1 / sb' = 1 / s - R_old (s - sa')`.
- `round_trip_from_low`, `round_trip_from_high` - Corollary 1.2: a rebalance
  to another range and back at the same price leaves the fraction
  `ω_A (1 - ω_B) / (ω_B (1 - ω_A))` deployed, from either starting range.

### Theorem 2 (Single-pool convergence), §3.4

`GeometricSiphon/Convergence.lean` - linearised layer:

- `pairwise_gap_decay`, `pairwise_gap_decay_abs` - the deterministic core
  of the appendix's spectral argument: under the linearised dynamics
  `η̇ = -c η - S(t)` with common coupling term, pairwise differences decay
  at exactly rate c, independent of N.
- `equal_growth_iff_equal_value` - the equilibrium characterisation in the
  proof of the theorem.

`GeometricSiphon/ConvergenceDiscrete.lean` - discrete-model layer. The file
declares a per-event model of the shared-balance process (uniform choice of
rebalancer; donation proportional to position value; absorption drawn from
the pool independently of the chosen position's identity; total value
conserved, `stepState_total`) and proves the convergence claim in it with
no linearisation:

- `expected_gap_decay` - `E[V_i(t) - V_j(t)] = (1 - α/N)^t (V_i(0) - V_j(0))`
  for an arbitrary absorption function; the absorption term cancels from
  pairwise differences in expectation (`sum_step_gap`).
- `expected_gap_decay_exp_bound` - Corollary 2.1: the exponential envelope
  `|E[gap]| ≤ |gap(0)| exp(-αt/N)`; with events arriving at rate N per unit
  time this is rate-c decay independent of N.

`GeometricSiphon/ConvergenceVariance.lean` - Corollary 2.2 (Dispersion), in
the same discrete model:

- `sum_step_gap_sq` - the one-step second-moment identity,
  `E[d'²] = q d² + (2/N) g²` with `q = 1 - (2α - α²/2)/N`, in summed form.
- `expected_gap_sq_bound`, `expected_gap_sq_bound_closed` - for `g² ≤ γ²`,
  `E[d(t)²] ≤ q^t d(0)² + γ² / (α (1 - α/4)) · (1 - q^t)`.

### Theorem 3 (Zero-swap extinction), §3.6

`GeometricSiphon/Extinction.lean`:

- `above_exit_isolated_mint_zero` - part (i), isolated case: single-sided
  withdrawal mints zero liquidity, total loss.
- `vK_le_mean_bound` - part (iii), the AM-GM bound `V_K ≤ V_0 (1 - ᾱ_K)^K`
  (with `mean_form_eq` for the paper's notation); `vK_le_min_bound` - the
  loose uniform bound.
- `extinction_time` - part (iv): any `K ≥ ln(V_0/ε)/ln(1/(1-ᾱ))` drives the
  envelope below ε.

`GeometricSiphon/SharedBalance.lean` - Corollary 3.1:

- `recovery_needs_dust`, `isolated_no_gain` - a mint that deploys at least
  the withdrawn value needs dust covering the position's shortfall of each
  token, and with no dust it never deploys more.

### Theorem 4 (Residual monotonicity), §3.7

`GeometricSiphon/Monotonicity.lean` - upward displacement:

- `deltaRclosed_eq_deltaR` - the appendix simplification of the closed form,
  normalised to `ΔR(δ) = L δ (2 s̄ + w/2 + δ) / (s̄ + w/2)`.
- `deltaR_strictMono` - strict monotonicity of the normal form;
  `deltaR_zero`, `deltaR_up_boundary` (`= L w`) give the endpoint values.
- `token0_binds`, `deltaRclosed_eq_value_loss` - the closed form is exactly
  `V_old - V_new` under Theorem 1's mint minimum, with token0 binding.
- `deltaR_down_boundary`, `deltaR_continuation_asymmetry` - properties of the
  upward closed form continued to `δ < 0`. They are not statements about
  the downward residual, where token1 binds.

`GeometricSiphon/MonotonicityDown.lean` - Corollary 4.1 (Downward
displacement):

- `token1_binds_down`, `deltaRdown_eq_value_loss` - for a downward
  displacement token1 binds and `V_old - V_new = L d s (s + sb) / (sb sb')`, with
  `d = s̄ - s`.
- `deltaRdown_strictMono` - strictly increasing in `d` on `[0, w/2]` under
  `w < s̄`, which is the paper's `sb < 3 sa`.
- `deltaRdown_zero`, `deltaRdown_boundary` (`= L w sa / sb`) - endpoint
  values.
- `deltaRdown_lt_up`, `deltaRdown_eq_up_mul` - the downward residual is the
  smaller at equal displacement, with the exact ratio of the two
  (`s̄ / sb` at `d = 0`).
- `retUp`, `retDown` - the fraction of value redeployed in each direction
  (`retUp_eq`, `retDown_eq`); `retUp_strictAnti`, `retDown_strictAnti` and
  the boundary lemmas give the residual fraction strictly increasing in the
  displacement in both directions, zero at the centre and one at both
  boundaries.

`GeometricSiphon/Excursion.lean` - the remark on ranges of equal width in
ticks:

- `tick_width_alpha`, `tick_width_alpha_sinh` - the zero-swap residual
  fraction of a tick-centred recentring, `sinh ℓ / (e^h - cosh ℓ)`.

### Theorems 5 and 6 (Directional and exit asymmetry), §3.8, §3.9

`GeometricSiphon/DirectionalExit.lean`:

- `directional_identity` - `V(s+δ) - V(s-δ) = 4 L δ (1 - s/sb)`;
  `directional_asymmetry` - strict positivity in range.
- `directional_scaling_exact`, `directional_scaling_price_form` - the
  leading term of the price-space scaling corollary as an exact identity in
  the substitution `δ = ΔP/(2s)`.
- `vbelow_strictAnti`, `exit_asymmetry`, `exit_ratio`,
  `exit_ratio_at_zero`, `vbelow_extinct` - Theorem 6 and its closed-form
  retention ratio `(sa - d)² / (sa sb)`.

### Proposition 7 (Partial-swap extinction), §3.10

`GeometricSiphon/PartialSwap.lean`:

- `VK_succ`, `VK_zero` - the recursion behind the product law, for an
  arbitrary sequence of undeployed fractions.
- `partial_swap_mean_bound` - the bound of Theorem 3(iii) with `β` in place
  of `α`; `VK_zero_swap_le_partial` - the partial-swap trajectory lies above
  the zero-swap one when `β k ≤ α k`.
- `uniform_recovery_bound` - Corollary 7.1: with `β k = (1 - S) α k`, the
  extinction bound of Theorem 3(iv) is at least `1 / (1 - S)` times its
  zero-swap value, before rounding (`log_uniform_recovery` is the concavity
  step).

### Proposition 9 (Displacement identity), §3.11

`GeometricSiphon/ResidualShare.lean`:

- `displacement_identity_token0`, `displacement_identity_token1` - after a
  costless swap of value `Q ≤ V (ω' - ω)` at a fixed price,
  `ω' β + Q / V = ω' - ω`.
- `displacement_identity_narrow` - Corollary 9.1.
- `exit_trade_value`, `exit_trade_optimal` - Corollary 9.2: after an exit,
  with proportional swap cost `κ`, the value deployed is greatest at
  `Q = ω' V / (1 - κ (1 - ω'))`, where it is `(1 - κ) V / (1 - κ (1 - ω'))`.

### Proposition 10 (Retained excursion), §3.11

`GeometricSiphon/Excursion.lean`:

- `excursion_up_out`, `excursion_up_leftover`, `excursion_up_back` - a range
  `[s/v, s v]`, the price moved to `s u` and back with `1 < u < v`,
  recentred each time with no swap and the leftover retained. Token0 binds
  at both mints, and `L_end / L_start = 1 - (u + 1/u - 2) v / (v - 1)²`.
- `excursion_down_out`, `excursion_down_leftover`, `excursion_down_back` -
  the downward excursion, with token1 binding at both mints and the same
  factor.
- `excursion_factor_sinh` - the factor as `sinh²(ℓ/2) / sinh²(h/2)` with
  `u = e^ℓ`, `v = e^h`.

### Proposition 11 (Netting), §3.12

`GeometricSiphon/SharedBalance.lean`. The file states the model: value
mismatches `z i k` per position and token, and swap plans that must change
each aggregate holding by minus the aggregate mismatch.

- `netting_lower_bound`, `netting_attained` - any swap plan sells at least
  `∑ₖ (∑ᵢ z_{i,k})⁺`, and selling the aggregate surpluses attains it.
- `netting_saving`, `netting_saving_pos_iff` - the saving per token is
  `min (∑ᵢ z⁺) (∑ᵢ z⁻)`, positive exactly when the token is in surplus in
  one position and missing in another.
- `centred_token0_missing`, `centred_token1_missing` - the first statement
  of Corollary 11.1: a position centred in tick space holds less than half
  its value in the token that has since risen.

### Proposition 12 (Neutral accounting), §3.12

`GeometricSiphon/SharedBalance.lean`. The file states the model: deployed
values and entitlements per position, and a rebalance that mints the lesser
of the ownerless mint and the position's equity after its own slippage.

- `neutral_own_equity`, `neutral_others`, `neutral_entitlement_nonneg`,
  `neutral_sum`, `neutral_attains` - under the rule the rebalancing
  position's equity falls by its own slippage only, no other entitlement
  changes, the entitlements still sum to the dust pool's value, and a
  position that could deploy at its own value does.
- `neutral_unique` - Corollary 12.1, at a rebalance.

## Scope: what is not formalised

- Theorem 2: the continuum derivation, and any identification of the
  discrete model with the on-chain process.
- Corollary 2.2: the equality case and noise in the per-event donation.
- Theorem 3, part (ii), which concerns the shared dust pool and has no
  closed form.
- Corollary 4.1: the limit statement for the ratio of the two residuals is
  given as an exact identity, not as a limit.
- Theorems 5 and 6: the asymptotic remainder of the price-space scaling
  corollary.
- Proposition 8 and Corollary 8.1 (the leftover and the swap size). Both
  are first-order statements in the liquidity share and the ratio mismatch.
- Proposition 10: the approximation `1 - (ℓ/h)²` for a narrow range.
- Corollary 11.1: the graph statement, that a token nets exactly when its
  return lies strictly between those of two partners. The file gives the
  two facts it combines, the missing token of a centred position and the
  condition for a positive saving.
- Corollary 12.1: the division of the dust pool's revaluation between
  rebalances.
- Propositions 11 and 12 are statements about an accounting rule. What is
  checked is the arithmetic of the rule, not that a contract implements it.
- Everything is in real arithmetic. Integer rounding, ticks and fees are
  outside the model.

## Building

Requires elan, the Lean toolchain manager. The pinned toolchain is in
`lean-toolchain`; mathlib is pinned by `lake-manifest.json`.

```
lake exe cache get   # fetch prebuilt mathlib (several GB, one-off)
lake build
```

Axiom audit:

```
lake env lean AxiomCheck.lean
```

It prints one line for each of 92 statements. Every one depends only on
`propext`, `Classical.choice` and `Quot.sound`, and the library contains no
`sorry`.
