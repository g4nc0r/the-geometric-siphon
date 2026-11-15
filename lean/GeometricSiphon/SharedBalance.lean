/-
Shared-balance results of "The Geometric Siphon": Corollary 3.1
(Irreversibility of zero-swap extinction), Proposition 11 (Netting) with
the two facts behind Corollary 11.1 (Shared tokens), and Proposition 12
(Neutral accounting) with Corollary 12.1 (Uniqueness).

Models. These statements are about accounting, and each section declares
the model it is proved in.

Corollary 3.1. A position withdraws amounts (x, y) worth V = s²x + y and
mints from them and from dust (dx, dy) into a range with per-liquidity
amounts (a', b'), by the mint minimum of the paper's eq. (mint). Deploying
at least V requires the dust to hold the position's shortfall of each
token.

Proposition 11. Positions i and tokens k, with z i k the value mismatch of
position i in token k (positive in surplus, negative when missing). A swap
plan sells σ k ≥ 0 and buys β k ≥ 0 of token k outside the shared balance,
and must change the aggregate holding of token k by -∑ i, z i k. The least
total sold is ∑ k (∑ i, z i k)⁺, and the saving over swapping alone is
∑ k min (∑ i (z i k)⁺) (∑ i (z i k)⁻).

Proposition 12. Position j has deployed value V j and entitlement G j. A
rebalance with slippage S and ownerless mint M deploys min M (V j + G j - S)
and sets G j to the remainder of the equity. Other positions are untouched.
-/
import GeometricSiphon.Defs

set_option linter.style.header false

namespace GeometricSiphon

open Finset

/-! ### Corollary 3.1 -/

section Recovery

variable {s x y dx dy a' b' : ℝ}

/-- **Corollary 3.1.** If the mint from withdrawn amounts and dust deploys
    at least the withdrawn value, the dust holds at least the position's
    shortfall of each token at that value. -/
theorem recovery_needs_dust (hs : s ≠ 0) (ha' : 0 < a') (hb' : 0 < b')
    (h : s ^ 2 * x + y ≤ min ((x + dx) / a') ((y + dy) / b') * (s ^ 2 * a' + b')) :
    (s ^ 2 * x + y) / (s ^ 2 * a' + b') * a' - x ≤ dx
      ∧ (s ^ 2 * x + y) / (s ^ 2 * a' + b') * b' - y ≤ dy := by
  have hs2 : (0:ℝ) < s ^ 2 := by positivity
  have hP : (0:ℝ) < s ^ 2 * a' + b' := by positivity
  have hm : (s ^ 2 * x + y) / (s ^ 2 * a' + b') ≤ min ((x + dx) / a') ((y + dy) / b') := by
    rw [div_le_iff₀ hP]; exact h
  constructor
  · have h1 := le_trans hm (min_le_left _ _)
    have h2 := mul_le_mul_of_nonneg_right h1 ha'.le
    rw [div_mul_cancel₀ _ ha'.ne'] at h2
    linarith
  · have h1 := le_trans hm (min_le_right _ _)
    have h2 := mul_le_mul_of_nonneg_right h1 hb'.le
    rw [div_mul_cancel₀ _ hb'.ne'] at h2
    linarith

/-- With no dust the mint never deploys more than the withdrawn value. -/
theorem isolated_no_gain (ha' : 0 < a') (hb' : 0 < b') :
    min (x / a') (y / b') * (s ^ 2 * a' + b') ≤ s ^ 2 * x + y := by
  have h1 : min (x / a') (y / b') * a' ≤ x := by
    calc min (x / a') (y / b') * a' ≤ x / a' * a' :=
          mul_le_mul_of_nonneg_right (min_le_left _ _) ha'.le
      _ = x := div_mul_cancel₀ x ha'.ne'
  have h2 : min (x / a') (y / b') * b' ≤ y := by
    calc min (x / a') (y / b') * b' ≤ y / b' * b' :=
          mul_le_mul_of_nonneg_right (min_le_right _ _) hb'.le
      _ = y := div_mul_cancel₀ y hb'.ne'
  nlinarith [mul_le_mul_of_nonneg_left h1 (sq_nonneg s)]

end Recovery

/-! ### Proposition 11 (Netting) -/

section Netting

variable {ι κ : Type*} [Fintype ι]

/-- **Proposition 11, lower bound.** Any swap plan that changes the
    aggregate holding of each token by minus its aggregate mismatch sells
    at least the aggregate surpluses. -/
theorem netting_lower_bound [Fintype κ] (z : ι → κ → ℝ) (σ β : κ → ℝ)
    (hσ : ∀ k, 0 ≤ σ k) (hβ : ∀ k, 0 ≤ β k)
    (hplan : ∀ k, σ k - β k = ∑ i, z i k) :
    ∑ k, max (∑ i, z i k) 0 ≤ ∑ k, σ k := by
  apply Finset.sum_le_sum
  intro k _
  apply max_le
  · rw [← hplan k]; linarith [hβ k]
  · exact hσ k

/-- **Proposition 11, attainment.** Selling the aggregate surpluses for the
    aggregate missing amounts is a plan, and it meets the bound. -/
theorem netting_attained (z : ι → κ → ℝ) :
    (∀ k, max (∑ i, z i k) 0 - max (-(∑ i, z i k)) 0 = ∑ i, z i k)
      ∧ (∀ k, 0 ≤ max (∑ i, z i k) 0) ∧ (∀ k, 0 ≤ max (-(∑ i, z i k)) 0) := by
  refine ⟨fun k => ?_, fun k => le_max_right _ _, fun k => le_max_right _ _⟩
  rcases le_total (∑ i, z i k) 0 with h | h
  · rw [max_eq_right h, max_eq_left (by linarith)]; ring
  · rw [max_eq_left h, max_eq_right (by linarith)]; ring

/-- A real number is its positive part less its negative part. -/
private lemma pos_sub_neg (a : ℝ) : max a 0 - max (-a) 0 = a := by
  rcases le_total a 0 with h | h
  · rw [max_eq_right h, max_eq_left (by linarith)]; ring
  · rw [max_eq_left h, max_eq_right (by linarith)]; ring

/-- **Proposition 11, saving.** Per token, the saving over each position
    swapping alone is the smaller of the total surplus and the total
    missing amount. -/
theorem netting_saving (z : ι → κ → ℝ) (k : κ) :
    ∑ i, max (z i k) 0 - max (∑ i, z i k) 0
      = min (∑ i, max (z i k) 0) (∑ i, max (-(z i k)) 0) := by
  have hsum : ∑ i, z i k = ∑ i, max (z i k) 0 - ∑ i, max (-(z i k)) 0 := by
    rw [← Finset.sum_sub_distrib]
    exact Finset.sum_congr rfl (fun i _ => (pos_sub_neg (z i k)).symm)
  rw [hsum]
  generalize ∑ i, max (z i k) 0 = P
  generalize ∑ i, max (-(z i k)) 0 = N
  rcases le_total P N with h | h
  · rw [min_eq_left h, max_eq_right (by linarith)]; ring
  · rw [min_eq_right h, max_eq_left (by linarith)]; ring

/-- **Proposition 11, when the saving is positive.** A token contributes to
    the saving exactly when it is the surplus token of one position and the
    missing token of another. -/
theorem netting_saving_pos_iff (z : ι → κ → ℝ) (k : κ) :
    0 < min (∑ i, max (z i k) 0) (∑ i, max (-(z i k)) 0)
      ↔ (∃ i, 0 < z i k) ∧ (∃ i, z i k < 0) := by
  have hP : 0 < ∑ i, max (z i k) 0 ↔ ∃ i, 0 < z i k := by
    rw [Finset.sum_pos_iff_of_nonneg (fun i _ => le_max_right _ _)]
    constructor
    · rintro ⟨i, -, hi⟩
      refine ⟨i, ?_⟩
      rcases lt_max_iff.mp hi with h | h
      · exact h
      · exact absurd h (lt_irrefl _)
    · rintro ⟨i, hi⟩
      exact ⟨i, Finset.mem_univ _, lt_max_of_lt_left hi⟩
  have hN : 0 < ∑ i, max (-(z i k)) 0 ↔ ∃ i, z i k < 0 := by
    rw [Finset.sum_pos_iff_of_nonneg (fun i _ => le_max_right _ _)]
    constructor
    · rintro ⟨i, -, hi⟩
      refine ⟨i, ?_⟩
      rcases lt_max_iff.mp hi with h | h
      · linarith
      · exact absurd h (lt_irrefl _)
    · rintro ⟨i, hi⟩
      exact ⟨i, Finset.mem_univ _, lt_max_of_lt_left (by linarith)⟩
  rw [lt_min_iff, hP, hN]

end Netting

/-! ### Corollary 11.1, the composition of a centred position

A range centred on s in tick space is [s/v, s v]. At sqrt price s u the
position holds, per unit of liquidity, token0 worth s u (v - u) / v and
token1 worth s (u v - 1) / v in token1 units. -/

section Centred

variable {s u v : ℝ}

/-- Token0 value less token1 value of a tick-centred position after the
    sqrt price has moved from s to s u. -/
theorem centred_value_gap (hs : 0 < s) (hu : 0 < u) (hv : 0 < v) :
    (s * u) ^ 2 * (1 / (s * u) - 1 / (s * v)) - (s * u - s / v)
      = s * (1 - u ^ 2) / v := by
  have hs0 := hs.ne'
  have hu0 := hu.ne'
  have hv0 := hv.ne'
  field_simp
  ring

/-- **Corollary 11.1, missing token.** After token0 has risen against
    token1 (u > 1) the position holds less than half its value in token0,
    so token0 is the missing token of a recentring. -/
theorem centred_token0_missing (hs : 0 < s) (hu : 1 < u) (hv : 0 < v) :
    (s * u) ^ 2 * (1 / (s * u) - 1 / (s * v)) < s * u - s / v := by
  have h := centred_value_gap hs (by linarith : 0 < u) hv
  have hneg : s * (1 - u ^ 2) / v < 0 := by
    apply div_neg_of_neg_of_pos _ hv
    have : 1 - u ^ 2 < 0 := by nlinarith
    nlinarith
  linarith

/-- After token0 has fallen against token1 (u < 1) token1 is the missing
    token. -/
theorem centred_token1_missing (hs : 0 < s) (hu : 0 < u) (hu1 : u < 1) (hv : 0 < v) :
    s * u - s / v < (s * u) ^ 2 * (1 / (s * u) - 1 / (s * v)) := by
  have h := centred_value_gap hs hu hv
  have hpos : 0 < s * (1 - u ^ 2) / v := by
    apply div_pos _ hv
    have : 0 < 1 - u ^ 2 := by nlinarith
    exact mul_pos hs this
  linarith

end Centred

/-! ### Proposition 12 (Neutral accounting) and Corollary 12.1 -/

section Neutral

variable {ι : Type*} [DecidableEq ι]

/-- Value minted by position j under the neutral rule: the lesser of the
    ownerless mint M and the position's equity after its own slippage. -/
noncomputable def neutralMint (V G : ι → ℝ) (j : ι) (S M : ℝ) : ℝ :=
  min M (V j + G j - S)

/-- Entitlements after position j rebalances under the neutral rule. -/
noncomputable def neutralEntitlement (V G : ι → ℝ) (j : ι) (S M : ℝ) : ι → ℝ :=
  Function.update G j (V j + G j - S - neutralMint V G j S M)

/-- **Proposition 12, own equity.** The rebalancing position's equity falls
    by its own slippage and by nothing else. -/
theorem neutral_own_equity (V G : ι → ℝ) (j : ι) (S M : ℝ) :
    neutralMint V G j S M + neutralEntitlement V G j S M j = V j + G j - S := by
  simp [neutralEntitlement]

/-- **Proposition 12, other positions.** No other entitlement changes. -/
theorem neutral_others (V G : ι → ℝ) (j : ι) (S M : ℝ) (i : ι) (hi : i ≠ j) :
    neutralEntitlement V G j S M i = G i := by
  simp [neutralEntitlement, hi]

/-- **Proposition 12, the cap.** The mint never exceeds the equity, and the
    new entitlement is non-negative. -/
theorem neutral_entitlement_nonneg (V G : ι → ℝ) (j : ι) (S M : ℝ) :
    neutralMint V G j S M ≤ V j + G j - S
      ∧ 0 ≤ neutralEntitlement V G j S M j := by
  have h : neutralMint V G j S M ≤ V j + G j - S := min_le_right _ _
  refine ⟨h, ?_⟩
  simp only [neutralEntitlement, Function.update_self]
  linarith

/-- **Proposition 12, conservation.** The dust pool's value changes by
    V j - S - V j' at the rebalance, and the entitlements change by the
    same amount in total, so they still sum to the dust pool's value. -/
theorem neutral_sum [Fintype ι] (V G : ι → ℝ) (j : ι) (S M : ℝ) :
    ∑ i, neutralEntitlement V G j S M i
      = ∑ i, G i + (V j - S - neutralMint V G j S M) := by
  unfold neutralEntitlement
  rw [Finset.sum_update_of_mem (Finset.mem_univ j),
    ← Finset.add_sum_erase Finset.univ G (Finset.mem_univ j)]
  have : Finset.univ \ {j} = Finset.univ.erase j := by
    ext i; simp
  rw [this]
  ring

omit [DecidableEq ι] in
/-- **Proposition 12, the netting saving.** With no slippage, a position
    whose ownerless mint would deploy at least its own value deploys at
    least its own value under the neutral rule. -/
theorem neutral_attains (V G : ι → ℝ) (j : ι) (M : ℝ)
    (hG : 0 ≤ G j) (hM : V j ≤ M) :
    V j ≤ neutralMint V G j 0 M := by
  unfold neutralMint
  exact le_min hM (by linarith)

/-- **Corollary 12.1 (Uniqueness).** Let a rule give position j the mint
    V' and the positions the entitlements G'. If no other entitlement
    changes, the equity of j falls by its own slippage only, and the
    entitlement of j is non-negative, then G' j is the entitlement of
    Proposition 12 for that mint and the mint is within the equity. -/
theorem neutral_unique (V G G' : ι → ℝ) (j : ι) (S V' : ℝ)
    (hown : V' + G' j = V j + G j - S) (hnn : 0 ≤ G' j)
    (hothers : ∀ i, i ≠ j → G' i = G i) :
    G' = Function.update G j (V j + G j - S - V') ∧ V' ≤ V j + G j - S := by
  refine ⟨?_, by linarith⟩
  funext i
  by_cases hi : i = j
  · subst hi
    simp only [Function.update_self]
    linarith
  · rw [Function.update_of_ne hi]
    exact hothers i hi

end Neutral

end GeometricSiphon
