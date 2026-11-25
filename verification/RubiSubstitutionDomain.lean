import Mathlib.Basic.Real.Basic
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

end OSR.Rubi

/-- info: 'OSR.Rubi.substitutionCoefficientCounterexample' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.substitutionCoefficientCounterexample
