/-
Theorem 3 (Zero-swap extinction) of "The Geometric Siphon".

Formalised here:
- Part (i), isolated case: at an above-range exit the withdrawn position is
  single-sided (x_w = 0), the recentred range requires both tokens, and the
  mint minimum gives L_new = 0, hence V_1 = 0 and residual fraction α = 1
  (`above_exit_isolated_mint_zero`). The shared-dust-pool refinement
  (0 < α ≤ 1 with a finite pool) involves the Stage 2 contract model and is
  not formalised.
- Part (iii): the K-step product law is taken as the definition `VK`, and
  both stated bounds are proved: the AM-GM mean bound
  V_K ≤ V_0 (1 - ᾱ_K)^K (`vK_le_mean_bound`) and the loose uniform bound
  V_K ≤ V_0 (1 - α_min)^K (`vK_le_min_bound`).
- Part (iv): the extinction-time ceiling, in the equivalent form that any
  K ≥ ln(V_0/ε) / ln(1/(1-ᾱ)) drives V_0 (1-ᾱ)^K below ε
  (`extinction_time`).

Part (ii) (α non-decreasing in |δ|/w past the boundary) concerns the
shared-pool mint and is argued qualitatively in the paper; it has no
self-contained closed form to formalise and is omitted.
-/
import Mathlib

set_option linter.style.header false

namespace GeometricSiphon.Extinction

open Finset

/-- Position value after K consecutive zero-swap rebalances with per-event
    residual fractions α k: the product law of Theorem 3, part (iii). -/
noncomputable def VK (V0 : ℝ) (α : ℕ → ℝ) (K : ℕ) : ℝ :=
  V0 * ∏ k ∈ range K, (1 - α k)

/-- Part (i), isolated case: minting withdrawn amounts (0, y) into a range
    that requires both tokens (positive per-liquidity amounts a', b')
    produces zero liquidity, hence zero redeployed value: total loss. -/
theorem above_exit_isolated_mint_zero (y a' b' φ' : ℝ)
    (hy : 0 ≤ y) (hb' : 0 < b') :
    min (0 / a') (y / b') * φ' = 0 := by
  rw [zero_div, min_eq_left (div_nonneg hy hb'.le)]
  ring

/-- Part (iii), loose bound: with a uniform floor α_min on the per-event
    residual fractions, V_K ≤ V_0 (1 - α_min)^K. -/
theorem vK_le_min_bound (V0 αmin : ℝ) (α : ℕ → ℝ) (K : ℕ)
    (hV0 : 0 ≤ V0) (hα : ∀ k, α k ≤ 1) (hmin : ∀ k, αmin ≤ α k) :
    VK V0 α K ≤ V0 * (1 - αmin) ^ K := by
  unfold VK
  apply mul_le_mul_of_nonneg_left _ hV0
  calc ∏ k ∈ range K, (1 - α k)
      ≤ ∏ _k ∈ range K, (1 - αmin) :=
        Finset.prod_le_prod (fun k _ => by linarith [hα k])
          (fun k _ => by linarith [hmin k])
    _ = (1 - αmin) ^ K := by rw [prod_const, card_range]

/-- Part (iii), AM-GM bound: V_K ≤ V_0 (1 - ᾱ_K)^K where ᾱ_K is the running
    mean of the residual fractions. Stated with 1 - ᾱ_K in the equivalent
    summed form (∑ (1 - α k))/K. -/
theorem vK_le_mean_bound (V0 : ℝ) (α : ℕ → ℝ) (K : ℕ)
    (hV0 : 0 ≤ V0) (hK : K ≠ 0) (hα : ∀ k, α k ≤ 1) :
    VK V0 α K ≤ V0 * ((∑ k ∈ range K, (1 - α k)) / K) ^ K := by
  unfold VK
  apply mul_le_mul_of_nonneg_left _ hV0
  have hKR : (K : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hK
  have hz : ∀ i ∈ range K, (0 : ℝ) ≤ 1 - α i := fun i _ => by linarith [hα i]
  have hw : ∀ i ∈ range K, (0 : ℝ) ≤ (K : ℝ)⁻¹ := fun i _ => by positivity
  have hw' : ∑ _i ∈ range K, (K : ℝ)⁻¹ = 1 := by
    rw [sum_const, card_range, nsmul_eq_mul]
    field_simp
  have hgm := Real.geom_mean_le_arith_mean_weighted (range K)
    (fun _ => (K : ℝ)⁻¹) (fun k => 1 - α k) hw hw' hz
  have hlhs : (∏ i ∈ range K, (1 - α i) ^ ((K : ℝ)⁻¹))
      = (∏ i ∈ range K, (1 - α i)) ^ ((K : ℝ)⁻¹) :=
    Real.finsetProd_rpow (range K) (fun k => 1 - α k) hz _
  have hrhs : ∑ i ∈ range K, (K : ℝ)⁻¹ * (1 - α i)
      = (∑ k ∈ range K, (1 - α k)) / K := by
    rw [← mul_sum]
    ring
  rw [hlhs, hrhs] at hgm
  have hprod0 : (0 : ℝ) ≤ ∏ k ∈ range K, (1 - α k) := prod_nonneg hz
  calc ∏ k ∈ range K, (1 - α k)
      = ((∏ k ∈ range K, (1 - α k)) ^ ((K : ℝ)⁻¹)) ^ (K : ℕ) := by
        rw [← Real.rpow_natCast ((∏ k ∈ range K, (1 - α k)) ^ ((K : ℝ)⁻¹)) K,
          ← Real.rpow_mul hprod0, inv_mul_cancel₀ hKR, Real.rpow_one]
    _ ≤ ((∑ k ∈ range K, (1 - α k)) / K) ^ (K : ℕ) :=
        pow_le_pow_left₀ (Real.rpow_nonneg hprod0 _) hgm K

/-- The mean form used in the bound equals 1 - ᾱ_K in the paper's notation. -/
theorem mean_form_eq (α : ℕ → ℝ) (K : ℕ) (hK : K ≠ 0) :
    (∑ k ∈ range K, (1 - α k)) / K
      = 1 - (∑ k ∈ range K, α k) / K := by
  have hKR : (K : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hK
  rw [sum_sub_distrib, sum_const, card_range, nsmul_eq_mul, mul_one]
  field_simp

/-- Part (iv), extinction time: for 0 < ᾱ < 1, any
    K ≥ ln(V_0/ε) / ln(1/(1-ᾱ)) drives the mean-bound envelope below ε.
    The paper's ceiling K* is the least such integer. -/
theorem extinction_time (V0 ε abar : ℝ) (K : ℕ)
    (hV0 : 0 < V0) (hε : 0 < ε) (h0 : 0 < abar) (h1 : abar < 1)
    (hK : Real.log (V0 / ε) / Real.log (1 / (1 - abar)) ≤ (K : ℝ)) :
    V0 * (1 - abar) ^ K ≤ ε := by
  have hb : 0 < 1 - abar := by linarith
  have hlogpos : 0 < Real.log (1 / (1 - abar)) :=
    Real.log_pos (one_lt_one_div hb (by linarith))
  have hKlog : Real.log (V0 / ε) ≤ (K : ℝ) * Real.log (1 / (1 - abar)) :=
    (div_le_iff₀ hlogpos).mp hK
  rw [one_div, Real.log_inv] at hKlog
  rw [Real.log_div hV0.ne' hε.ne'] at hKlog
  have hlhs : 0 < V0 * (1 - abar) ^ K := by positivity
  rw [← Real.log_le_log_iff hlhs hε,
    Real.log_mul hV0.ne' (by positivity), Real.log_pow]
  linarith

end GeometricSiphon.Extinction
