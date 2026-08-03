/-
Theorems 5 and 6 of "The Geometric Siphon": directional asymmetry and exit
asymmetry, with the closed-form exit value-retention ratio and the
price-space scaling of the directional gap.

Setting (paper §3.8, §3.9, App A): pool (T0, T1) with T0 the volatile asset
and T1 a stablecoin, so position value V = L φ(s, sa, sb) is in USD. The
V3 ordering places the volatile asset as token0 throughout.

On the price-space scaling (Cor. directional-scaling): the paper's statement
is asymptotic, with remainder O((ΔP/P0)²) coming from the conversion between
the price-space displacement ΔP and the sqrt-price displacement δ. Here we
formalise the substitution δ = ΔP/(2s) as an exact identity (the leading
term); the asymptotic remainder of the exact conversion δ = √(P0+ΔP) - √P0
is not formalised.
-/
import GeometricSiphon.Defs

set_option linter.style.header false

namespace GeometricSiphon

/-! ### Theorem 5: directional asymmetry -/

/-- The directional identity (eq. directional-identity):
    V(s+δ) - V(s-δ) = 4 L δ (1 - s/sb), with the range held fixed. -/
theorem directional_identity (L s sa sb δ : ℝ) (hsb : sb ≠ 0) :
    L * phi (s + δ) sa sb - L * phi (s - δ) sa sb
      = 4 * L * δ * (1 - s / sb) := by
  unfold phi
  field_simp
  ring

/-- **Theorem 5 (Directional asymmetry).** For s interior to the range and
    any admissible δ > 0, the up-move position retains strictly more USD
    value than the down-move position. -/
theorem directional_asymmetry (L s sa sb δ : ℝ)
    (hL : 0 < L) (hδ : 0 < δ) (hs : s < sb) (hsb : 0 < sb) :
    L * phi (s - δ) sa sb < L * phi (s + δ) sa sb := by
  have hid := directional_identity L s sa sb δ hsb.ne'
  have hfac : 0 < 1 - s / sb := by
    rw [sub_pos, div_lt_one hsb]
    exact hs
  have key : 0 < 4 * L * δ * (1 - s / sb) :=
    mul_pos (mul_pos (mul_pos (by norm_num) hL) hδ) hfac
  linarith [hid, key]

/-- Price-space scaling, leading term as an exact identity: substituting
    δ = ΔP/(2s) into the directional identity gives
    gap = (2 L ΔP / s)(1 - s/sb). With s = √P0 and sb = √Pb this is the
    displayed formula of Cor. directional-scaling. -/
theorem directional_scaling_exact (L s sa sb ΔP : ℝ)
    (hs : s ≠ 0) (hsb : sb ≠ 0) :
    L * phi (s + ΔP / (2 * s)) sa sb - L * phi (s - ΔP / (2 * s)) sa sb
      = 2 * L * ΔP / s * (1 - s / sb) := by
  rw [directional_identity L s sa sb (ΔP / (2 * s)) hsb]
  field_simp
  ring

/-- The same identity phrased through the price variables P0 = s², Pb = sb²
    as in the paper's display: gap = (2 L ΔP / √P0)(1 - √(P0/Pb)). -/
theorem directional_scaling_price_form (L s sa sb ΔP : ℝ)
    (hs : 0 < s) (hsb : 0 < sb) :
    L * phi (s + ΔP / (2 * s)) sa sb - L * phi (s - ΔP / (2 * s)) sa sb
      = 2 * L * ΔP / Real.sqrt (s ^ 2) * (1 - Real.sqrt (s ^ 2 / sb ^ 2)) := by
  have h1 : Real.sqrt (s ^ 2) = s := Real.sqrt_sq hs.le
  have h2 : Real.sqrt (s ^ 2 / sb ^ 2) = s / sb := by
    rw [← div_pow]
    exact Real.sqrt_sq (by positivity)
  rw [h1, h2]
  exact directional_scaling_exact L s sa sb ΔP hs.ne' hsb.ne'

/-! ### Theorem 6: exit asymmetry -/

/-- USD value of a below-range exit at displacement d past the lower
    boundary (eq. vbelow): the position is all token0, marked at the
    prevailing price (sa - d)². -/
noncomputable def Vbelow (L sa sb d : ℝ) : ℝ :=
  L * (1 / sa - 1 / sb) * (sa - d) ^ 2

/-- USD value of an above-range exit: the position is all stablecoin,
    constant in the displacement. -/
noncomputable def Vabove (L sa sb : ℝ) : ℝ := L * (sb - sa)

/-- The below-exit value is strictly decreasing in the displacement. -/
theorem vbelow_strictAnti (L sa sb d₁ d₂ : ℝ)
    (hL : 0 < L) (hsa : 0 < sa) (hab : sa < sb)
    (_h₁ : 0 ≤ d₁) (h₁₂ : d₁ < d₂) (h₂ : d₂ < sa) :
    Vbelow L sa sb d₂ < Vbelow L sa sb d₁ := by
  have hsb : 0 < sb := hsa.trans hab
  have hcoef : 0 < 1 / sa - 1 / sb :=
    sub_pos.mpr (one_div_lt_one_div_of_lt hsa hab)
  have hLc : 0 < L * (1 / sa - 1 / sb) := mul_pos hL hcoef
  have hsq : (sa - d₂) ^ 2 < (sa - d₁) ^ 2 := by nlinarith
  unfold Vbelow
  exact mul_lt_mul_of_pos_left hsq hLc

/-- **Theorem 6 (Exit asymmetry).** At every displacement 0 ≤ d < sa past
    the lower boundary, the below-exit retains strictly less USD value than
    the above-exit. -/
theorem exit_asymmetry (L sa sb d : ℝ)
    (hL : 0 < L) (hsa : 0 < sa) (hab : sa < sb)
    (hd : 0 ≤ d) (hd' : d < sa) :
    Vbelow L sa sb d < Vabove L sa sb := by
  have hsb : 0 < sb := hsa.trans hab
  have hpos : 0 < sa * sb := mul_pos hsa hsb
  have hexp : Vbelow L sa sb d * (sa * sb) = L * (sb - sa) * (sa - d) ^ 2 := by
    unfold Vbelow
    field_simp
  have hexp' : Vabove L sa sb * (sa * sb) = L * (sb - sa) * (sa * sb) := by
    unfold Vabove
    ring
  have hLba : 0 < L * (sb - sa) := mul_pos hL (sub_pos.mpr hab)
  have key : Vbelow L sa sb d * (sa * sb) < Vabove L sa sb * (sa * sb) := by
    rw [hexp, hexp']
    apply mul_lt_mul_of_pos_left _ hLba
    nlinarith
  exact lt_of_mul_lt_mul_right key hpos.le

/-- **Corollary (Closed-form exit value-retention ratio).**
    V_below(d) / V_above = (sa - d)² / (sa sb); in price variables this is
    P' / √(Pa Pb) with P' = (sa - d)², Pa = sa², Pb = sb². -/
theorem exit_ratio (L sa sb d : ℝ)
    (hL : L ≠ 0) (hsa : sa ≠ 0) (hsb : sb ≠ 0) (hab : sa ≠ sb) :
    Vbelow L sa sb d / Vabove L sa sb = (sa - d) ^ 2 / (sa * sb) := by
  have hba : sb - sa ≠ 0 := sub_ne_zero.mpr (Ne.symm hab)
  unfold Vbelow Vabove
  field_simp

/-- Ratio endpoint as d → 0: the retention ratio starts at sa/sb, i.e.
    √(Pa/Pb) < 1. -/
theorem exit_ratio_at_zero (L sa sb : ℝ)
    (hL : L ≠ 0) (hsa : sa ≠ 0) (hsb : sb ≠ 0) (hab : sa ≠ sb) :
    Vbelow L sa sb 0 / Vabove L sa sb = sa / sb := by
  rw [exit_ratio L sa sb 0 hL hsa hsb hab]
  field_simp
  ring

/-- Ratio endpoint at d = sa: the below-exit value vanishes as the volatile
    asset's price reaches zero. -/
theorem vbelow_extinct (L sa sb : ℝ) : Vbelow L sa sb sa = 0 := by
  unfold Vbelow; ring

end GeometricSiphon
