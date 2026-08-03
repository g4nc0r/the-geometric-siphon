# Lean formalisation

Machine-checked proofs of the theorems of *The Geometric Siphon*, formalised
in Lean 4 against mathlib. This is a verification artefact for the idealised
real-arithmetic model of the paper; the Foundry suite under `../foundry/`
remains the check against actual fixed-point pool arithmetic.

## Layout and coverage

The library root is `GeometricSiphon.lean`; shared definitions (φ, R, L_new
from paper §2, eqs. 4 to 6) live in `GeometricSiphon/Defs.lean` and every
theorem file imports them. File names follow the mathlib convention of
descriptive content names; the mapping to the paper's theorem numbering is
recorded here and in each file's doc comments. All theorem statements refer
to the consolidated manuscript.

`GeometricSiphon/GeometricResidual.lean` - Theorem 1 (Geometric residual):

- `geometric_residual` - paper-form iff: for a rebalance between ranges both
  strictly containing the current price, isolated case,
  `ΔR = 0 ↔ R(s, sa, sb) = R(s, sa', sb')`.
- `residual_nonpos` - `ΔR ≤ 0` unconditionally: the isolated-case rebalance
  never creates value.
- `residual_zero_iff`, `vnew_le_vold` - the abstract core.

`GeometricSiphon/Monotonicity.lean` - Theorem 4 (Residual monotonicity):

- `deltaRclosed_eq_deltaR` - the appendix simplification of the closed form,
  normalised to `ΔR(δ) = L δ (2 s̄ + w/2 + δ) / (s̄ + w/2)`.
- `deltaR_strictMono` - strict monotonicity across the whole in-range
  branch; `deltaR_zero`, `deltaR_up_boundary` (`= L w`),
  `deltaR_down_boundary` (`= -L w s̄ / sb`) give the endpoint values.
- `deltaR_branch_asymmetry` - `|ΔR(-δ)| < ΔR(δ)` at equal displacement.
- `token0_binds`, `deltaRclosed_eq_value_loss` - bridge lemmas showing the
  closed form is exactly `V_old - V_new` under Theorem 1's mint minimum,
  with token0 binding on the upward branch.

`GeometricSiphon/DirectionalExit.lean` - Theorems 5 and 6:

- `directional_identity` - `V(s+δ) - V(s-δ) = 4 L δ (1 - s/sb)`;
  `directional_asymmetry` - strict positivity in range.
- `directional_scaling_exact` / `directional_scaling_price_form` - the
  leading term of Cor. directional-scaling as an exact identity in the
  substitution δ = ΔP/(2s); the asymptotic remainder of the price-space
  conversion is not formalised.
- `vbelow_strictAnti`, `exit_asymmetry`, `exit_ratio`,
  `exit_ratio_at_zero`, `vbelow_extinct` - Theorem 6 and its closed-form
  retention ratio `(sa - d)² / (sa sb)`.

`GeometricSiphon/Extinction.lean` - Theorem 3 (Zero-swap extinction):

- `above_exit_isolated_mint_zero` - part (i), isolated case: single-sided
  withdrawal mints zero liquidity, total loss.
- `vK_le_mean_bound` - part (iii) AM-GM bound `V_K ≤ V_0 (1 - ᾱ_K)^K`
  (with `mean_form_eq` for the paper's notation);
  `vK_le_min_bound` - the loose uniform bound.
- `extinction_time` - part (iv): any `K ≥ ln(V_0/ε)/ln(1/(1-ᾱ))` drives the
  envelope below ε.
- Part (ii) concerns the shared-dust-pool mint and is argued qualitatively
  in the paper; it has no closed form to formalise and is omitted.

`GeometricSiphon/Convergence.lean` - Theorem 2 and its corollary,
linearised layer:

- `pairwise_gap_decay` / `pairwise_gap_decay_abs` - the deterministic core
  of the appendix's spectral argument: under the linearised dynamics
  `η̇ = -c η - S(t)` with common coupling term, pairwise differences decay
  at exactly rate c, independent of N.
- `equal_growth_iff_equal_value` - the equilibrium characterisation in the
  proof of Theorem 2.

`GeometricSiphon/ConvergenceDiscrete.lean` - Theorem 2, discrete-model
layer. Declares an explicit per-event model of the shared-balance process
(uniform choice of rebalancer; donation proportional to position value;
absorption drawn from the pool independently of the chosen position's
identity; total value conserved, `stepState_total`) and proves the
convergence claim exactly, with no linearisation:

- `expected_gap_decay` - `E[V_i(t) - V_j(t)] = (1 - α/N)^t (V_i(0) - V_j(0))`
  for an arbitrary absorption function; the absorption term cancels from
  pairwise differences in expectation (`sum_step_gap`).
- `expected_gap_decay_exp_bound` - the corollary's exponential envelope,
  `|E[gap]| ≤ |gap(0)| exp(-αt/N)`; with events arriving at rate N per unit
  time this is rate-c decay independent of N.
- The model is a declared formalisation choice (stated in the file header);
  identifying it with the on-chain process is an empirical matter, and the
  paper's continuum ODE derivation is not reproduced.

## Building

Requires elan (the Lean toolchain manager). The pinned toolchain is in
`lean-toolchain`; mathlib is pinned by `lake-manifest.json`.

```
lake exe cache get   # fetch prebuilt mathlib (several GB, one-off)
lake build
```

Axiom audit (confirms every theorem depends only on `propext`,
`Classical.choice` and `Quot.sound`, and contains no `sorry`):

```
lake env lean AxiomCheck.lean
```
