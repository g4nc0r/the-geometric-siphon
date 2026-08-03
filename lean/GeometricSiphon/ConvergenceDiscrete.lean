/-
Theorem 2 (Single-pool convergence), discrete-model layer.

The paper proves Theorem 2 by linearising the expected growth equation at
the equilibrium and running a spectral argument (App A); Convergence.lean
formalises that deterministic core. This file closes the expectation gap in
a different way: it declares an explicit discrete stochastic model of the
shared-balance rebalancing process and proves the convergence claim
exactly, with no linearisation.

Model (a formalisation choice, stated here once). The state is the value
vector V : Fin N -> R together with the contract dust pool D. One rebalance
event picks a position k uniformly at random; the chosen position donates
the fraction a of its value to the pool and absorbs A(D) from it:

  V' j = V j                     (j not chosen)
  V' k = (1 - a) V k + A(D)
  D'   = D + a V k - A(D).

This encodes the paper's two empirically grounded per-event laws: donation
proportional to position value (the constant proportional donation rate c
of §5, with a playing c per event), and absorption depending on the pool
state but not on the identity or size of the chosen position (the Stage 2
mint draws from the accumulated pool). Every event conserves the total
value sum V + D (`stepState_total`), matching the conservation assumption
of the rate corollary.

Results. Because donation is proportional and absorption is
identity-independent, the absorption term cancels from pairwise differences
in expectation, and the expected gap contracts by exactly (1 - a/N) per
event (`sum_step_gap`); over t events

  E[V_i(t) - V_j(t)] = (1 - a/N)^t (V_i(0) - V_j(0)),

which is `expected_gap_decay`, with the exponential envelope
|E[gap]| <= |gap(0)| exp(-a t / N) as `expected_gap_decay_exp_bound`. With
events arriving at rate N per unit time this is the corollary's rate-c
decay, independent of N. Expectation over the t-step process is the
standard backward recursion `expOver` (finite uniform choice at each step);
no measure theory is required.

What this file does not claim: identifying the model above with the
on-chain process is an empirical matter (§5), and the paper's continuum
ODE derivation is not reproduced. Where the two overlap, the discrete
result is stronger than the linearised statement.
-/
import Mathlib

set_option linter.style.header false

namespace GeometricSiphon.Convergence

open Finset

variable {N : ℕ}

/-- Process state: position values and the shared dust pool. -/
abbrev State (N : ℕ) := (Fin N → ℝ) × ℝ

/-- One rebalance event: the chosen position k donates the fraction α of
    its value to the pool and absorbs `absorb D` from it. -/
noncomputable def stepState (α : ℝ) (absorb : ℝ → ℝ) (k : Fin N) (s : State N) :
    State N :=
  (fun j => if j = k then (1 - α) * s.1 j + absorb s.2 else s.1 j,
    s.2 + α * s.1 k - absorb s.2)

/-- Expectation of f over the t-step process started at s: backward
    recursion over the uniform choice of rebalancer at each event. -/
noncomputable def expOver (α : ℝ) (absorb : ℝ → ℝ) :
    ℕ → State N → (State N → ℝ) → ℝ
  | 0, s, f => f s
  | t + 1, s, f => (∑ k, expOver α absorb t (stepState α absorb k s) f) / N

/-- Every event conserves total value ∑ V + D. -/
theorem stepState_total (α : ℝ) (absorb : ℝ → ℝ) (k : Fin N) (s : State N) :
    (∑ j, (stepState α absorb k s).1 j) + (stepState α absorb k s).2
      = (∑ j, s.1 j) + s.2 := by
  simp only [stepState]
  have hpt : ∀ j, (if j = k then (1 - α) * s.1 j + absorb s.2 else s.1 j)
      = s.1 j + (if j = k then absorb s.2 - α * s.1 j else 0) := by
    intro j
    by_cases h : j = k
    · simp [h]; ring
    · simp [h]
  simp_rw [hpt]
  rw [Finset.sum_add_distrib, Finset.sum_ite_eq' univ k]
  simp
  ring

/-- One-step cancellation: summing the post-event pairwise gap over the
    uniform choice of rebalancer, the absorption term cancels and the gap
    contracts by the factor (N - α). -/
theorem sum_step_gap (α : ℝ) (absorb : ℝ → ℝ) (s : State N) (i j : Fin N) :
    ∑ k, ((stepState α absorb k s).1 i - (stepState α absorb k s).1 j)
      = ((N : ℝ) - α) * (s.1 i - s.1 j) := by
  simp only [stepState]
  rw [Finset.sum_sub_distrib]
  have hsum : ∀ m : Fin N,
      ∑ k, (if m = k then (1 - α) * s.1 m + absorb s.2 else s.1 m)
        = (N : ℝ) * s.1 m + (absorb s.2 - α * s.1 m) := by
    intro m
    have hpt : ∀ k, (if m = k then (1 - α) * s.1 m + absorb s.2 else s.1 m)
        = s.1 m + (if m = k then absorb s.2 - α * s.1 m else 0) := by
      intro k
      by_cases h : m = k
      · simp [h]; ring
      · simp [h]
    simp_rw [hpt]
    rw [Finset.sum_add_distrib, Finset.sum_const, Finset.card_univ,
      Fintype.card_fin, nsmul_eq_mul, Finset.sum_ite_eq]
    simp
  rw [hsum i, hsum j]
  ring

/-- **Theorem 2 (Single-pool convergence), discrete model, exact form.**
    The expected pairwise gap after t events contracts geometrically:
    E[V_i(t) - V_j(t)] = (1 - α/N)^t (V_i(0) - V_j(0)). No linearisation
    is involved, and the absorption function is arbitrary. -/
theorem expected_gap_decay (hN : 0 < N) (α : ℝ) (absorb : ℝ → ℝ)
    (t : ℕ) (s : State N) (i j : Fin N) :
    expOver α absorb t s (fun s' => s'.1 i - s'.1 j)
      = (1 - α / N) ^ t * (s.1 i - s.1 j) := by
  induction t generalizing s with
  | zero => simp [expOver]
  | succ t ih =>
    have hNR : ((N : ℝ)) ≠ 0 := Nat.cast_ne_zero.mpr hN.ne'
    simp only [expOver]
    simp_rw [ih]
    rw [← Finset.mul_sum, sum_step_gap, mul_div_assoc, mul_div_right_comm,
      sub_div, div_self hNR, pow_succ]
    ring

/-- **Corollary (rate bound), discrete model.** The paper's exponential
    envelope holds with rate α per N events: for 0 ≤ α ≤ N,
    |E[V_i(t) - V_j(t)]| ≤ |V_i(0) - V_j(0)| exp(-α t / N). -/
theorem expected_gap_decay_exp_bound (hN : 0 < N) (α : ℝ) (absorb : ℝ → ℝ)
    (_hα0 : 0 ≤ α) (hαN : α ≤ N) (t : ℕ) (s : State N) (i j : Fin N) :
    |expOver α absorb t s (fun s' => s'.1 i - s'.1 j)|
      ≤ |s.1 i - s.1 j| * Real.exp (-(α * t) / N) := by
  rw [expected_gap_decay hN, abs_mul]
  have hbase0 : 0 ≤ 1 - α / N := by
    rw [sub_nonneg, div_le_one (by exact_mod_cast hN)]
    exact_mod_cast hαN
  rw [abs_of_nonneg (pow_nonneg hbase0 t),
    mul_comm ((1 - α / (N : ℝ)) ^ t) _]
  apply mul_le_mul_of_nonneg_left _ (abs_nonneg _)
  have h1 : 1 - α / N ≤ Real.exp (-(α / N)) := by
    have := Real.add_one_le_exp (-(α / N))
    linarith
  calc (1 - α / (N : ℝ)) ^ t
      ≤ Real.exp (-(α / N)) ^ t := pow_le_pow_left₀ hbase0 h1 t
    _ = Real.exp (-(α * t) / N) := by
        rw [← Real.exp_nat_mul]
        congr 1
        ring

end GeometricSiphon.Convergence
