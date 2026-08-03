/-
Formalisation of Theorem 1 (Geometric residual) of "The Geometric Siphon".

Setting (paper §2, §3.1): a concentrated liquidity position with liquidity L
at sqrt price s in range [sa, sb], with sa < s < sb, holds token amounts

  x = L (1/s - 1/sb),   y = L (s - sa),

value V = x s² + y = L φ(s, sa, sb) with φ = 2s - s²/sb - sa, and token
ratio R = x / y. A rebalance to [sa', sb'] (also containing s), isolated
case (no shared-balance tokens), mints

  L_new = min ( x / (1/s - 1/sb'),  y / (s - sa') ).

Theorem 1:  ΔR = V_new - V_old = 0  ↔  R(s,sa,sb) = R(s,sa',sb').

The core argument is abstracted over a = 1/s - 1/sb, b = s - sa (old range)
and a' = 1/s - 1/sb', b' = s - sa' (new range), all strictly positive when
the price is strictly interior to both ranges. Note φ = s²·a + b, so
V_old = L (s²a + b) and V_new = L·min(a/a', b/b')·(s²a' + b').

Beyond the iff, we also formalise the inequality implicit in the paper's
proof (the surplus token exits as dust, so value is never created):
ΔR ≤ 0 unconditionally.
-/
import GeometricSiphon.Defs
set_option linter.style.header false

namespace GeometricSiphon

/-! ### Core lemmas, abstract form -/

section Core

variable {L s a b a' b' : ℝ}

/-- The binding-constraint liquidity ratio `m = min (a/a') (b/b')` deploys
    at most the withdrawn token0: `m * a' ≤ a`. -/
private lemma min_mul_left (ha' : 0 < a') : min (a / a') (b / b') * a' ≤ a := by
  have h := min_le_left (a / a') (b / b')
  calc min (a / a') (b / b') * a' ≤ (a / a') * a' :=
        mul_le_mul_of_nonneg_right h ha'.le
    _ = a := div_mul_cancel₀ a ha'.ne'

/-- Likewise for token1: `m * b' ≤ b`. -/
private lemma min_mul_right (hb' : 0 < b') : min (a / a') (b / b') * b' ≤ b := by
  have h := min_le_right (a / a') (b / b')
  calc min (a / a') (b / b') * b' ≤ (b / b') * b' :=
        mul_le_mul_of_nonneg_right h hb'.le
    _ = b := div_mul_cancel₀ b hb'.ne'

/-- Value conservation with loss: the isolated-case rebalance never creates
    value, `V_new ≤ V_old`. (The strict-surplus direction of the paper's
    proof of Theorem 1.) -/
theorem vnew_le_vold (hL : 0 < L) (ha' : 0 < a') (hb' : 0 < b') :
    L * (min (a / a') (b / b') * (s ^ 2 * a' + b')) ≤ L * (s ^ 2 * a + b) := by
  have h1 : min (a / a') (b / b') * a' ≤ a := min_mul_left ha'
  have h2 : min (a / a') (b / b') * b' ≤ b := min_mul_right hb'
  have hs2 : (0:ℝ) ≤ s ^ 2 := sq_nonneg s
  have := mul_le_mul_of_nonneg_left h1 hs2
  nlinarith [mul_le_mul_of_nonneg_left
    (add_le_add (mul_le_mul_of_nonneg_left h1 hs2) h2) hL.le]

/-- **Theorem 1 (Geometric residual), abstract core.**
    `ΔR = 0` iff the old and new ranges require the same token ratio at the
    current price, i.e. `a/b = a'/b'` (equivalently `a·b' = a'·b`). -/
theorem residual_zero_iff (hL : 0 < L) (hs : s ≠ 0)
    (_ha : 0 < a) (hb : 0 < b) (ha' : 0 < a') (hb' : 0 < b') :
    L * (min (a / a') (b / b') * (s ^ 2 * a' + b')) - L * (s ^ 2 * a + b) = 0
      ↔ a / b = a' / b' := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have h1 : min (a / a') (b / b') * a' ≤ a := min_mul_left ha'
  have h2 : min (a / a') (b / b') * b' ≤ b := min_mul_right hb'
  constructor
  · -- ΔR = 0 forces both per-token deficits to vanish, hence equal ratios.
    intro hzero
    have hkey : s ^ 2 * (a - min (a / a') (b / b') * a')
        + (b - min (a / a') (b / b') * b') = 0 := by
      have hL' : L ≠ 0 := hL.ne'
      field_simp at hzero
      nlinarith [hzero]
    have d1 : (0:ℝ) ≤ a - min (a / a') (b / b') * a' := by linarith
    have d2 : (0:ℝ) ≤ b - min (a / a') (b / b') * b' := by linarith
    have e1 : a - min (a / a') (b / b') * a' = 0 := by nlinarith
    have e2 : b - min (a / a') (b / b') * b' = 0 := by nlinarith
    rw [div_eq_div_iff hb.ne' hb'.ne']
    nlinarith [e1, e2]
  · -- Equal ratios: both tokens redeploy in full and V_new = V_old exactly.
    intro hratio
    have hcross : a * b' = a' * b := by
      rw [div_eq_div_iff hb.ne' hb'.ne'] at hratio; linarith [hratio]
    have hmin : min (a / a') (b / b') = a / a' := by
      have : a / a' = b / b' := by
        rw [div_eq_div_iff ha'.ne' hb'.ne']; linarith [hcross]
      simp [this]
    rw [hmin]
    have hb'' : (a / a') * b' = b := by
      field_simp
      linarith [hcross]
    have ha'' : (a / a') * a' = a := div_mul_cancel₀ a ha'.ne'
    have : (a / a') * (s ^ 2 * a' + b') = s ^ 2 * a + b := by
      have : (a / a') * (s ^ 2 * a' + b')
          = s ^ 2 * ((a / a') * a') + (a / a') * b' := by ring
      rw [this, ha'', hb'']
    rw [this]; ring

end Core

/-! ### Paper-level statement, in the variables of §2 -/

section Paper

/-- **Theorem 1 (Geometric residual), paper form.**
    For a rebalance from [sa, sb] to [sa', sb'] at sqrt price s strictly
    interior to both ranges, isolated case: the signed residual
    ΔR = V_new - V_old vanishes iff R(s,sa,sb) = R(s,sa',sb'). -/
theorem geometric_residual
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb') :
    Lnew L s sa sb sa' sb' * phi s sa' sb' - L * phi s sa sb = 0
      ↔ ratio s sa sb = ratio s sa' sb' := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  -- Rewrite everything into the abstract coordinates a, b, a', b'.
  have hphi := phi_eq s sa sb hs.ne' hsb.ne'
  have hphi' := phi_eq s sa' sb' hs.ne' hsb'.ne'
  have hLnew : Lnew L s sa sb sa' sb'
      = L * (min ((1 / s - 1 / sb) / (1 / s - 1 / sb'))
              ((s - sa) / (s - sa'))) := by
    unfold Lnew
    rw [mul_div_assoc, mul_div_assoc, ← mul_min_of_nonneg _ _ hL.le]
  rw [hphi, hphi', hLnew, ratio, ratio]
  have core := residual_zero_iff (L := L) (s := s)
    (a := 1 / s - 1 / sb) (b := s - sa)
    (a' := 1 / s - 1 / sb') (b' := s - sa')
    hL hs.ne' ha hb ha' hb'
  rw [← core]
  constructor <;> intro h <;> nlinarith [h]

/-- The residual is never positive: isolated-case rebalancing only destroys
    or conserves position value (paper, proof of Theorem 1). -/
theorem residual_nonpos
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb') :
    Lnew L s sa sb sa' sb' * phi s sa' sb' - L * phi s sa sb ≤ 0 := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  have hphi := phi_eq s sa sb hs.ne' hsb.ne'
  have hphi' := phi_eq s sa' sb' hs.ne' hsb'.ne'
  have hLnew : Lnew L s sa sb sa' sb'
      = L * (min ((1 / s - 1 / sb) / (1 / s - 1 / sb'))
              ((s - sa) / (s - sa'))) := by
    unfold Lnew
    rw [mul_div_assoc, mul_div_assoc, ← mul_min_of_nonneg _ _ hL.le]
  rw [hphi, hphi', hLnew]
  have := vnew_le_vold (L := L) (s := s)
    (a := 1 / s - 1 / sb) (b := s - sa)
    (a' := 1 / s - 1 / sb') (b' := s - sa') hL ha' hb'
  nlinarith [this]

end Paper

end GeometricSiphon
