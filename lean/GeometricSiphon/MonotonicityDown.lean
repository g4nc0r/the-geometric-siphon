/-
Corollary 4.1 (Downward displacement) of "The Geometric Siphon".

Setting (paper §3.7): the equal-width recentred rebalance of Theorem 4, with
the price displaced downwards from the midpoint, s = sbar - d with
0 ≤ d ≤ w/2. Old range [sbar - w/2, sbar + w/2], new range
[s - w/2, s + w/2].

For a downward displacement token1 is the binding constraint in the mint minimum and the
residual is surplus token0, valued at the current price:

  |ΔR(d)| = L d s (s + sb) / (sb sb'),    sb = sbar + w/2,  sb' = s + w/2.

The closed form for an upward displacement (`deltaR` in Monotonicity.lean) is not
the residual here. Its continuation to δ < 0 is a statement about that
rational function only.

Sign convention as in Monotonicity.lean: the quantity is the value
surrendered, V_old - V_new ≥ 0.

Hypothesis. The paper's condition sb < 3 sa is `w < sbar` in midpoint
coordinates. It makes the lower bound of the recentred range positive on
the whole range of displacement, and it is used for the monotonicity of the absolute
residual. The binding lemma, the closed form, the boundary value, the
comparison with the upward residual and the fraction results need only
`w / 2 < sbar`.

Also here: the residual as a fraction of position value in both directions
(`retUp`, `retDown` are the fractions of value redeployed), strictly
monotone in the displacement and equal to one at both boundaries.
-/
import GeometricSiphon.Monotonicity

set_option linter.style.header false

namespace GeometricSiphon

/-- Residual for a downward displacement, in midpoint coordinates, d = sbar - s ≥ 0:
    `L d s (s + sb) / (sb sb')` with s = sbar - d. -/
noncomputable def deltaRdown (L sbar w d : ℝ) : ℝ :=
  L * d * (sbar - d) * (2 * sbar + w / 2 - d)
    / ((sbar + w / 2) * (sbar + w / 2 - d))

/-- For 0 ≤ d < w/2 the token1 term is the binding constraint in the mint
    minimum. -/
theorem token1_binds_down (L sbar w d : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hd : 0 ≤ d) (hd' : d < w / 2) :
    Lnew L (sbar - d) (sbar - w / 2) (sbar + w / 2)
        ((sbar - d) - w / 2) ((sbar - d) + w / 2)
      = L * ((sbar - d) - (sbar - w / 2))
          / ((sbar - d) - ((sbar - d) - w / 2)) := by
  unfold Lnew
  apply min_eq_right
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hs : 0 < sbar - d := by linarith
  have hsw : 0 < sbar - d + u := by linarith
  have hsb : 0 < sbar + u := by linarith
  have hs' : sbar - d ≠ 0 := hs.ne'
  have hsw' : sbar - d + u ≠ 0 := hsw.ne'
  have hsb' : sbar + u ≠ 0 := hsb.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hnum : 1 / (sbar - d) - 1 / (sbar + u)
      = (u + d) / ((sbar - d) * (sbar + u)) := by
    field_simp; ring
  have hden : 1 / (sbar - d) - 1 / ((sbar - d) + u)
      = u / ((sbar - d) * ((sbar - d) + u)) := by
    field_simp; ring
  rw [hnum, hden,
    show (sbar - d) - ((sbar - d) - u) = u from by ring,
    show (sbar - d) - (sbar - u) = u - d from by ring]
  have hdiff : L * ((u + d) / ((sbar - d) * (sbar + u)))
          / (u / ((sbar - d) * ((sbar - d) + u)))
        - L * (u - d) / u
      = L * (d * (2 * sbar + u - d)) / (u * (sbar + u)) := by
    rw [div_div_eq_mul_div]
    field_simp
    ring
  have hpos : 0 ≤ L * (d * (2 * sbar + u - d)) / (u * (sbar + u)) := by
    have hb : 0 ≤ d * (2 * sbar + u - d) := mul_nonneg hd (by linarith)
    exact div_nonneg (mul_nonneg hL.le hb) (by positivity)
  linarith [hdiff, hpos]

/-- The downward closed form is the value surrendered: V_old - V_new, with
    V_new = Lnew · φ(new range) from the Theorem 1 development. -/
theorem deltaRdown_eq_value_loss (L sbar w d : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hd : 0 ≤ d) (hd' : d < w / 2) :
    L * phi (sbar - d) (sbar - w / 2) (sbar + w / 2)
        - Lnew L (sbar - d) (sbar - w / 2) (sbar + w / 2)
            ((sbar - d) - w / 2) ((sbar - d) + w / 2)
          * phi (sbar - d) ((sbar - d) - w / 2) ((sbar - d) + w / 2)
      = deltaRdown L sbar w d := by
  rw [token1_binds_down L sbar w d hL hw hmid hd hd']
  unfold deltaRdown phi
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hsw' : sbar - d + u ≠ 0 := by
    have : 0 < sbar - d + u := by linarith
    exact this.ne'
  have hsw'' : sbar + u - d ≠ 0 := by
    have : 0 < sbar + u - d := by linarith
    exact this.ne'
  have hsb' : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have hu' : u ≠ 0 := hu0.ne'
  rw [show (sbar - d) - ((sbar - d) - u) = u from by ring,
    show (sbar - d) - (sbar - u) = u - d from by ring]
  field_simp
  ring

/-- No displacement, no residual. -/
theorem deltaRdown_zero (L sbar w : ℝ) : deltaRdown L sbar w 0 = 0 := by
  unfold deltaRdown; simp

/-- Downward boundary value: `L w sa / sb` with sa = sbar - w/2 and
    sb = sbar + w/2. -/
theorem deltaRdown_boundary (L sbar w : ℝ) (hw : 0 < w) (hmid : w / 2 < sbar) :
    deltaRdown L sbar w (w / 2) = L * w * (sbar - w / 2) / (sbar + w / 2) := by
  rw [show L * w * (sbar - w / 2) = L * (2 * (w / 2)) * (sbar - w / 2) from by ring]
  unfold deltaRdown
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hsb' : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have hm' : sbar ≠ 0 := by
    have : 0 < sbar := by linarith
    exact this.ne'
  rw [show sbar + u - u = sbar from by ring]
  field_simp
  ring

/-- **Corollary 4.1, monotone core.** Under `w < sbar` (the paper's
    sb < 3 sa) the downward residual is strictly increasing in the
    displacement on [0, w/2]. -/
theorem deltaRdown_strictMono (L sbar w d₁ d₂ : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hadm : w < sbar)
    (h₁ : 0 ≤ d₁) (h₂ : d₂ ≤ w / 2) (h₁₂ : d₁ < d₂) :
    deltaRdown L sbar w d₁ < deltaRdown L sbar w d₂ := by
  unfold deltaRdown
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hm2 : 2 * u < sbar := by rw [hu]; linarith
  set t₁ : ℝ := sbar + u - d₁ with ht₁
  set t₂ : ℝ := sbar + u - d₂ with ht₂
  have ht₂m : sbar ≤ t₂ := by rw [ht₂]; linarith
  have ht₁m : sbar ≤ t₁ := by rw [ht₁]; linarith
  have hm0 : 0 < sbar := by linarith
  have ht₁0 : 0 < t₁ := by linarith
  have ht₂0 : 0 < t₂ := by linarith
  have hsb : 0 < sbar + u := by linarith
  -- the difference in factored form
  have hdiff : L * d₂ * (sbar - d₂) * (2 * sbar + u - d₂) / ((sbar + u) * t₂)
        - L * d₁ * (sbar - d₁) * (2 * sbar + u - d₁) / ((sbar + u) * t₁)
      = L * (d₂ - d₁) * (t₁ * t₂ * (t₁ + t₂ - 2 * u) - u * sbar * (sbar + u))
          / ((sbar + u) * t₁ * t₂) := by
    rw [ht₁, ht₂]
    have e₁ : sbar + u - d₁ ≠ 0 := by rw [← ht₁]; exact ht₁0.ne'
    have e₂ : sbar + u - d₂ ≠ 0 := by rw [← ht₂]; exact ht₂0.ne'
    have e₃ : sbar + u ≠ 0 := hsb.ne'
    field_simp
    ring
  have hprod : sbar * sbar ≤ t₁ * t₂ :=
    mul_le_mul ht₁m ht₂m hm0.le ht₁0.le
  have hsum : 2 * sbar - 2 * u ≤ t₁ + t₂ - 2 * u := by linarith
  have hsum0 : 0 ≤ 2 * sbar - 2 * u := by linarith
  have hbig : sbar * sbar * (2 * sbar - 2 * u) ≤ t₁ * t₂ * (t₁ + t₂ - 2 * u) :=
    mul_le_mul hprod hsum hsum0 (by positivity)
  have hcore : 0 < sbar * sbar * (2 * sbar - 2 * u) - u * sbar * (sbar + u) := by
    have h1 : 0 < sbar * (sbar - 2 * u) := mul_pos hm0 (by linarith)
    have h2 : 0 < u * (sbar - 2 * u) := mul_pos hu0 (by linarith)
    have h3 : 0 < sbar * (sbar * (sbar - 2 * u)) := mul_pos hm0 h1
    nlinarith [mul_pos hm0 h2, mul_pos hm0 (mul_pos hu0 hu0), h3]
  have hnum : 0 < t₁ * t₂ * (t₁ + t₂ - 2 * u) - u * sbar * (sbar + u) := by
    linarith
  have hpos : 0 < L * (d₂ - d₁) * (t₁ * t₂ * (t₁ + t₂ - 2 * u) - u * sbar * (sbar + u))
      / ((sbar + u) * t₁ * t₂) :=
    div_pos (mul_pos (mul_pos hL (by linarith)) hnum) (by positivity)
  linarith [hdiff, hpos]

/-- At equal displacement the downward residual is the smaller. -/
theorem deltaRdown_lt_up (L sbar w d : ℝ)
    (hL : 0 < L) (_hw : 0 < w) (hmid : w / 2 < sbar)
    (hd : 0 < d) (hd' : d ≤ w / 2) :
    deltaRdown L sbar w d < deltaR L sbar w d := by
  unfold deltaRdown deltaR
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hsb : 0 < sbar + u := by linarith
  have ht : 0 < sbar + u - d := by linarith
  have hdiff : L * d * (2 * sbar + u + d) / (sbar + u)
        - L * d * (sbar - d) * (2 * sbar + u - d) / ((sbar + u) * (sbar + u - d))
      = L * d * (u * (2 * sbar + u - d) + 2 * d * (sbar + u - d))
          / ((sbar + u) * (sbar + u - d)) := by
    have e₁ : sbar + u - d ≠ 0 := ht.ne'
    have e₃ : sbar + u ≠ 0 := hsb.ne'
    field_simp
    ring
  have hnum : 0 < u * (2 * sbar + u - d) + 2 * d * (sbar + u - d) := by
    have h1 : 0 < u * (2 * sbar + u - d) := mul_pos hu0 (by linarith)
    have h2 : 0 < 2 * d * (sbar + u - d) := mul_pos (by linarith) ht
    linarith
  have hpos : 0 < L * d * (u * (2 * sbar + u - d) + 2 * d * (sbar + u - d))
      / ((sbar + u) * (sbar + u - d)) :=
    div_pos (mul_pos (mul_pos hL hd) hnum) (by positivity)
  linarith [hdiff, hpos]

/-- The ratio of the downward to the upward residual at equal displacement, as an exact
    identity. At d = 0 the factor is sbar / sb. -/
theorem deltaRdown_eq_up_mul (L sbar w d : ℝ)
    (hw : 0 < w) (hmid : w / 2 < sbar) (hd : 0 ≤ d) (hd' : d ≤ w / 2) :
    deltaRdown L sbar w d
      = deltaR L sbar w d
          * ((sbar - d) * (2 * sbar + w / 2 - d)
              / ((sbar + w / 2 - d) * (2 * sbar + w / 2 + d))) := by
  unfold deltaRdown deltaR
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have e₁ : sbar + u - d ≠ 0 := by
    have : 0 < sbar + u - d := by linarith
    exact this.ne'
  have e₂ : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have e₃ : 2 * sbar + u + d ≠ 0 := by
    have : 0 < 2 * sbar + u + d := by linarith
    exact this.ne'
  rw [div_mul_div_comm, div_eq_div_iff (mul_ne_zero e₂ e₁)
    (mul_ne_zero e₂ (mul_ne_zero e₁ e₃))]
  ring

/-! ### The residual as a fraction of position value

`retUp` and `retDown` are the fractions of the position's value that the
recentred mint redeploys, V_new / V_old, for the two directions. The residual
fraction is one minus these. -/

/-- Fraction of value redeployed, upward displacement, δ ≥ 0. -/
noncomputable def retUp (sbar w δ : ℝ) : ℝ :=
  (w / 2 - δ) * (2 * sbar + 2 * δ + w / 2)
    / (2 * sbar * (w / 2) + (w / 2) ^ 2 + 2 * δ * (w / 2) - δ ^ 2)

/-- Fraction of value redeployed, downward displacement, d ≥ 0. -/
noncomputable def retDown (sbar w d : ℝ) : ℝ :=
  (w / 2 - d) * (sbar + w / 2) * (2 * sbar - 2 * d + w / 2)
    / ((sbar + w / 2 - d)
        * (2 * sbar * (w / 2) + (w / 2) ^ 2 - 2 * d * (w / 2) - d ^ 2))

/-- `retUp` is V_new / V_old for an upward displacement. -/
theorem retUp_eq (L sbar w δ : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hδ : 0 ≤ δ) (hδ' : δ < w / 2) :
    Lnew L (sbar + δ) (sbar - w / 2) (sbar + w / 2)
          ((sbar + δ) - w / 2) ((sbar + δ) + w / 2)
        * phi (sbar + δ) ((sbar + δ) - w / 2) ((sbar + δ) + w / 2)
      = L * phi (sbar + δ) (sbar - w / 2) (sbar + w / 2) * retUp sbar w δ := by
  rw [token0_binds L sbar w δ hL hw hmid hδ hδ']
  unfold retUp phi
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hs' : sbar + δ ≠ 0 := by
    have : 0 < sbar + δ := by linarith
    exact this.ne'
  have hsw' : sbar + δ + u ≠ 0 := by
    have : 0 < sbar + δ + u := by linarith
    exact this.ne'
  have hsb' : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hD : 2 * sbar * u + u ^ 2 + 2 * δ * u - δ ^ 2 ≠ 0 := by
    have : 0 < 2 * sbar * u + u ^ 2 + 2 * δ * u - δ ^ 2 := by
      nlinarith [mul_pos hu0 (show 0 < sbar by linarith), mul_nonneg hδ hu0.le,
        mul_nonneg hδ (show 0 ≤ u - δ by linarith)]
    exact this.ne'
  have hnum : 1 / (sbar + δ) - 1 / (sbar + u)
      = (u - δ) / ((sbar + δ) * (sbar + u)) := by
    field_simp; ring
  have hden : 1 / (sbar + δ) - 1 / ((sbar + δ) + u)
      = u / ((sbar + δ) * ((sbar + δ) + u)) := by
    field_simp; ring
  rw [hnum, hden, div_div_eq_mul_div]
  conv_rhs => rw [← mul_div_assoc]
  rw [eq_div_iff hD]
  field_simp
  ring

/-- `retDown` is V_new / V_old for a downward displacement. -/
theorem retDown_eq (L sbar w d : ℝ)
    (hL : 0 < L) (hw : 0 < w) (hmid : w / 2 < sbar)
    (hd : 0 ≤ d) (hd' : d < w / 2) :
    Lnew L (sbar - d) (sbar - w / 2) (sbar + w / 2)
          ((sbar - d) - w / 2) ((sbar - d) + w / 2)
        * phi (sbar - d) ((sbar - d) - w / 2) ((sbar - d) + w / 2)
      = L * phi (sbar - d) (sbar - w / 2) (sbar + w / 2) * retDown sbar w d := by
  rw [token1_binds_down L sbar w d hL hw hmid hd hd']
  unfold retDown phi
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hsw' : sbar - d + u ≠ 0 := by
    have : 0 < sbar - d + u := by linarith
    exact this.ne'
  have hsw'' : sbar + u - d ≠ 0 := by
    have : 0 < sbar + u - d := by linarith
    exact this.ne'
  have hsb' : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have hu' : u ≠ 0 := hu0.ne'
  have hD : 2 * sbar * u + u ^ 2 - 2 * d * u - d ^ 2 ≠ 0 := by
    have : 0 < 2 * sbar * u + u ^ 2 - 2 * d * u - d ^ 2 := by
      nlinarith [mul_pos hu0 (show 0 < sbar - u by linarith),
        mul_nonneg hd (show 0 ≤ u - d by linarith),
        mul_pos hu0 (show 0 < u - d by linarith)]
    exact this.ne'
  rw [show (sbar - d) - ((sbar - d) - u) = u from by ring,
    show (sbar - d) - (sbar - u) = u - d from by ring]
  conv_rhs => rw [← mul_div_assoc]
  rw [eq_div_iff (mul_ne_zero hsw'' hD)]
  field_simp
  ring

/-- The whole position is residual at the upward boundary. -/
theorem retUp_boundary (sbar w : ℝ) : retUp sbar w (w / 2) = 0 := by
  unfold retUp; simp

/-- The whole position is residual at the downward boundary. -/
theorem retDown_boundary (sbar w : ℝ) : retDown sbar w (w / 2) = 0 := by
  unfold retDown; simp

/-- Nothing is residual at zero displacement, upward form. -/
theorem retUp_zero (sbar w : ℝ) (hw : 0 < w) (hmid : w / 2 < sbar) :
    retUp sbar w 0 = 1 := by
  unfold retUp
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have h : 2 * sbar + u ≠ 0 := by
    have : 0 < 2 * sbar + u := by linarith
    exact this.ne'
  have hu' : u ≠ 0 := hu0.ne'
  rw [div_eq_one_iff_eq (by
    rw [show 2 * sbar * u + u ^ 2 + 2 * 0 * u - 0 ^ 2 = u * (2 * sbar + u) from by ring]
    exact mul_ne_zero hu' h)]
  ring

/-- Nothing is residual at zero displacement, downward form. -/
theorem retDown_zero (sbar w : ℝ) (hw : 0 < w) (hmid : w / 2 < sbar) :
    retDown sbar w 0 = 1 := by
  unfold retDown
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have h : 2 * sbar + u ≠ 0 := by
    have : 0 < 2 * sbar + u := by linarith
    exact this.ne'
  have h' : sbar + u ≠ 0 := by
    have : 0 < sbar + u := by linarith
    exact this.ne'
  have hu' : u ≠ 0 := hu0.ne'
  rw [div_eq_one_iff_eq (by
    rw [show (sbar + u - 0) * (2 * sbar * u + u ^ 2 - 2 * 0 * u - 0 ^ 2)
      = (sbar + u) * (u * (2 * sbar + u)) from by ring]
    exact mul_ne_zero h' (mul_ne_zero hu' h))]
  ring

/-- The residual fraction is strictly increasing in the displacement on the
    upward side: the fraction redeployed is strictly decreasing. -/
theorem retUp_strictAnti (sbar w δ₁ δ₂ : ℝ)
    (hw : 0 < w) (hmid : w / 2 < sbar)
    (h₁ : 0 ≤ δ₁) (h₂ : δ₂ ≤ w / 2) (h₁₂ : δ₁ < δ₂) :
    retUp sbar w δ₂ < retUp sbar w δ₁ := by
  unfold retUp
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hm0 : 0 < sbar := by linarith
  have hD₁ : 0 < 2 * sbar * u + u ^ 2 + 2 * δ₁ * u - δ₁ ^ 2 := by
    nlinarith [mul_pos hu0 hm0, mul_nonneg h₁ hu0.le,
      mul_nonneg h₁ (show 0 ≤ u - δ₁ by linarith)]
  have hD₂ : 0 < 2 * sbar * u + u ^ 2 + 2 * δ₂ * u - δ₂ ^ 2 := by
    nlinarith [mul_pos hu0 hm0, mul_nonneg (show 0 ≤ δ₂ by linarith) hu0.le,
      mul_nonneg (show 0 ≤ δ₂ by linarith) (show 0 ≤ u - δ₂ by linarith)]
  have hdiff : (u - δ₁) * (2 * sbar + 2 * δ₁ + u)
          / (2 * sbar * u + u ^ 2 + 2 * δ₁ * u - δ₁ ^ 2)
        - (u - δ₂) * (2 * sbar + 2 * δ₂ + u)
          / (2 * sbar * u + u ^ 2 + 2 * δ₂ * u - δ₂ ^ 2)
      = (δ₂ - δ₁) * (2 * δ₁ * δ₂ * sbar + 3 * δ₁ * δ₂ * u + 2 * δ₁ * sbar * u
            + δ₁ * u ^ 2 + 2 * δ₂ * sbar * u + δ₂ * u ^ 2 + 4 * sbar ^ 2 * u
            + 4 * sbar * u ^ 2 + u ^ 3)
          / ((2 * sbar * u + u ^ 2 + 2 * δ₁ * u - δ₁ ^ 2)
              * (2 * sbar * u + u ^ 2 + 2 * δ₂ * u - δ₂ ^ 2)) := by
    have e₁ := hD₁.ne'
    have e₂ := hD₂.ne'
    rw [div_sub_div _ _ e₁ e₂, div_eq_div_iff (mul_ne_zero e₁ e₂) (mul_ne_zero e₁ e₂)]
    ring
  have hδ₂0 : 0 < δ₂ := by linarith
  have hnum : 0 < 2 * δ₁ * δ₂ * sbar + 3 * δ₁ * δ₂ * u + 2 * δ₁ * sbar * u
      + δ₁ * u ^ 2 + 2 * δ₂ * sbar * u + δ₂ * u ^ 2 + 4 * sbar ^ 2 * u
      + 4 * sbar * u ^ 2 + u ^ 3 := by
    have a1 : 0 ≤ 2 * δ₁ * δ₂ * sbar := by positivity
    have a2 : 0 ≤ 3 * δ₁ * δ₂ * u := by positivity
    have a3 : 0 ≤ 2 * δ₁ * sbar * u := by positivity
    have a4 : 0 ≤ δ₁ * u ^ 2 := by positivity
    have a5 : 0 < 2 * δ₂ * sbar * u := by positivity
    have a6 : 0 < δ₂ * u ^ 2 := by positivity
    have a7 : 0 < 4 * sbar ^ 2 * u := by positivity
    have a8 : 0 < 4 * sbar * u ^ 2 := by positivity
    have a9 : 0 < u ^ 3 := by positivity
    linarith
  have hpos := div_pos (mul_pos (show 0 < δ₂ - δ₁ by linarith) hnum) (mul_pos hD₁ hD₂)
  linarith [hdiff, hpos]

/-- The residual fraction is strictly increasing in the displacement on the
    downward side: the fraction redeployed is strictly decreasing. -/
theorem retDown_strictAnti (sbar w d₁ d₂ : ℝ)
    (_hw : 0 < w) (hmid : w / 2 < sbar)
    (h₁ : 0 ≤ d₁) (h₂ : d₂ ≤ w / 2) (h₁₂ : d₁ < d₂) :
    retDown sbar w d₂ < retDown sbar w d₁ := by
  unfold retDown
  set u : ℝ := w / 2 with hu
  have hu0 : 0 < u := by rw [hu]; linarith
  have hm0 : 0 < sbar := by linarith
  have hmu : 0 < sbar - u := by linarith
  have hd₂0 : 0 < d₂ := by linarith
  have hsb : 0 < sbar + u := by linarith
  have ht₁ : 0 < sbar + u - d₁ := by linarith
  have ht₂ : 0 < sbar + u - d₂ := by linarith
  have hD₁ : 0 < 2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2 := by
    nlinarith [mul_pos hu0 hmu, mul_nonneg h₁ (show 0 ≤ u - d₁ by linarith),
      mul_pos hu0 (show 0 < u - d₁ by linarith)]
  have hD₂ : 0 < 2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2 := by
    nlinarith [mul_pos hu0 hmu, mul_nonneg hd₂0.le (show 0 ≤ u - d₂ by linarith),
      mul_nonneg hu0.le (show 0 ≤ u - d₂ by linarith)]
  -- retDown = (sbar + u) * A * B with A, B positive and decreasing
  have hA : (2 * sbar - 2 * d₂ + u) / (sbar + u - d₂)
      < (2 * sbar - 2 * d₁ + u) / (sbar + u - d₁) := by
    rw [div_lt_div_iff₀ ht₂ ht₁]
    nlinarith [mul_pos hu0 (show 0 < d₂ - d₁ by linarith)]
  have hA0 : 0 < (2 * sbar - 2 * d₂ + u) / (sbar + u - d₂) :=
    div_pos (by linarith) ht₂
  have hB : (u - d₂) / (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2)
      ≤ (u - d₁) / (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2) := by
    rw [div_le_div_iff₀ hD₂ hD₁]
    have key : (u - d₁) * (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2)
        - (u - d₂) * (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2)
        = (d₂ - d₁) * (2 * sbar * u - u ^ 2 - u * d₁ - d₂ * (u - d₁)) := by ring
    have hbr : 0 ≤ 2 * sbar * u - u ^ 2 - u * d₁ - d₂ * (u - d₁) := by
      nlinarith [mul_pos hu0 hmu,
        mul_nonneg (show 0 ≤ u - d₂ by linarith) (show 0 ≤ u - d₁ by linarith)]
    nlinarith [mul_nonneg (show 0 ≤ d₂ - d₁ by linarith) hbr]
  have hB0 : 0 < (u - d₁) / (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2) :=
    div_pos (by linarith) hD₁
  have hB0' : 0 ≤ (u - d₂) / (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2) :=
    div_nonneg (by linarith) hD₂.le
  have hprod : (2 * sbar - 2 * d₂ + u) / (sbar + u - d₂)
        * ((u - d₂) / (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2))
      < (2 * sbar - 2 * d₁ + u) / (sbar + u - d₁)
        * ((u - d₁) / (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2)) :=
    by
      by_cases hz : (u - d₂) / (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2) = 0
      · rw [hz, mul_zero]; exact mul_pos (lt_trans hA0 hA) hB0
      · exact mul_lt_mul hA hB (lt_of_le_of_ne hB0' (Ne.symm hz)) (le_of_lt (lt_trans hA0 hA))
  have e₁ : (u - d₁) * (sbar + u) * (2 * sbar - 2 * d₁ + u)
        / ((sbar + u - d₁) * (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2))
      = (sbar + u) * ((2 * sbar - 2 * d₁ + u) / (sbar + u - d₁)
        * ((u - d₁) / (2 * sbar * u + u ^ 2 - 2 * d₁ * u - d₁ ^ 2))) := by
    rw [div_mul_div_comm, div_eq_iff (mul_ne_zero ht₁.ne' hD₁.ne'), mul_assoc (sbar + u),
      div_mul_cancel₀ _ (mul_ne_zero ht₁.ne' hD₁.ne')]
    ring
  have e₂ : (u - d₂) * (sbar + u) * (2 * sbar - 2 * d₂ + u)
        / ((sbar + u - d₂) * (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2))
      = (sbar + u) * ((2 * sbar - 2 * d₂ + u) / (sbar + u - d₂)
        * ((u - d₂) / (2 * sbar * u + u ^ 2 - 2 * d₂ * u - d₂ ^ 2))) := by
    rw [div_mul_div_comm, div_eq_iff (mul_ne_zero ht₂.ne' hD₂.ne'), mul_assoc (sbar + u),
      div_mul_cancel₀ _ (mul_ne_zero ht₂.ne' hD₂.ne')]
    ring
  rw [e₁, e₂]
  exact mul_lt_mul_of_pos_left hprod hsb

end GeometricSiphon
