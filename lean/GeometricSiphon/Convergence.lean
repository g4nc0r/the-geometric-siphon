/-
Theorem 2 (Single-pool convergence) and Corollary (Exponential convergence
rate) of "The Geometric Siphon" - the deterministic linearised layer.

Scope note. Theorem 2 is an in-expectation statement over a stochastic
rebalancing process; the paper's own proof proceeds by linearising the
expected growth equation at the fixed point (App A, spectral argument):

  η̇ = -M η,   M = c I + π 1 1ᵀ,

where η_i = V_i - V̄. The reduction from the stochastic process to this ODE
(the expectation step in the paper's proof) is not formalised here and is
left open. What is formalised is the deterministic core of the spectral
argument: for
any two components governed by the linearised dynamics, the common-mode term
π ∑_j η_j cancels in the difference, the difference satisfies ġ = -c g, and
therefore decays at exactly rate c, independent of N. This is the content of
the corollary's display |E[V_i(t) - V_j(t)]| ≤ |V_i(0) - V_j(0)| e^{-ct}
at the linearised level (with equality).
-/
import Mathlib

set_option linter.style.header false

namespace GeometricSiphon.Convergence

/-- Deterministic core of the spectral argument: if two trajectories obey
    the linearised growth dynamics η̇ = -c η - S(t) with a common coupling
    term S (here S(t) = π ∑_j η_j(t)), their difference satisfies
    ġ = -c g and decays at exactly rate c. -/
theorem pairwise_gap_decay (ηi ηj S : ℝ → ℝ) (c : ℝ)
    (hi : Differentiable ℝ ηi) (hj : Differentiable ℝ ηj)
    (hdi : ∀ t, deriv ηi t = -c * ηi t - S t)
    (hdj : ∀ t, deriv ηj t = -c * ηj t - S t) (t : ℝ) :
    ηi t - ηj t = (ηi 0 - ηj 0) * Real.exp (-c * t) := by
  have hgderiv : ∀ u, HasDerivAt (fun x => (ηi x - ηj x) * Real.exp (c * x)) 0 u := by
    intro u
    have h1 : HasDerivAt (fun x => ηi x - ηj x) (deriv ηi u - deriv ηj u) u :=
      ((hi u).hasDerivAt).sub ((hj u).hasDerivAt)
    have h2 : HasDerivAt (fun x => Real.exp (c * x)) (Real.exp (c * u) * c) u := by
      simpa using ((hasDerivAt_id u).const_mul c).exp
    have h3 := h1.mul h2
    have h4 : (deriv ηi u - deriv ηj u) * Real.exp (c * u)
        + (ηi u - ηj u) * (Real.exp (c * u) * c) = 0 := by
      rw [hdi u, hdj u]
      ring
    exact h4 ▸ h3
  have hconst := is_const_of_deriv_eq_zero
    (fun u => (hgderiv u).differentiableAt)
    (fun u => (hgderiv u).deriv) t 0
  have key : (ηi t - ηj t) * Real.exp (c * t) = ηi 0 - ηj 0 := by
    simpa using hconst
  have hexp : Real.exp (c * t) ≠ 0 := Real.exp_ne_zero _
  have hsolve : ηi t - ηj t = (ηi 0 - ηj 0) * (Real.exp (c * t))⁻¹ := by
    rw [← key]
    field_simp
  rw [hsolve, neg_mul, Real.exp_neg]

/-- **Corollary (Exponential convergence rate), linearised form.** Pairwise
    deviations decay at rate c, independent of the number of positions:
    the paper's bound holds with equality at the linearised level. -/
theorem pairwise_gap_decay_abs (ηi ηj S : ℝ → ℝ) (c : ℝ)
    (hi : Differentiable ℝ ηi) (hj : Differentiable ℝ ηj)
    (hdi : ∀ t, deriv ηi t = -c * ηi t - S t)
    (hdj : ∀ t, deriv ηj t = -c * ηj t - S t) (t : ℝ) :
    |ηi t - ηj t| ≤ |ηi 0 - ηj 0| * Real.exp (-c * t) := by
  rw [pairwise_gap_decay ηi ηj S c hi hj hdi hdj t, abs_mul,
    abs_of_pos (Real.exp_pos _)]

/-- Equilibrium characterisation inside Theorem 2's proof: with the growth
    law E[V̇/V] = π D/V - c, two positions have equal proportional growth
    iff they have equal value. -/
theorem equal_growth_iff_equal_value (piD c Vi Vj : ℝ)
    (hpiD : 0 < piD) (hVi : 0 < Vi) (hVj : 0 < Vj) :
    piD / Vi - c = piD / Vj - c ↔ Vi = Vj := by
  constructor
  · intro h
    have h' : piD / Vi = piD / Vj := by linarith
    rw [div_eq_div_iff hVi.ne' hVj.ne'] at h'
    exact (mul_left_cancel₀ hpiD.ne' h').symm
  · intro h
    rw [h]

end GeometricSiphon.Convergence
