/-
Corollary 2.2 (Dispersion) of "The Geometric Siphon": second moment of the
pairwise gap in the discrete model of ConvergenceDiscrete.lean.

`expected_gap_decay` says the expected gap contracts by (1 - α/N) per
event. It says nothing about how far a single trajectory strays from that
mean. This file closes the second moment exactly, in the same model.

One-step identity (`sum_step_gap_sq`). Write d = V_i - V_j and
g = A(D) - α (V_i + V_j)/2 for the pool's absorption net of the pair's mean
donation. Summed over the uniform choice of rebalancer,

  ∑_k d'(k)^2 = (N - 2α + α^2/2) d^2 + 2 g^2,

which is the paper's E[d'^2] = q d^2 + (2/N) g^2 after division by N. The
cross terms in d g cancel between the events that pick i and pick j, in
the same way as the absorption term cancels in the first moment.

Bound (`expected_gap_sq_bound`, `expected_gap_sq_bound_closed`). If
g^2 ≤ γ^2 on every state and 0 < α ≤ 1, 2 ≤ N, then with
q = 1 - (2α - α^2/2)/N,

  E[d(t)^2] ≤ q^t d(0)^2 + γ^2 / (α (1 - α/4)) · (1 - q^t).

The second term does not depend on N in the limit: the gap does not
converge to zero along a path, only its mean does.

The paper writes c for the donation fraction α. Its equality case
(g^2 constant) and noise in the per-event donation are not formalised.
-/
import GeometricSiphon.ConvergenceDiscrete

set_option linter.style.header false

namespace GeometricSiphon.Convergence

open Finset

variable {N : ℕ}

/-- Pool absorption net of the pair's mean donation. -/
noncomputable def pairDrift (α : ℝ) (absorb : ℝ → ℝ) (s : State N) (i j : Fin N) : ℝ :=
  absorb s.2 - α * (s.1 i + s.1 j) / 2

/-- One-step second-moment identity, summed over the rebalancer. -/
theorem sum_step_gap_sq (α : ℝ) (absorb : ℝ → ℝ) (s : State N) (i j : Fin N)
    (hij : i ≠ j) :
    ∑ k, ((stepState α absorb k s).1 i - (stepState α absorb k s).1 j) ^ 2
      = ((N : ℝ) - 2 * α + α ^ 2 / 2) * (s.1 i - s.1 j) ^ 2
        + 2 * (pairDrift α absorb s i j) ^ 2 := by
  set d := s.1 i - s.1 j with hd
  set g := pairDrift α absorb s i j with hg
  have hpt : ∀ k : Fin N,
      ((stepState α absorb k s).1 i - (stepState α absorb k s).1 j) ^ 2
        = d ^ 2 + (if k = i then ((1 - α / 2) * d + g) ^ 2 - d ^ 2 else 0)
              + (if k = j then ((1 - α / 2) * d - g) ^ 2 - d ^ 2 else 0) := by
    intro k
    simp only [stepState, hd, hg, pairDrift]
    by_cases hki : k = i
    · subst hki
      have hkj : ¬ (j = k) := fun h => hij h.symm
      simp [hkj, hij]
      ring
    · by_cases hkj : k = j
      · subst hkj
        have : ¬ (i = k) := fun h => hki h.symm
        simp [this, hki]
        ring
      · have h1 : ¬ (i = k) := fun h => hki h.symm
        have h2 : ¬ (j = k) := fun h => hkj h.symm
        simp [h1, h2, hki, hkj]
  simp_rw [hpt]
  rw [Finset.sum_add_distrib, Finset.sum_add_distrib, Finset.sum_const, Finset.card_univ,
    Fintype.card_fin, nsmul_eq_mul, Finset.sum_ite_eq', Finset.sum_ite_eq']
  simp
  ring

/-- **Corollary 2.2, bound in summed form.** Second moment of the pairwise gap after t events, for a
    pool whose net drift is bounded by γ on every state. -/
theorem expected_gap_sq_bound (hN : 2 ≤ N) (α : ℝ) (absorb : ℝ → ℝ)
    (_hα0 : 0 ≤ α) (hα1 : α ≤ 1) (γ : ℝ) (i j : Fin N) (hij : i ≠ j)
    (hγ : ∀ s : State N, (pairDrift α absorb s i j) ^ 2 ≤ γ ^ 2) :
    ∀ (t : ℕ) (s : State N),
      expOver α absorb t s (fun s' => (s'.1 i - s'.1 j) ^ 2)
        ≤ (1 - (2 * α - α ^ 2 / 2) / N) ^ t * (s.1 i - s.1 j) ^ 2
          + (2 * γ ^ 2 / N) * ∑ u ∈ range t, (1 - (2 * α - α ^ 2 / 2) / N) ^ u := by
  have hNpos : (0 : ℝ) < N := by
    have : (2 : ℝ) ≤ N := by exact_mod_cast hN
    linarith
  set ρ := 1 - (2 * α - α ^ 2 / 2) / (N : ℝ) with hρ
  have hρ0 : 0 ≤ ρ := by
    have hN2 : (2 : ℝ) ≤ N := by exact_mod_cast hN
    have hnum : 2 * α - α ^ 2 / 2 ≤ N := by nlinarith
    rw [hρ, sub_nonneg, div_le_one hNpos]
    exact hnum
  have hNρ : (N : ℝ) * ρ = (N : ℝ) - 2 * α + α ^ 2 / 2 := by
    rw [hρ]; field_simp; ring
  intro t
  induction t with
  | zero => intro s; simp [expOver]
  | succ t ih =>
    intro s
    simp only [expOver]
    have hsum : ∑ k, expOver α absorb t (stepState α absorb k s) (fun s' => (s'.1 i - s'.1 j) ^ 2)
        ≤ ∑ k, (ρ ^ t * ((stepState α absorb k s).1 i - (stepState α absorb k s).1 j) ^ 2
            + (2 * γ ^ 2 / N) * ∑ u ∈ range t, ρ ^ u) :=
      Finset.sum_le_sum (fun k _ => ih _)
    rw [Finset.sum_add_distrib, ← Finset.mul_sum, sum_step_gap_sq α absorb s i j hij,
      Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul] at hsum
    have hg := hγ s
    rw [div_le_iff₀ hNpos]
    rw [Finset.sum_range_succ]
    have hρt : 0 ≤ ρ ^ t := pow_nonneg hρ0 t
    calc _ ≤ _ := hsum
      _ ≤ ρ ^ t * ((N : ℝ) * ρ * (s.1 i - s.1 j) ^ 2 + 2 * γ ^ 2)
            + (N : ℝ) * ((2 * γ ^ 2 / N) * ∑ u ∈ range t, ρ ^ u) := by
          rw [hNρ]
          nlinarith [mul_le_mul_of_nonneg_left hg hρt]
      _ = _ := by
          field_simp
          ring

/-- **Corollary 2.2, bound in closed form.** The geometric sum evaluated:
    E[d(t)^2] ≤ q^t d(0)^2 + γ^2 / (α (1 - α/4)) · (1 - q^t). -/
theorem expected_gap_sq_bound_closed (hN : 2 ≤ N) (α : ℝ) (absorb : ℝ → ℝ)
    (hα0 : 0 < α) (hα1 : α ≤ 1) (γ : ℝ) (i j : Fin N) (hij : i ≠ j)
    (hγ : ∀ s : State N, (pairDrift α absorb s i j) ^ 2 ≤ γ ^ 2)
    (t : ℕ) (s : State N) :
    expOver α absorb t s (fun s' => (s'.1 i - s'.1 j) ^ 2)
      ≤ (1 - (2 * α - α ^ 2 / 2) / N) ^ t * (s.1 i - s.1 j) ^ 2
        + γ ^ 2 / (α * (1 - α / 4)) * (1 - (1 - (2 * α - α ^ 2 / 2) / N) ^ t) := by
  have h := expected_gap_sq_bound hN α absorb hα0.le hα1 γ i j hij hγ t s
  have hNpos : (0 : ℝ) < N := by
    have : (2 : ℝ) ≤ N := by exact_mod_cast hN
    linarith
  have hk : 0 < 2 * α - α ^ 2 / 2 := by nlinarith
  have hne : 1 - (2 * α - α ^ 2 / 2) / (N : ℝ) ≠ 1 := by
    have : 0 < (2 * α - α ^ 2 / 2) / (N : ℝ) := div_pos hk hNpos
    linarith
  have hsum : (2 * γ ^ 2 / N) * ∑ u ∈ range t, (1 - (2 * α - α ^ 2 / 2) / (N : ℝ)) ^ u
      = γ ^ 2 / (α * (1 - α / 4)) * (1 - (1 - (2 * α - α ^ 2 / 2) / (N : ℝ)) ^ t) := by
    rw [geom_sum_eq hne]
    have h4 : 0 < 1 - α / 4 := by linarith
    have e : 1 - (2 * α - α ^ 2 / 2) / (N : ℝ) - 1 = -(2 * α * (1 - α / 4)) / N := by
      ring
    rw [e]
    generalize (1 - (2 * α - α ^ 2 / 2) / (N : ℝ)) ^ t = r
    have := hNpos.ne'
    have := hα0.ne'
    have := h4.ne'
    field_simp
    ring
  linarith [h, hsum]

end GeometricSiphon.Convergence
