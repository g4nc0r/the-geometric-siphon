/-
Proposition 10 (Retained excursion) of "The Geometric Siphon", and the
remark on ranges of equal width in ticks that follows Corollary 4.1.

Setting (paper §3.11). A fully deployed position with liquidity L has a
range centred on s in tick space, [s/v, s v] with v = e^h > 1. The sqrt
price moves to s u (upward) or s / u (downward) with 1 < u < v, u = e^|ℓ|,
and returns to s. After each move the range is recentred at equal width in
ticks with no swap, and the position's own leftover is retained and offered
to the next mint.

Upward excursion. On the way out token0 binds and the leftover is token1;
on the way back token0 binds again, the retained token1 being enough for
the mint. Downward excursion: the mirror image, with token1 binding at
both mints. In both cases

  L_end / L_start = 1 - (u + 1/u - 2) v / (v - 1)²
                  = 1 - sinh²(ℓ/2) / sinh²(h/2).

The binding token at each mint is proved, not assumed. The approximation
1 - (ℓ/h)² for small h is not formalised.

Tick-width remark. The zero-swap residual fraction of the recentred mint is
(u - 1/u) / (2v - u - 1/u) = sinh ℓ / (e^h - cosh ℓ).
-/
import GeometricSiphon.Defs

set_option linter.style.header false

namespace GeometricSiphon

/-! ### Upward excursion -/

section Up

variable {L s u v : ℝ}

/-- Way out, token0 candidate: liquidity `L (v - u) / (v - 1)`. -/
lemma excursion_up_out_token0 (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    L * (1 / (s * u) - 1 / (s * v)) / (1 / (s * u) - 1 / (s * u * v))
      = L * (v - u) / (v - 1) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : u ≠ 0 := by linarith
  have hv0 : v ≠ 0 := by linarith
  have hv1 : v - 1 ≠ 0 := by linarith
  have e1 : 1 / (s * u) - 1 / (s * v) = (v - u) / (s * u * v) := by field_simp
  have e2 : 1 / (s * u) - 1 / (s * u * v) = (v - 1) / (s * u * v) := by field_simp
  rw [e1, e2]
  field_simp

/-- Way out, token1 candidate: liquidity `L (u v - 1) / (u (v - 1))`. -/
lemma excursion_up_out_token1 (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    L * (s * u - s / v) / (s * u - s * u / v) = L * (u * v - 1) / (u * (v - 1)) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : u ≠ 0 := by linarith
  have hv0 : v ≠ 0 := by linarith
  have hv1 : v - 1 ≠ 0 := by linarith
  have e1 : s * u - s / v = s * (u * v - 1) / v := by field_simp
  have e2 : s * u - s * u / v = s * u * (v - 1) / v := by field_simp
  rw [e1, e2]
  field_simp

/-- **Proposition 10, way out.** Token0 binds, and the mint leaves the
    position with liquidity `L (v - u) / (v - 1)`. -/
theorem excursion_up_out (hL : 0 < L) (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    min (L * (1 / (s * u) - 1 / (s * v)) / (1 / (s * u) - 1 / (s * u * v)))
        (L * (s * u - s / v) / (s * u - s * u / v))
      = L * (v - u) / (v - 1) := by
  rw [excursion_up_out_token0 hs hu huv, excursion_up_out_token1 hs hu huv]
  apply min_eq_left
  have hu0 : 0 < u := by linarith
  have hv1 : 0 < v - 1 := by linarith
  rw [div_le_div_iff₀ hv1 (mul_pos hu0 hv1)]
  have key : L * (u * v - 1) * (v - 1) - L * (v - u) * (u * (v - 1))
      = L * (v - 1) * ((u - 1) * (u + 1)) := by ring
  have hpos : 0 ≤ L * (v - 1) * ((u - 1) * (u + 1)) := by
    have : 0 ≤ (u - 1) * (u + 1) := mul_nonneg (by linarith) (by linarith)
    exact mul_nonneg (mul_nonneg hL.le hv1.le) this
  linarith

/-- The token1 left over on the way out, `L s (u² - 1) / v`. -/
theorem excursion_up_leftover (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    L * (s * u - s / v) - L * (v - u) / (v - 1) * (s * u - s * u / v)
      = L * s * (u ^ 2 - 1) / v := by
  have hv0 : v ≠ 0 := by linarith
  have hv1 : v - 1 ≠ 0 := by linarith
  field_simp
  ring

/-- **Proposition 10, way back.** With the token1 leftover retained, token0
    binds again at the return mint. Here `L₁ = L (v - u) / (v - 1)` is the
    liquidity after the first mint and `L s (u² - 1) / v` the leftover. -/
theorem excursion_up_back (hL : 0 < L) (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    min (L * (v - u) / (v - 1) * (1 / s - 1 / (s * u * v)) / (1 / s - 1 / (s * v)))
        ((L * (v - u) / (v - 1) * (s - s * u / v) + L * s * (u ^ 2 - 1) / v)
          / (s - s / v))
      = L * (1 - (u + 1 / u - 2) * v / (v - 1) ^ 2) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : 0 < u := by linarith
  have hv0 : 0 < v := by linarith
  have hv1 : 0 < v - 1 := by linarith
  have hu0' : u ≠ 0 := hu0.ne'
  have hv0' : v ≠ 0 := hv0.ne'
  have hv1' : v - 1 ≠ 0 := hv1.ne'
  have e0 : L * (v - u) / (v - 1) * (1 / s - 1 / (s * u * v)) / (1 / s - 1 / (s * v))
      = L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2) := by
    have a1 : 1 / s - 1 / (s * u * v) = (u * v - 1) / (s * u * v) := by field_simp
    have a2 : 1 / s - 1 / (s * v) = (v - 1) / (s * v) := by field_simp
    rw [a1, a2]
    field_simp
  have e1 : (L * (v - u) / (v - 1) * (s - s * u / v) + L * s * (u ^ 2 - 1) / v)
        / (s - s / v)
      = (L * (v - u) ^ 2 + L * (u ^ 2 - 1) * (v - 1)) / (v - 1) ^ 2 := by
    have b2 : s - s / v = s * (v - 1) / v := by field_simp
    rw [b2]
    field_simp
  have e2 : L * (1 - (u + 1 / u - 2) * v / (v - 1) ^ 2)
      = L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2) := by
    field_simp
    ring
  rw [e0, e1, e2]
  apply min_eq_left
  have hgap : (L * (v - u) ^ 2 + L * (u ^ 2 - 1) * (v - 1)) / (v - 1) ^ 2
        - L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2)
      = L * v * ((u - 1) ^ 2 * (u + 1)) / (u * (v - 1) ^ 2) := by
    field_simp
    ring
  have hpos : 0 ≤ L * v * ((u - 1) ^ 2 * (u + 1)) / (u * (v - 1) ^ 2) := by
    have : 0 ≤ (u - 1) ^ 2 * (u + 1) := mul_nonneg (sq_nonneg _) (by linarith)
    exact div_nonneg (mul_nonneg (mul_nonneg hL.le hv0.le) this) (by positivity)
  linarith

end Up

/-! ### Downward excursion -/

section Down

variable {L s u v : ℝ}

/-- **Proposition 10, way out, downward.** At price s / u token1 binds, and
    the mint leaves liquidity `L (v - u) / (v - 1)`. -/
theorem excursion_down_out (hL : 0 < L) (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    min (L * (1 / (s / u) - 1 / (s * v)) / (1 / (s / u) - 1 / (s * v / u)))
        (L * (s / u - s / v) / (s / u - s / (u * v)))
      = L * (v - u) / (v - 1) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : 0 < u := by linarith
  have hv0 : 0 < v := by linarith
  have hv1 : 0 < v - 1 := by linarith
  have hu0' : u ≠ 0 := hu0.ne'
  have hv0' : v ≠ 0 := hv0.ne'
  have hv1' : v - 1 ≠ 0 := hv1.ne'
  have e0 : L * (1 / (s / u) - 1 / (s * v)) / (1 / (s / u) - 1 / (s * v / u))
      = L * (u * v - 1) / (u * (v - 1)) := by
    have a1 : 1 / (s / u) - 1 / (s * v) = (u * v - 1) / (s * v) := by field_simp
    have a2 : 1 / (s / u) - 1 / (s * v / u) = u * (v - 1) / (s * v) := by field_simp
    rw [a1, a2]
    field_simp
  have e1 : L * (s / u - s / v) / (s / u - s / (u * v)) = L * (v - u) / (v - 1) := by
    have b1 : s / u - s / v = s * (v - u) / (u * v) := by field_simp
    have b2 : s / u - s / (u * v) = s * (v - 1) / (u * v) := by field_simp
    rw [b1, b2]
    field_simp
  rw [e0, e1]
  apply min_eq_right
  rw [div_le_div_iff₀ hv1 (mul_pos hu0 hv1)]
  have key : L * (u * v - 1) * (v - 1) - L * (v - u) * (u * (v - 1))
      = L * (v - 1) * ((u - 1) * (u + 1)) := by ring
  have hpos : 0 ≤ L * (v - 1) * ((u - 1) * (u + 1)) := by
    have : 0 ≤ (u - 1) * (u + 1) := mul_nonneg (by linarith) (by linarith)
    exact mul_nonneg (mul_nonneg hL.le hv1.le) this
  linarith

/-- The token0 left over on the way out, `L (u² - 1) / (s v)`. -/
theorem excursion_down_leftover (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    L * (1 / (s / u) - 1 / (s * v))
        - L * (v - u) / (v - 1) * (1 / (s / u) - 1 / (s * v / u))
      = L * (u ^ 2 - 1) / (s * v) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : u ≠ 0 := by linarith
  have hv0 : v ≠ 0 := by linarith
  have hv1 : v - 1 ≠ 0 := by linarith
  have a1 : 1 / (s / u) - 1 / (s * v) = (u * v - 1) / (s * v) := by field_simp
  have a2 : 1 / (s / u) - 1 / (s * v / u) = u * (v - 1) / (s * v) := by field_simp
  rw [a1, a2]
  field_simp
  ring

/-- **Proposition 10, way back, downward.** With the token0 leftover
    retained, token1 binds again at the return mint, and the liquidity
    factor is the same as for the upward excursion. -/
theorem excursion_down_back (hL : 0 < L) (hs : 0 < s) (hu : 1 < u) (huv : u < v) :
    min ((L * (v - u) / (v - 1) * (1 / s - 1 / (s * v / u)) + L * (u ^ 2 - 1) / (s * v))
          / (1 / s - 1 / (s * v)))
        (L * (v - u) / (v - 1) * (s - s / (u * v)) / (s - s / v))
      = L * (1 - (u + 1 / u - 2) * v / (v - 1) ^ 2) := by
  have hs0 : s ≠ 0 := hs.ne'
  have hu0 : 0 < u := by linarith
  have hv0 : 0 < v := by linarith
  have hv1 : 0 < v - 1 := by linarith
  have hu0' : u ≠ 0 := hu0.ne'
  have hv0' : v ≠ 0 := hv0.ne'
  have hv1' : v - 1 ≠ 0 := hv1.ne'
  have e0 : (L * (v - u) / (v - 1) * (1 / s - 1 / (s * v / u)) + L * (u ^ 2 - 1) / (s * v))
        / (1 / s - 1 / (s * v))
      = (L * (v - u) ^ 2 + L * (u ^ 2 - 1) * (v - 1)) / (v - 1) ^ 2 := by
    have a1 : 1 / s - 1 / (s * v / u) = (v - u) / (s * v) := by field_simp
    have a2 : 1 / s - 1 / (s * v) = (v - 1) / (s * v) := by field_simp
    rw [a1, a2]
    field_simp
  have e1 : L * (v - u) / (v - 1) * (s - s / (u * v)) / (s - s / v)
      = L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2) := by
    have b1 : s - s / (u * v) = s * (u * v - 1) / (u * v) := by field_simp
    have b2 : s - s / v = s * (v - 1) / v := by field_simp
    rw [b1, b2]
    field_simp
  have e2 : L * (1 - (u + 1 / u - 2) * v / (v - 1) ^ 2)
      = L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2) := by
    field_simp
    ring
  rw [e0, e1, e2]
  apply min_eq_right
  have hgap : (L * (v - u) ^ 2 + L * (u ^ 2 - 1) * (v - 1)) / (v - 1) ^ 2
        - L * (v - u) * (u * v - 1) / (u * (v - 1) ^ 2)
      = L * v * ((u - 1) ^ 2 * (u + 1)) / (u * (v - 1) ^ 2) := by
    field_simp
    ring
  have hpos : 0 ≤ L * v * ((u - 1) ^ 2 * (u + 1)) / (u * (v - 1) ^ 2) := by
    have : 0 ≤ (u - 1) ^ 2 * (u + 1) := mul_nonneg (sq_nonneg _) (by linarith)
    exact div_nonneg (mul_nonneg (mul_nonneg hL.le hv0.le) this) (by positivity)
  linarith

end Down

/-! ### The hyperbolic forms -/

/-- The excursion factor in the paper's variables: with u = e^ℓ and
    v = e^h, `(u + 1/u - 2) v / (v - 1)² = sinh²(ℓ/2) / sinh²(h/2)`. -/
theorem excursion_factor_sinh (ℓ h : ℝ) (hh : h ≠ 0) :
    (Real.exp ℓ + 1 / Real.exp ℓ - 2) * Real.exp h / (Real.exp h - 1) ^ 2
      = Real.sinh (ℓ / 2) ^ 2 / Real.sinh (h / 2) ^ 2 := by
  rw [Real.sinh_eq, Real.sinh_eq]
  have hp : Real.exp ℓ = Real.exp (ℓ / 2) ^ 2 := by
    rw [← Real.exp_nat_mul]; congr 1; ring
  have hq : Real.exp h = Real.exp (h / 2) ^ 2 := by
    rw [← Real.exp_nat_mul]; congr 1; ring
  rw [hp, hq, Real.exp_neg, Real.exp_neg]
  have hp0 : Real.exp (ℓ / 2) ≠ 0 := (Real.exp_pos _).ne'
  have hq0 : Real.exp (h / 2) ≠ 0 := (Real.exp_pos _).ne'
  have hq1 : Real.exp (h / 2) ^ 2 - 1 ≠ 0 := by
    rw [← hq]
    intro hz
    have : Real.exp h = 1 := by linarith
    exact hh (Real.exp_eq_one_iff h |>.mp this)
  have hq2 : Real.exp (h / 2) - (Real.exp (h / 2))⁻¹ ≠ 0 := by
    intro hz
    apply hq1
    have : Real.exp (h / 2) = (Real.exp (h / 2))⁻¹ := by linarith
    have h2 : Real.exp (h / 2) * Real.exp (h / 2) = 1 := by
      nth_rewrite 2 [this]
      exact mul_inv_cancel₀ hq0
    nlinarith
  generalize Real.exp (ℓ / 2) = p at hp0 ⊢
  generalize Real.exp (h / 2) = q at hq0 hq1 hq2 ⊢
  have hq3 : q ^ 2 - 1 ≠ 0 := hq1
  have hq4 : q - q⁻¹ = (q ^ 2 - 1) / q := by field_simp
  rw [hq4]
  field_simp
  ring

/-- Remark after Corollary 4.1. Range [1/v, v] around 1, price at u with
    1 < u < v: the token0 and token1 values per unit liquidity are
    u (1 - u/v) and u - 1/v, and the zero-swap residual fraction of the
    recentred mint, their normalised gap, is (u - 1/u) / (2v - u - 1/u). -/
theorem tick_width_alpha {u v : ℝ} (hu : 1 < u) (huv : u < v) :
    ((u - 1 / v) - u * (1 - u / v)) / ((u - 1 / v) + u * (1 - u / v))
      = (u - 1 / u) / (2 * v - u - 1 / u) := by
  have hu0 : (0 : ℝ) < u := by linarith
  have hv0 : (0 : ℝ) < v := by linarith
  have key : 0 < 2 * u * v - u ^ 2 - 1 := by
    have h1 := mul_pos hu0 (sub_pos.mpr huv)
    have h2 := mul_pos (sub_pos.mpr hu) (by linarith : (0 : ℝ) < u + 1)
    nlinarith
  have h1 : (u - 1 / v) + u * (1 - u / v) ≠ 0 := by
    have e : (u - 1 / v) + u * (1 - u / v) = (2 * u * v - u ^ 2 - 1) / v := by
      field_simp; ring
    rw [e]; exact (div_pos key hv0).ne'
  have h2 : 2 * v - u - 1 / u ≠ 0 := by
    have e : 2 * v - u - 1 / u = (2 * u * v - u ^ 2 - 1) / u := by
      field_simp
    rw [e]; exact (div_pos key hu0).ne'
  rw [div_eq_div_iff h1 h2]
  field_simp
  ring

/-- The same fraction in the paper's variables: sinh ℓ / (e^h - cosh ℓ). -/
theorem tick_width_alpha_sinh (ℓ h : ℝ) :
    (Real.exp ℓ - 1 / Real.exp ℓ) / (2 * Real.exp h - Real.exp ℓ - 1 / Real.exp ℓ)
      = Real.sinh ℓ / (Real.exp h - Real.cosh ℓ) := by
  rw [Real.sinh_eq, Real.cosh_eq, Real.exp_neg, one_div]
  have e : Real.exp h - (Real.exp ℓ + (Real.exp ℓ)⁻¹) / 2
      = (2 * Real.exp h - Real.exp ℓ - (Real.exp ℓ)⁻¹) / 2 := by ring
  rw [e, div_div_div_cancel_right₀ (by norm_num : (2 : ℝ) ≠ 0)]

end GeometricSiphon
