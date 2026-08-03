/-
Theorem 4 (Residual monotonicity) of "The Geometric Siphon".

Setting (paper §3.7, App A): equal-width rebalance recentred on the current
sqrt price. Old range [sa, sb] with width w = sb - sa and midpoint
sbar = (sa + sb)/2; current price s = sbar + δ; new range [s - w/2, s + w/2].
For δ ≥ 0 token0 binds and the residual appears as surplus token1
(eq. dr-closed-form):

  ΔR(δ) = L (s - sa) - L ((1/s - 1/sb) / (1/s - 1/(s + w/2))) (w/2).

Sign convention: in this theorem ΔR(δ) is the value surrendered by the
rebalance, i.e. V_old - V_new, which is ≥ 0 on the upward branch. Theorem 1's
signed residual is the negative of this quantity.

The appendix simplification (eq. g-simplified) reduces the closed form to a
rational function; here we normalise one step further, to

  ΔR(δ) = L δ (2 sbar + w/2 + δ) / (sbar + w/2),

from which ΔR(0) = 0, ΔR(w/2) = L w, strict monotonicity across the branch,
the downward-branch boundary magnitude L w sbar / sb, and the branch
asymmetry |ΔR(-δ)| < ΔR(δ) all follow.

We also prove the bridging results the paper leaves implicit: for
0 ≤ δ < w/2 token0 is the binding constraint in the mint minimum of
Theorem 1 (`token0_binds`), and the closed form equals V_old - V_new with
V_new built from `Lnew` and `phi` of the Theorem 1 development
(`deltaRclosed_eq_value_loss`). Proofs work in the half-width variable
u = w/2 internally.
-/
import GeometricSiphon.Defs

set_option linter.style.header false

namespace GeometricSiphon

/-- The paper's closed form (eq. dr-closed-form): token1 surplus of the
    equal-width recentred rebalance, as a function of the current price s
    and the old range. -/
noncomputable def deltaRclosed (L s sa sb w : ℝ) : ℝ :=
  L * (s - sa) - L * ((1 / s - 1 / sb) / (1 / s - 1 / (s + w / 2))) * (w / 2)

/-- The simplified form in midpoint-displacement coordinates. -/
noncomputable def deltaR (L sbar w δ : ℝ) : ℝ :=
  L * δ * (2 * sbar + w / 2 + δ) / (sbar + w / 2)

/-- The appendix simplification (eq. g-simplified, normalised): substituting
    s = sbar + δ, sa = sbar - w/2, sb = sbar + w/2 into the closed form
    yields the rational normal form. Holds on the closed branch δ ≥ -w/2. -/
theorem deltaRclosed_eq_deltaR (L sbar w δ : ℝ)
    (hw : 0 < w) (hmid : w / 2 < sbar) (hδl : -(w / 2) ≤ δ) :
    deltaRclosed L (sbar + δ) (sbar - w / 2) (sbar + w / 2) w
      = deltaR L sbar w δ := by
  unfold deltaRclosed deltaR
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hs : 0 < sbar + δ := by linarith
  have hsw : 0 < sbar + δ + u := by linarith
  have hsb : 0 < sbar + u := by linarith
  have hs' : sbar + δ ≠ 0 := hs.ne'
  have hsw' : sbar + δ + u ≠ 0 := hsw.ne'
  have hsb' : sbar + u ≠ 0 := hsb.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hnum : 1 / (sbar + δ) - 1 / (sbar + u)
      = (u - δ) / ((sbar + δ) * (sbar + u)) := by
    field_simp; ring
  have hden : 1 / (sbar + δ) - 1 / ((sbar + δ) + u)
      = u / ((sbar + δ) * ((sbar + δ) + u)) := by
    field_simp; ring
  rw [hnum, hden, div_div_eq_mul_div]
  field_simp
  ring

/-- ΔR(0) = 0: the centred rebalance is ratio-preserving (Theorem 1). -/
theorem deltaR_zero (L sbar w : ℝ) : deltaR L sbar w 0 = 0 := by
  unfold deltaR; ring

/-- Upward boundary value: ΔR(w/2) = L w. -/
theorem deltaR_up_boundary (L sbar w : ℝ) (hsb : sbar + w / 2 ≠ 0) :
    deltaR L sbar w (w / 2) = L * w := by
  rw [show L * w = L * (2 * (w / 2)) from by ring]
  unfold deltaR
  set u : ℝ := w / 2 with hu
  field_simp
  ring

/-- Downward boundary value: ΔR(-w/2) = -(L w sbar / sb) with sb = sbar + w/2,
    i.e. boundary magnitude smaller than the upward branch by sbar / sb. -/
theorem deltaR_down_boundary (L sbar w : ℝ) (hsb : sbar + w / 2 ≠ 0) :
    deltaR L sbar w (-(w / 2)) = -(L * w * sbar / (sbar + w / 2)) := by
  rw [show L * w * sbar = L * (2 * (w / 2)) * sbar from by ring]
  unfold deltaR
  set u : ℝ := w / 2 with hu
  field_simp
  ring

/-- **Theorem 4 (Residual monotonicity), monotone core.** ΔR is strictly
    increasing in δ across the whole in-range branch [-w/2, w/2]; with
    `deltaR_zero`, |ΔR| is therefore strictly increasing in |δ| on each
    branch, with the endpoint values given by the boundary lemmas. -/
theorem deltaR_strictMono (L sbar w δ₁ δ₂ : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (h₁ : -(w / 2) ≤ δ₁) (_h₂ : δ₂ ≤ w / 2) (h₁₂ : δ₁ < δ₂) :
    deltaR L sbar w δ₁ < deltaR L sbar w δ₂ := by
  have hsb : 0 < sbar + w / 2 := by linarith
  unfold deltaR
  rw [div_eq_mul_inv, div_eq_mul_inv]
  apply mul_lt_mul_of_pos_right _ (inv_pos.mpr hsb)
  have hbracket : 0 < 2 * sbar + w / 2 + (δ₁ + δ₂) := by linarith
  have key : 0 < L * ((δ₂ - δ₁) * (2 * sbar + w / 2 + (δ₁ + δ₂))) :=
    mul_pos hL (mul_pos (by linarith) hbracket)
  have expand : L * δ₂ * (2 * sbar + w / 2 + δ₂) - L * δ₁ * (2 * sbar + w / 2 + δ₁)
      = L * ((δ₂ - δ₁) * (2 * sbar + w / 2 + (δ₁ + δ₂))) := by ring
  linarith [key, expand]

/-- Branch asymmetry at equal displacement: the downward-branch magnitude is
    strictly smaller, |ΔR(-δ)| < ΔR(δ) for δ ∈ (0, w/2]. -/
theorem deltaR_branch_asymmetry (L sbar w δ : ℝ)
    (hL : 0 < L) (_hw : 0 < w) (hmid : w / 2 < sbar)
    (hδ : 0 < δ) (hδ' : δ ≤ w / 2) :
    |deltaR L sbar w (-δ)| < deltaR L sbar w δ := by
  have hsb : 0 < sbar + w / 2 := by linarith
  have hbr : 0 < 2 * sbar + w / 2 - δ := by linarith
  have hneg : deltaR L sbar w (-δ)
      = -(L * δ * (2 * sbar + w / 2 - δ) / (sbar + w / 2)) := by
    unfold deltaR; ring
  have habs : 0 < L * δ * (2 * sbar + w / 2 - δ) / (sbar + w / 2) :=
    div_pos (mul_pos (mul_pos hL hδ) hbr) hsb
  rw [hneg, abs_neg, abs_of_pos habs]
  unfold deltaR
  rw [div_eq_mul_inv, div_eq_mul_inv]
  apply mul_lt_mul_of_pos_right _ (inv_pos.mpr hsb)
  have key : 0 < 2 * (L * δ * δ) := by positivity
  have expand : L * δ * (2 * sbar + w / 2 + δ) - L * δ * (2 * sbar + w / 2 - δ)
      = 2 * (L * δ * δ) := by ring
  linarith [key, expand]

/-! ### Bridge to the Theorem 1 development

The closed form is not free-standing: it is V_old - V_new for the recentred
rebalance, with V_new determined by the mint minimum of Theorem 1. The two
lemmas below make that precise on the upward branch 0 ≤ δ < w/2 (at δ = w/2
the price sits on the old boundary and the position is single-sided; that
endpoint is covered by Theorem 3's exit analysis and by continuity). -/

/-- For 0 ≤ δ < w/2 the token0 term is the binding constraint in the mint
    minimum: `Lnew` equals the token0-limited liquidity. -/
theorem token0_binds (L sbar w δ : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hδ : 0 ≤ δ) (hδ' : δ < w / 2) :
    Lnew L (sbar + δ) (sbar - w / 2) (sbar + w / 2)
        ((sbar + δ) - w / 2) ((sbar + δ) + w / 2)
      = L * (1 / (sbar + δ) - 1 / (sbar + w / 2))
          / (1 / (sbar + δ) - 1 / ((sbar + δ) + w / 2)) := by
  unfold Lnew
  apply min_eq_left
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hs : 0 < sbar + δ := by linarith
  have hsw : 0 < sbar + δ + u := by linarith
  have hsb : 0 < sbar + u := by linarith
  have hs' : sbar + δ ≠ 0 := hs.ne'
  have hsw' : sbar + δ + u ≠ 0 := hsw.ne'
  have hsb' : sbar + u ≠ 0 := hsb.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hnum : 1 / (sbar + δ) - 1 / (sbar + u)
      = (u - δ) / ((sbar + δ) * (sbar + u)) := by
    field_simp; ring
  have hden : 1 / (sbar + δ) - 1 / ((sbar + δ) + u)
      = u / ((sbar + δ) * ((sbar + δ) + u)) := by
    field_simp; ring
  rw [hnum, hden,
    show (sbar + δ) - ((sbar + δ) - u) = u from by ring,
    show (sbar + δ) - (sbar - u) = δ + u from by ring]
  have hdiff : L * (δ + u) / u
      - L * ((u - δ) / ((sbar + δ) * (sbar + u)))
          / (u / ((sbar + δ) * ((sbar + δ) + u)))
      = L * (δ * (2 * sbar + u + δ)) / (u * (sbar + u)) := by
    rw [div_div_eq_mul_div]
    field_simp
    ring
  have hpos : 0 ≤ L * (δ * (2 * sbar + u + δ)) / (u * (sbar + u)) := by
    have hb : 0 ≤ δ * (2 * sbar + u + δ) := mul_nonneg hδ (by linarith)
    exact div_nonneg (mul_nonneg hL.le hb) (by positivity)
  linarith [hdiff, hpos]

/-- The closed form is the value surrendered: ΔR(δ) = V_old - V_new, with
    V_new = Lnew · φ(new range) from the Theorem 1 development. -/
theorem deltaRclosed_eq_value_loss (L sbar w δ : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hδ : 0 ≤ δ) (hδ' : δ < w / 2) :
    deltaRclosed L (sbar + δ) (sbar - w / 2) (sbar + w / 2) w
      = L * phi (sbar + δ) (sbar - w / 2) (sbar + w / 2)
        - Lnew L (sbar + δ) (sbar - w / 2) (sbar + w / 2)
            ((sbar + δ) - w / 2) ((sbar + δ) + w / 2)
          * phi (sbar + δ) ((sbar + δ) - w / 2) ((sbar + δ) + w / 2) := by
  have hs0 : 0 < sbar + δ := by linarith
  have hsw0 : 0 < sbar + δ + w / 2 := by linarith
  have hsb0 : 0 < sbar + w / 2 := by linarith
  rw [token0_binds L sbar w δ hL hw hmid hδ hδ',
    phi_eq _ _ _ hs0.ne' hsb0.ne', phi_eq _ _ _ hs0.ne' hsw0.ne']
  unfold deltaRclosed
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hs : 0 < sbar + δ := by linarith
  have hsw : 0 < sbar + δ + u := by linarith
  have hsb : 0 < sbar + u := by linarith
  have hs' : sbar + δ ≠ 0 := hs.ne'
  have hsw' : sbar + δ + u ≠ 0 := hsw.ne'
  have hsb' : sbar + u ≠ 0 := hsb.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hnum : 1 / (sbar + δ) - 1 / (sbar + u)
      = (u - δ) / ((sbar + δ) * (sbar + u)) := by
    field_simp; ring
  have hden : 1 / (sbar + δ) - 1 / ((sbar + δ) + u)
      = u / ((sbar + δ) * ((sbar + δ) + u)) := by
    field_simp; ring
  rw [hnum, hden, div_div_eq_mul_div, div_div_eq_mul_div]
  field_simp
  ring

end GeometricSiphon
