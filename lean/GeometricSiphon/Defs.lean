/-
Shared definitions for the Lean formalisation of "The Geometric Siphon".

The concentrated liquidity primitives of paper §2, used by every theorem
file: the per-unit-liquidity value coefficient φ, the required token ratio
R, and the isolated-case mint minimum L_new, together with the two basic
facts about them that the theorem files share.

Setting: a position with liquidity L at sqrt price s in range [sa, sb],
with sa < s < sb, holds token amounts x = L(1/s - 1/sb), y = L(s - sa);
its value in token1 units is V = x s² + y = L φ(s, sa, sb).
-/
import Mathlib

set_option linter.style.header false

namespace GeometricSiphon

/-- Position value coefficient φ(s, sa, sb) = 2s - s²/sb - sa  (eq. 5). -/
noncomputable def phi (s sa sb : ℝ) : ℝ := 2 * s - s ^ 2 / sb - sa

/-- Token ratio R(s, sa, sb) = (1/s - 1/sb) / (s - sa)  (eq. 4). -/
noncomputable def ratio (s sa sb : ℝ) : ℝ := (1 / s - 1 / sb) / (s - sa)

/-- New liquidity from the per-token minimum (eq. 6), isolated case. -/
noncomputable def Lnew (L s sa sb sa' sb' : ℝ) : ℝ :=
  min (L * (1 / s - 1 / sb) / (1 / s - 1 / sb'))
      (L * (s - sa) / (s - sa'))

/-- φ decomposes over the token amounts: φ = s²(1/s - 1/sb) + (s - sa). -/
lemma phi_eq (s sa sb : ℝ) (hs : s ≠ 0) (hsb : sb ≠ 0) :
    phi s sa sb = s ^ 2 * (1 / s - 1 / sb) + (s - sa) := by
  unfold phi; field_simp; ring

/-- Strict interiority gives positive abstract coordinates. -/
lemma amount_coeffs_pos {s sa sb : ℝ} (h0 : 0 < sa) (h1 : sa < s) (h2 : s < sb) :
    0 < 1 / s - 1 / sb ∧ 0 < s - sa := by
  have hs : 0 < s := h0.trans h1
  have hsb : 0 < sb := hs.trans h2
  exact ⟨sub_pos.mpr (one_div_lt_one_div_of_lt hs h2), sub_pos.mpr h1⟩

end GeometricSiphon
