/-
Proposition 7 (Partial-swap extinction) and Corollary 7.1 (Uniform
recovery) of "The Geometric Siphon".

Setting (paper §3.10): K consecutive isolated rebalances with zero-swap
residual fractions α k. The internal swap at rebalance k leaves the
fraction β k of the position's value undeployed, 0 ≤ β k ≤ α k.

The value after K rebalances is the product of Theorem 3 with β in place
of α (`VK` of Extinction.lean, which is stated for an arbitrary sequence).
This file records the recursion behind the product, the comparison with
the zero-swap trajectory, the bounds of Theorem 3 at β, and the uniform
recovery comparison of the two extinction bounds.

For the comparison, β k = (1 - S) α k with 0 ≤ S < 1 has mean (1 - S) ᾱ,
and ln(1 / (1 - (1 - S) ᾱ)) ≤ (1 - S) ln(1 / (1 - ᾱ)) by concavity of the
logarithm, so the bound of Theorem 3(iv) is at least 1 / (1 - S) times its
zero-swap value, before rounding.
-/
import GeometricSiphon.Extinction

set_option linter.style.header false

namespace GeometricSiphon.Extinction

open Finset

/-- No rebalance, no change. -/
theorem VK_zero (V0 : ℝ) (β : ℕ → ℝ) : VK V0 β 0 = V0 := by
  simp [VK]

/-- **Proposition 7, recursion.** Each rebalance keeps the fraction
    1 - β k of the value, and the product law is its solution. -/
theorem VK_succ (V0 : ℝ) (β : ℕ → ℝ) (K : ℕ) :
    VK V0 β (K + 1) = VK V0 β K * (1 - β K) := by
  unfold VK
  rw [prod_range_succ]
  ring

/-- A swap that leaves less undeployed keeps more: with β k ≤ α k ≤ 1 the
    partial-swap trajectory lies above the zero-swap one. -/
theorem VK_zero_swap_le_partial (V0 : ℝ) (α β : ℕ → ℝ) (K : ℕ)
    (hV0 : 0 ≤ V0) (hα : ∀ k, α k ≤ 1) (hβ : ∀ k, β k ≤ α k) :
    VK V0 α K ≤ VK V0 β K := by
  unfold VK
  apply mul_le_mul_of_nonneg_left _ hV0
  exact Finset.prod_le_prod (fun k _ => by linarith [hα k])
    (fun k _ => by linarith [hβ k])

/-- **Proposition 7, bound.** The mean bound of Theorem 3(iii) with β in
    place of α. -/
theorem partial_swap_mean_bound (V0 : ℝ) (β : ℕ → ℝ) (K : ℕ)
    (hV0 : 0 ≤ V0) (hK : K ≠ 0) (hβ : ∀ k, β k ≤ 1) :
    VK V0 β K ≤ V0 * (1 - (∑ k ∈ range K, β k) / K) ^ K := by
  rw [← mean_form_eq β K hK]
  exact vK_le_mean_bound V0 β K hV0 hK hβ

/-- Under uniform recovery the mean undeployed fraction is (1 - S) ᾱ. -/
theorem uniform_recovery_mean (S : ℝ) (α : ℕ → ℝ) (K : ℕ) :
    (∑ k ∈ range K, (1 - S) * α k) / K = (1 - S) * ((∑ k ∈ range K, α k) / K) := by
  rw [← mul_sum, mul_div_assoc]

/-- Concavity of the logarithm in the form used by Corollary 7.1. -/
theorem log_uniform_recovery (S abar : ℝ)
    (hS0 : 0 ≤ S) (hS1 : S < 1) (_h0 : 0 < abar) (h1 : abar < 1) :
    Real.log (1 / (1 - (1 - S) * abar)) ≤ (1 - S) * Real.log (1 / (1 - abar)) := by
  have hb : 0 < 1 - abar := by linarith
  have hp0 : 0 ≤ 1 - S := by linarith
  have hp1 : 1 - S ≤ 1 := by linarith
  have hbern := rpow_one_add_le_one_add_mul_self
    (s := -abar) (by linarith) hp0 hp1
  rw [show (1 : ℝ) + -abar = 1 - abar from by ring,
    show 1 + (1 - S) * -abar = 1 - (1 - S) * abar from by ring] at hbern
  have hpow : 0 < (1 - abar) ^ (1 - S) := Real.rpow_pos_of_pos hb _
  have hlog := Real.log_le_log hpow hbern
  rw [Real.log_rpow hb] at hlog
  rw [one_div, one_div, Real.log_inv, Real.log_inv]
  linarith

/-- **Corollary 7.1 (Uniform recovery).** If each swap recovers the same
    fraction S of the residual, the extinction bound of Theorem 3(iv) is,
    before rounding, at least 1 / (1 - S) times its zero-swap value. -/
theorem uniform_recovery_bound (V0 ε S abar : ℝ)
    (hV : ε ≤ V0) (hε : 0 < ε)
    (hS0 : 0 ≤ S) (hS1 : S < 1) (h0 : 0 < abar) (h1 : abar < 1) :
    1 / (1 - S) * (Real.log (V0 / ε) / Real.log (1 / (1 - abar)))
      ≤ Real.log (V0 / ε) / Real.log (1 / (1 - (1 - S) * abar)) := by
  have hp : 0 < 1 - S := by linarith
  have hb : 0 < 1 - abar := by linarith
  have hlogV : 0 ≤ Real.log (V0 / ε) :=
    Real.log_nonneg ((one_le_div hε).mpr hV)
  have hA : 0 < Real.log (1 / (1 - abar)) :=
    Real.log_pos (one_lt_one_div hb (by linarith))
  have hc : 0 < 1 - (1 - S) * abar := by nlinarith [mul_pos hp h0]
  have hB : 0 < Real.log (1 / (1 - (1 - S) * abar)) :=
    Real.log_pos (one_lt_one_div hc (by nlinarith [mul_pos hp h0]))
  have hle := log_uniform_recovery S abar hS0 hS1 h0 h1
  have h := div_le_div_of_nonneg_left hlogV hB hle
  have e : 1 / (1 - S) * (Real.log (V0 / ε) / Real.log (1 / (1 - abar)))
      = Real.log (V0 / ε) / ((1 - S) * Real.log (1 / (1 - abar))) := by
    have := hp.ne'
    have := hA.ne'
    field_simp
  rw [e]
  exact h

end GeometricSiphon.Extinction
