import Mathlib.Analysis.SpecialFunctions.Log.Deriv
import Mathlib.Tactic.FieldSimp

/-! Real first-derivative cases of Rubi 4.17.3.0, section 9.1, source cells
19–21. The functions are independent of the integration variable as function
heads, but their values vary with it. Each hypothesis is local to the point x. -/

namespace OSR.Rubi

variable {f g : ℝ → ℝ}

/-- Cell 19, the primitive of the derivative of a product. -/
theorem product (x p q : ℝ) (hf : HasDerivAt f p x) (hg : HasDerivAt g q x) :
    HasDerivAt (fun t => f t * g t) (p * g x + f x * q) x :=
  hf.mul hg

/-- Cell 20, with the quotient restricted to a nonzero denominator. -/
theorem quotient (x p q : ℝ) (hf : HasDerivAt f p x) (hg : HasDerivAt g q x) (hg0 : g x ≠ 0) :
    HasDerivAt (fun t => f t / g t) ((p * g x - f x * q) / g x ^ 2) x :=
  hf.div hg hg0

/-- Cell 21, restricted to the real branch of the source logarithm. -/
theorem logQuotient (x p q : ℝ) (hf : HasDerivAt f p x) (hg : HasDerivAt g q x)
    (hg0 : g x ≠ 0) (hpos : 0 < f x / g x) :
    HasDerivAt (fun t => Real.log (f t / g t)) ((p * g x - f x * q) / (f x * g x)) x := by
  have hf0 : f x ≠ 0 := by
    intro h
    rw [h, zero_div] at hpos
    exact (lt_irrefl 0) hpos
  convert ((quotient x p q hf hg hg0).log hpos.ne') using 1
  field_simp

end OSR.Rubi

/-- info: 'OSR.Rubi.product' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.product

/-- info: 'OSR.Rubi.quotient' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.quotient

/-- info: 'OSR.Rubi.logQuotient' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.logQuotient
