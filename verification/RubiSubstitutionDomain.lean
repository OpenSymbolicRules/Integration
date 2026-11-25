import Mathlib.Analysis.SpecialFunctions.Log.Basic
import Mathlib.Tactic.NormNum

/-! The coefficient equation of Rubi 4.17.3.0 section 9.1 cells 16–18 admits
a specialization for which the displayed quotient has no real value.
Existence of a finite coefficient is phrased without Lean's total division. -/

namespace OSR.Rubi

theorem substitutionCoefficientCounterexample :
    ∃ a b p q : ℝ, a * (q + 1) = b * (p + 1) ∧ ¬ ∃ z : ℝ, (p + 1) * z = a := by
  refine ⟨1, 1, -1, -1, by norm_num, ?_⟩
  rintro ⟨z, hz⟩
  norm_num at hz

/-- Cells 3, 6 and 7 admit a negative order and zero affine slope.
Even for a positive exponential base neither required reciprocal then exists. -/
theorem primitiveSlopeCounterexample :
    ∃ (n : ℤ) (b p F : ℝ), n < 0 ∧ b = 0 ∧ p ≠ 0 ∧ 1 < F ∧
      (¬ ∃ z : ℝ, b * z = 1) ∧ (¬ ∃ z : ℝ, (b * p * Real.log F) * z = 1) := by
  refine ⟨-1, 0, 1, 2, ?_⟩
  norm_num

end OSR.Rubi

/-- info: 'OSR.Rubi.substitutionCoefficientCounterexample' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.substitutionCoefficientCounterexample

/-- info: 'OSR.Rubi.primitiveSlopeCounterexample' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.primitiveSlopeCounterexample
