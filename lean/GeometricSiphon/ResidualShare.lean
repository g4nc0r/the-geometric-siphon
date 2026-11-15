/-
Theorem 1 in value fractions, Corollary 1.2 (Round trip) and Proposition 9
(Displacement identity) of "The Geometric Siphon".

Setting as in GeometricResidual.lean. A position holding token amounts in
the per-liquidity coordinates a = 1/s - 1/sb, b = s - sa has value
s²a + b per unit of liquidity, of which the fraction s²a / (s²a + b) is in
token0 and b / (s²a + b) in token1 (`frac0`, `frac1`; paper eq. fractions).

Theorem 1, value-fraction form. In the isolated case the mint takes all of
the missing token, so with ω the fraction of the withdrawn value held in
the missing token and ω' the fraction the new range requires in it,

  ΔR / V = -(ω' - ω) / ω' ≤ 0.

The missing token is token1 when R_old ≥ R_new and token0 when
R_old ≤ R_new; the two cases are `geometric_residual_share_token1` and
`geometric_residual_share_token0`. The vanishing condition is
`geometric_residual` of GeometricResidual.lean.

Corollary 1.2. A rebalance from one range to another and back at the same
price leaves the fraction ω_A (1 - ω_B) / (ω_B (1 - ω_A)) of the value
deployed, whichever range it starts from.

Proposition 9. If value Q of the surplus token is first swapped for the
missing token at the current price and at no cost, the mint leaves the
fraction β of value undeployed with ω' β + Q/V = ω' - ω.

Also here: Corollary 1.1 (the ratio-preserving ranges), Corollary 9.1 (the
narrow-range form of the identity) and Corollary 9.2 (the swap after an
exit, at a proportional cost κ).
-/
import GeometricSiphon.GeometricResidual

set_option linter.style.header false

namespace GeometricSiphon

/-! ### Value fractions -/

/-- Fraction of a position's value held in token0. -/
noncomputable def frac0 (s sa sb : ℝ) : ℝ := s ^ 2 * (1 / s - 1 / sb) / phi s sa sb

/-- Fraction of a position's value held in token1. -/
noncomputable def frac1 (s sa sb : ℝ) : ℝ := (s - sa) / phi s sa sb

/-- φ is positive strictly inside the range. -/
lemma phi_pos {s sa sb : ℝ} (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb) :
    0 < phi s sa sb := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  rw [phi_eq s sa sb hs.ne' hsb.ne']
  have : 0 < s ^ 2 * (1 / s - 1 / sb) := mul_pos (by positivity) ha
  linarith

/-- The two fractions sum to one. -/
theorem frac0_add_frac1 {s sa sb : ℝ} (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb) :
    frac0 s sa sb + frac1 s sa sb = 1 := by
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hφ := (phi_pos h0 h1 h2).ne'
  unfold frac0 frac1
  rw [← add_div, ← phi_eq s sa sb hs.ne' hsb.ne', div_self hφ]

/-- The token1 fraction in terms of the token ratio (paper eq. fractions):
    1 / (1 + R s²). -/
theorem frac1_eq_ratio {s sa sb : ℝ} (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb) :
    frac1 s sa sb = 1 / (1 + ratio s sa sb * s ^ 2) := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hφ := phi_pos h0 h1 h2
  unfold frac1 ratio
  rw [phi_eq s sa sb hs.ne' hsb.ne'] at hφ ⊢
  have hb' : s - sa ≠ 0 := hb.ne'
  have hden : 1 + (1 / s - 1 / sb) / (s - sa) * s ^ 2
      = (s ^ 2 * (1 / s - 1 / sb) + (s - sa)) / (s - sa) := by
    rw [add_div, div_self hb']; ring
  rw [hden, one_div_div]

/-- The token0 fraction in terms of the token ratio: R s² / (1 + R s²). -/
theorem frac0_eq_ratio {s sa sb : ℝ} (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb) :
    frac0 s sa sb = ratio s sa sb * s ^ 2 / (1 + ratio s sa sb * s ^ 2) := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  have hs : (0:ℝ) < s := h0.trans h1
  have hpos : 0 < 1 + ratio s sa sb * s ^ 2 := by
    have : 0 < ratio s sa sb := div_pos ha hb
    positivity
  have h := frac0_add_frac1 h0 h1 h2
  rw [frac1_eq_ratio h0 h1 h2] at h
  have : frac0 s sa sb = 1 - 1 / (1 + ratio s sa sb * s ^ 2) := by linarith
  rw [this, eq_div_iff hpos.ne', sub_mul, one_mul, one_div, inv_mul_cancel₀ hpos.ne']
  ring

/-! ### Core lemmas, abstract form

Holdings (X, Y) of token0 and token1, not necessarily those of a position,
are minted into a range with per-liquidity amounts (a', b'). -/

section Core

variable {s X Y a b a' b' : ℝ}

/-- Mint from holdings (X, Y) when token0 binds: the value deployed is the
    value held times ω / ω' in token0 fractions. -/
theorem mint_share_token0 (hs : s ≠ 0) (ha' : 0 < a') (hb' : 0 < b')
    (hV : s ^ 2 * X + Y ≠ 0) (hbind : X / a' ≤ Y / b') :
    min (X / a') (Y / b') * (s ^ 2 * a' + b')
      = (s ^ 2 * X + Y)
          * ((s ^ 2 * X / (s ^ 2 * X + Y)) / (s ^ 2 * a' / (s ^ 2 * a' + b'))) := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  have hsa : s ^ 2 * a' ≠ 0 := (mul_pos hs2 ha').ne'
  rw [min_eq_left hbind, div_div_eq_mul_div, div_mul_eq_mul_div, mul_div_assoc',
    div_eq_div_iff ha'.ne' hsa, div_mul_eq_mul_div, mul_div_assoc',
    div_mul_eq_mul_div, eq_div_iff hV]
  ring

/-- Mint from holdings (X, Y) when token1 binds. -/
theorem mint_share_token1 (ha' : 0 < a') (hb' : 0 < b') (hs : s ≠ 0)
    (hV : s ^ 2 * X + Y ≠ 0) (hbind : Y / b' ≤ X / a') :
    min (X / a') (Y / b') * (s ^ 2 * a' + b')
      = (s ^ 2 * X + Y)
          * ((Y / (s ^ 2 * X + Y)) / (b' / (s ^ 2 * a' + b'))) := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  rw [min_eq_right hbind, div_div_eq_mul_div, div_mul_eq_mul_div, mul_div_assoc',
    div_eq_div_iff hb'.ne' hb'.ne', div_mul_eq_mul_div, mul_div_assoc',
    div_mul_eq_mul_div, eq_div_iff hV]
  ring

/-- Token0 fractions are ordered as the cross products. -/
lemma frac0_le_iff (hs : s ≠ 0) (ha : 0 < a) (hb : 0 < b) (ha' : 0 < a') (hb' : 0 < b') :
    s ^ 2 * a / (s ^ 2 * a + b) ≤ s ^ 2 * a' / (s ^ 2 * a' + b') ↔ a * b' ≤ a' * b := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  rw [div_le_div_iff₀ hP hP']
  constructor
  · intro h
    have : s ^ 2 * (a * b') ≤ s ^ 2 * (a' * b) := by nlinarith
    exact le_of_mul_le_mul_left this hs2
  · intro h
    have : s ^ 2 * (a * b') ≤ s ^ 2 * (a' * b) := mul_le_mul_of_nonneg_left h hs2.le
    nlinarith

/-- Token1 fractions are ordered as the opposite cross products. -/
lemma frac1_le_iff (hs : s ≠ 0) (ha : 0 < a) (hb : 0 < b) (ha' : 0 < a') (hb' : 0 < b') :
    b / (s ^ 2 * a + b) ≤ b' / (s ^ 2 * a' + b') ↔ a' * b ≤ a * b' := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  rw [div_le_div_iff₀ hP hP']
  constructor
  · intro h
    have : s ^ 2 * (a' * b) ≤ s ^ 2 * (a * b') := by nlinarith
    exact le_of_mul_le_mul_left this hs2
  · intro h
    have : s ^ 2 * (a' * b) ≤ s ^ 2 * (a * b') := mul_le_mul_of_nonneg_left h hs2.le
    nlinarith

end Core

/-! ### Theorem 1, value-fraction form -/

section Paper

/-- `Lnew` as L times the minimum of the two coordinate ratios. -/
private lemma Lnew_eq (L s sa sb sa' sb' : ℝ) (hL : 0 < L) :
    Lnew L s sa sb sa' sb'
      = L * (min ((1 / s - 1 / sb) / (1 / s - 1 / sb')) ((s - sa) / (s - sa'))) := by
  unfold Lnew
  rw [mul_div_assoc, mul_div_assoc, ← mul_min_of_nonneg _ _ hL.le]

/-- **Theorem 1 (Geometric residual), value-fraction form, token1 missing.**
    If R_old ≥ R_new then ΔR / V = -(ω' - ω) / ω' with ω, ω' the token1
    fractions of the old and new ranges, and ω ≤ ω'. -/
theorem geometric_residual_share_token1
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb')
    (hR : ratio s sa' sb' ≤ ratio s sa sb) :
    (Lnew L s sa sb sa' sb' * phi s sa' sb' - L * phi s sa sb) / (L * phi s sa sb)
        = -((frac1 s sa' sb' - frac1 s sa sb) / frac1 s sa' sb')
      ∧ frac1 s sa sb ≤ frac1 s sa' sb' := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hcross : (1 / s - 1 / sb') * (s - sa) ≤ (1 / s - 1 / sb) * (s - sa') := by
    unfold ratio at hR
    rwa [div_le_div_iff₀ hb' hb] at hR
  have hbind : (s - sa) / (s - sa') ≤ (1 / s - 1 / sb) / (1 / s - 1 / sb') := by
    rw [div_le_div_iff₀ hb' ha']; linarith
  unfold frac1
  rw [Lnew_eq L s sa sb sa' sb' hL, phi_eq s sa sb hs.ne' hsb.ne',
    phi_eq s sa' sb' hs.ne' hsb'.ne']
  set a := 1 / s - 1 / sb
  set b := s - sa
  set a' := 1 / s - 1 / sb'
  set b' := s - sa'
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  refine ⟨?_, (frac1_le_iff hs.ne' ha hb ha' hb').mpr hcross⟩
  rw [mul_assoc, mint_share_token1 ha' hb' hs.ne' hP.ne' hbind]
  have hω' : b' / (s ^ 2 * a' + b') ≠ 0 := (div_pos hb' hP').ne'
  have hPne := hP.ne'
  rw [div_eq_iff (mul_pos hL hP).ne']
  generalize b' / (s ^ 2 * a' + b') = w' at hω' ⊢
  generalize s ^ 2 * a + b = P at hPne ⊢
  field_simp
  ring

/-- **Theorem 1 (Geometric residual), value-fraction form, token0 missing.**
    If R_old ≤ R_new then ΔR / V = -(ω' - ω) / ω' with ω, ω' the token0
    fractions of the old and new ranges, and ω ≤ ω'. -/
theorem geometric_residual_share_token0
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb')
    (hR : ratio s sa sb ≤ ratio s sa' sb') :
    (Lnew L s sa sb sa' sb' * phi s sa' sb' - L * phi s sa sb) / (L * phi s sa sb)
        = -((frac0 s sa' sb' - frac0 s sa sb) / frac0 s sa' sb')
      ∧ frac0 s sa sb ≤ frac0 s sa' sb' := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hcross : (1 / s - 1 / sb) * (s - sa') ≤ (1 / s - 1 / sb') * (s - sa) := by
    unfold ratio at hR
    rwa [div_le_div_iff₀ hb hb'] at hR
  have hbind : (1 / s - 1 / sb) / (1 / s - 1 / sb') ≤ (s - sa) / (s - sa') := by
    rw [div_le_div_iff₀ ha' hb']; linarith
  unfold frac0
  rw [Lnew_eq L s sa sb sa' sb' hL, phi_eq s sa sb hs.ne' hsb.ne',
    phi_eq s sa' sb' hs.ne' hsb'.ne']
  set a := 1 / s - 1 / sb
  set b := s - sa
  set a' := 1 / s - 1 / sb'
  set b' := s - sa'
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  refine ⟨?_, (frac0_le_iff hs.ne' ha hb ha' hb').mpr hcross⟩
  rw [mul_assoc, mint_share_token0 hs.ne' ha' hb' hP.ne' hbind]
  have hω' : s ^ 2 * a' / (s ^ 2 * a' + b') ≠ 0 :=
    (div_pos (mul_pos hs2 ha') hP').ne'
  rw [div_eq_iff (mul_pos hL hP).ne', sub_div, div_self hω']
  ring

/-! ### Corollary 1.2 (Round trip) -/

/-- **Corollary 1.2, starting from the range with the smaller token0
    fraction.** From A = [sa, sb] to B = [sa', sb'] and back, with
    ω_A ≤ ω_B the token0 fractions, the value deployed is
    V · ω_A (1 - ω_B) / (ω_B (1 - ω_A)). -/
theorem round_trip_from_low
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb')
    (hω : frac0 s sa sb ≤ frac0 s sa' sb') :
    Lnew (Lnew L s sa sb sa' sb') s sa' sb' sa sb * phi s sa sb
      = L * phi s sa sb
          * (frac0 s sa sb * (1 - frac0 s sa' sb')
              / (frac0 s sa' sb' * (1 - frac0 s sa sb))) := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have e1 : 1 - frac0 s sa sb = frac1 s sa sb := by
    linarith [frac0_add_frac1 h0 h1 h2]
  have e1' : 1 - frac0 s sa' sb' = frac1 s sa' sb' := by
    linarith [frac0_add_frac1 h0' h1' h2']
  rw [e1, e1']
  unfold frac0 at hω
  unfold frac0 frac1
  rw [phi_eq s sa sb hs.ne' hsb.ne', phi_eq s sa' sb' hs.ne' hsb'.ne'] at hω ⊢
  unfold Lnew
  set a := 1 / s - 1 / sb
  set b := s - sa
  set a' := 1 / s - 1 / sb'
  set b' := s - sa'
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  have hcross : a * b' ≤ a' * b := (frac0_le_iff hs.ne' ha hb ha' hb').mp hω
  have hfirst : min (L * a / a') (L * b / b') = L * a / a' := by
    apply min_eq_left
    rw [div_le_div_iff₀ ha' hb']
    nlinarith [mul_le_mul_of_nonneg_left hcross hL.le]
  rw [hfirst]
  have hsecond : min (L * a / a' * a' / a) (L * a / a' * b' / b) = L * a / a' * b' / b := by
    apply min_eq_right
    rw [div_le_div_iff₀ hb ha]
    have hLa : 0 ≤ L * a / a' := by positivity
    nlinarith [mul_le_mul_of_nonneg_left hcross hLa]
  rw [hsecond]
  have hs2' : s ^ 2 ≠ 0 := hs2.ne'
  field_simp

/-- **Corollary 1.2, starting from the range with the larger token0
    fraction.** From B to A and back leaves the same fraction. -/
theorem round_trip_from_high
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb')
    (hω : frac0 s sa sb ≤ frac0 s sa' sb') :
    Lnew (Lnew L s sa' sb' sa sb) s sa sb sa' sb' * phi s sa' sb'
      = L * phi s sa' sb'
          * (frac0 s sa sb * (1 - frac0 s sa' sb')
              / (frac0 s sa' sb' * (1 - frac0 s sa sb))) := by
  obtain ⟨ha, hb⟩ := amount_coeffs_pos h0 h1 h2
  obtain ⟨ha', hb'⟩ := amount_coeffs_pos h0' h1' h2'
  have hs : (0:ℝ) < s := h0.trans h1
  have hsb : (0:ℝ) < sb := hs.trans h2
  have hsb' : (0:ℝ) < sb' := hs.trans h2'
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have e1 : 1 - frac0 s sa sb = frac1 s sa sb := by
    linarith [frac0_add_frac1 h0 h1 h2]
  have e1' : 1 - frac0 s sa' sb' = frac1 s sa' sb' := by
    linarith [frac0_add_frac1 h0' h1' h2']
  rw [e1, e1']
  unfold frac0 at hω
  unfold frac0 frac1
  rw [phi_eq s sa sb hs.ne' hsb.ne', phi_eq s sa' sb' hs.ne' hsb'.ne'] at hω ⊢
  unfold Lnew
  set a := 1 / s - 1 / sb
  set b := s - sa
  set a' := 1 / s - 1 / sb'
  set b' := s - sa'
  have hP : (0:ℝ) < s ^ 2 * a + b := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  have hcross : a * b' ≤ a' * b := (frac0_le_iff hs.ne' ha hb ha' hb').mp hω
  have hfirst : min (L * a' / a) (L * b' / b) = L * b' / b := by
    apply min_eq_right
    rw [div_le_div_iff₀ hb ha]
    nlinarith [mul_le_mul_of_nonneg_left hcross hL.le]
  rw [hfirst]
  have hsecond : min (L * b' / b * a / a') (L * b' / b * b / b') = L * b' / b * a / a' := by
    apply min_eq_left
    rw [div_le_div_iff₀ ha' hb']
    have hLb : 0 ≤ L * b' / b := by positivity
    nlinarith [mul_le_mul_of_nonneg_left hcross hLb]
  rw [hsecond]
  have hs2' : s ^ 2 ≠ 0 := hs2.ne'
  field_simp

/-! ### Corollary 1.1 (Ratio-preserving ranges) -/

/-- A new range requires the token ratio R at the current price exactly
    when its bounds satisfy `1 / sb' = 1 / s - R (s - sa')`. -/
theorem ratio_preserving_locus (s sa' sb' R : ℝ) (h : s - sa' ≠ 0) :
    ratio s sa' sb' = R ↔ 1 / sb' = 1 / s - R * (s - sa') := by
  unfold ratio
  rw [div_eq_iff h]
  constructor <;> intro h' <;> linarith

/-- **Corollary 1.1.** The new ranges with zero residual are those on the
    curve `1 / sb' = 1 / s - R_old (s - sa')`. -/
theorem zero_residual_locus
    (L s sa sb sa' sb' : ℝ) (hL : 0 < L)
    (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb)
    (h0' : 0 < sa') (h1' : sa' < s) (h2' : s < sb') :
    Lnew L s sa sb sa' sb' * phi s sa' sb' - L * phi s sa sb = 0
      ↔ 1 / sb' = 1 / s - ratio s sa sb * (s - sa') := by
  rw [geometric_residual L s sa sb sa' sb' hL h0 h1 h2 h0' h1' h2',
    ← ratio_preserving_locus s sa' sb' _ (sub_pos.mpr h1').ne']
  exact eq_comm

end Paper

/-! ### Proposition 9 (Displacement identity)

Holdings (X, Y) worth V = s²X + Y are rebalanced at a fixed price into a
range with per-liquidity amounts (a', b') after a costless swap of value Q
from the surplus token to the missing one. β is the fraction of V that the
mint leaves undeployed. -/

section Identity

variable {s X Y a' b' Q : ℝ}

/-- **Proposition 9, token0 missing.** With ω = s²X / V and
    ω' = s²a' / (s²a' + b'), a swap of value 0 ≤ Q ≤ V (ω' - ω) of token1
    for token0 gives ω' β + Q / V = ω' - ω. -/
theorem displacement_identity_token0 (hs : 0 < s) (ha' : 0 < a') (hb' : 0 < b')
    (hV : 0 < s ^ 2 * X + Y)
    (hQ : Q ≤ (s ^ 2 * X + Y)
      * (s ^ 2 * a' / (s ^ 2 * a' + b') - s ^ 2 * X / (s ^ 2 * X + Y))) :
    s ^ 2 * a' / (s ^ 2 * a' + b')
        * (1 - min ((X + Q / s ^ 2) / a') ((Y - Q) / b') * (s ^ 2 * a' + b')
            / (s ^ 2 * X + Y))
      + Q / (s ^ 2 * X + Y)
      = s ^ 2 * a' / (s ^ 2 * a' + b') - s ^ 2 * X / (s ^ 2 * X + Y) := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  -- the swap leaves the value unchanged
  have hVQ : s ^ 2 * (X + Q / s ^ 2) + (Y - Q) = s ^ 2 * X + Y := by
    field_simp; ring
  -- the bound on Q in cross-multiplied form
  have hQ' : Q * (s ^ 2 * a' + b') ≤ s ^ 2 * (a' * Y - X * b') := by
    have h := mul_le_mul_of_nonneg_right hQ hP'.le
    have e : (s ^ 2 * X + Y)
          * (s ^ 2 * a' / (s ^ 2 * a' + b') - s ^ 2 * X / (s ^ 2 * X + Y))
          * (s ^ 2 * a' + b')
        = s ^ 2 * (a' * Y - X * b') := by
      have := hV.ne'
      have := hP'.ne'
      field_simp
      ring
    linarith
  have hbind : (X + Q / s ^ 2) / a' ≤ (Y - Q) / b' := by
    rw [div_le_div_iff₀ ha' hb']
    have e : (X + Q / s ^ 2) * b' = (s ^ 2 * X * b' + Q * b') / s ^ 2 := by
      field_simp
    rw [e, div_le_iff₀ hs2]
    nlinarith
  have hV' : s ^ 2 * (X + Q / s ^ 2) + (Y - Q) ≠ 0 := by rw [hVQ]; exact hV.ne'
  rw [mint_share_token0 hs.ne' ha' hb' hV' hbind, hVQ]
  have hω' : s ^ 2 * a' / (s ^ 2 * a' + b') ≠ 0 := (div_pos (mul_pos hs2 ha') hP').ne'
  have e2 : s ^ 2 * (X + Q / s ^ 2) = s ^ 2 * X + Q := by field_simp
  rw [e2]
  have hVne := hV.ne'
  generalize s ^ 2 * a' / (s ^ 2 * a' + b') = w' at hω' ⊢
  generalize s ^ 2 * X + Y = V at hVne ⊢
  field_simp
  ring

/-- **Proposition 9, token1 missing.** With ω = Y / V and
    ω' = b' / (s²a' + b'), a swap of value 0 ≤ Q ≤ V (ω' - ω) of token0 for
    token1 gives ω' β + Q / V = ω' - ω. -/
theorem displacement_identity_token1 (hs : 0 < s) (ha' : 0 < a') (hb' : 0 < b')
    (hV : 0 < s ^ 2 * X + Y)
    (hQ : Q ≤ (s ^ 2 * X + Y)
      * (b' / (s ^ 2 * a' + b') - Y / (s ^ 2 * X + Y))) :
    b' / (s ^ 2 * a' + b')
        * (1 - min ((X - Q / s ^ 2) / a') ((Y + Q) / b') * (s ^ 2 * a' + b')
            / (s ^ 2 * X + Y))
      + Q / (s ^ 2 * X + Y)
      = b' / (s ^ 2 * a' + b') - Y / (s ^ 2 * X + Y) := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP' : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  have hVQ : s ^ 2 * (X - Q / s ^ 2) + (Y + Q) = s ^ 2 * X + Y := by
    field_simp; ring
  have hQ' : Q * (s ^ 2 * a' + b') ≤ s ^ 2 * (X * b' - a' * Y) := by
    have h := mul_le_mul_of_nonneg_right hQ hP'.le
    have e : (s ^ 2 * X + Y)
          * (b' / (s ^ 2 * a' + b') - Y / (s ^ 2 * X + Y))
          * (s ^ 2 * a' + b')
        = s ^ 2 * (X * b' - a' * Y) := by
      have := hV.ne'
      have := hP'.ne'
      field_simp
      ring
    linarith
  have hbind : (Y + Q) / b' ≤ (X - Q / s ^ 2) / a' := by
    rw [div_le_div_iff₀ hb' ha']
    have e : (X - Q / s ^ 2) * b' = (s ^ 2 * X * b' - Q * b') / s ^ 2 := by
      field_simp
    rw [e, le_div_iff₀ hs2]
    nlinarith
  have hV' : s ^ 2 * (X - Q / s ^ 2) + (Y + Q) ≠ 0 := by rw [hVQ]; exact hV.ne'
  rw [mint_share_token1 ha' hb' hs.ne' hV' hbind, hVQ]
  have hω' : b' / (s ^ 2 * a' + b') ≠ 0 := (div_pos hb' hP').ne'
  have hVne := hV.ne'
  generalize b' / (s ^ 2 * a' + b') = w' at hω' ⊢
  generalize s ^ 2 * X + Y = V at hVne ⊢
  field_simp
  ring

end Identity

/-! ### Corollaries 9.1 and 9.2 -/

/-- **Corollary 9.1 (Narrow-range form).** With ω = (1 - δ) / 2 and
    ω' = (1 - δ') / 2 the identity reads (1 - δ') β + 2 Q / V + δ' = δ. -/
theorem displacement_identity_narrow {ω ω' β q δ δ' : ℝ}
    (hω : ω = (1 - δ) / 2) (hω' : ω' = (1 - δ') / 2)
    (h : ω' * β + q = ω' - ω) :
    (1 - δ') * β + 2 * q + δ' = δ := by
  subst hω hω'
  linarith

section ExitTrade

variable {V ω' κ Q : ℝ}

/-- **Corollary 9.2, the swap.** A position holding one token swaps value Q
    at proportional cost κ. The two mint constraints, (1 - κ) Q / ω' and
    (V - Q) / (1 - ω'), meet at `Q = ω' V / (1 - κ (1 - ω'))`, where the
    value deployed is `(1 - κ) V / (1 - κ (1 - ω'))`. -/
theorem exit_trade_value (hω : 0 < ω') (hω1 : ω' < 1) (hκ0 : 0 ≤ κ) (hκ1 : κ < 1) :
    min ((1 - κ) * (ω' * V / (1 - κ * (1 - ω'))) / ω')
        ((V - ω' * V / (1 - κ * (1 - ω'))) / (1 - ω'))
      = (1 - κ) * V / (1 - κ * (1 - ω')) := by
  have hd : (0 : ℝ) < 1 - ω' := by linarith
  have hden : (0 : ℝ) < 1 - κ * (1 - ω') := by nlinarith
  have hω0 := hω.ne'
  have hd0 := hd.ne'
  have hden0 := hden.ne'
  have e1 : (1 - κ) * (ω' * V / (1 - κ * (1 - ω'))) / ω'
      = (1 - κ) * V / (1 - κ * (1 - ω')) := by
    field_simp
  have e2 : (V - ω' * V / (1 - κ * (1 - ω'))) / (1 - ω')
      = (1 - κ) * V / (1 - κ * (1 - ω')) := by
    rw [div_eq_div_iff hd0 hden0]
    field_simp
    ring
  rw [e1, e2, min_self]

/-- **Corollary 9.2, optimality.** No swap size deploys more. -/
theorem exit_trade_optimal (hω : 0 < ω') (hω1 : ω' < 1) (hκ0 : 0 ≤ κ) (hκ1 : κ < 1) :
    min ((1 - κ) * Q / ω') ((V - Q) / (1 - ω'))
      ≤ (1 - κ) * V / (1 - κ * (1 - ω')) := by
  have hd : (0 : ℝ) < 1 - ω' := by linarith
  have hden : (0 : ℝ) < 1 - κ * (1 - ω') := by nlinarith
  have hκ : (0 : ℝ) < 1 - κ := by linarith
  rcases le_total Q (ω' * V / (1 - κ * (1 - ω'))) with h | h
  · apply le_trans (min_le_left _ _)
    rw [div_le_div_iff₀ hω hden]
    have h' : Q * (1 - κ * (1 - ω')) ≤ ω' * V := (le_div_iff₀ hden).mp h
    nlinarith [mul_le_mul_of_nonneg_left h' hκ.le]
  · apply le_trans (min_le_right _ _)
    rw [div_le_div_iff₀ hd hden]
    have h' : ω' * V ≤ Q * (1 - κ * (1 - ω')) := (div_le_iff₀ hden).mp h
    nlinarith

end ExitTrade

end GeometricSiphon
