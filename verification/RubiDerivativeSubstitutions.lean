import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.Tactic.FieldSimp
import Mathlib.Tactic.Ring

/-! Real chain rules for Rubi 4.17.3.0, section 9.1. K is the integrand
in the new variable. The source factor u has value K(z(x)). P is its
primitive at z(x). F and G may themselves be successive derivatives when
their indicated derivatives exist. The power cases use positive bases. -/

namespace OSR.Rubi

/-- Cell 8, for a predecessor F with derivative F' at x. -/
theorem primitiveSubstitution (F K P : ℝ → ℝ) (x F' : ℝ)
    (hF : HasDerivAt F F' x) (hP : HasDerivAt P (K (F x)) (F x)) :
    HasDerivAt (fun t => P (F t)) (K (F x) * F') x :=
  hP.comp x hF

/-- Cells 9–11. The product and derivative bindings stay in the same order. -/
theorem productSubstitution (F G K P : ℝ → ℝ) (a x F' G' : ℝ)
    (hF : HasDerivAt F F' x) (hG : HasDerivAt G G' x)
    (hP : HasDerivAt P (K (F x * G x)) (F x * G x)) :
    HasDerivAt (fun t => a * P (F t * G t))
      (K (F x * G x) * (a * F' * G x + a * F x * G')) x := by
  convert ((hP.comp x (hF.mul hG)).const_mul a) using 1 <;> first | rfl | ring

/-- Cells 12, 13 and 15. The coefficient guard also covers p = -1. -/
theorem leftPowerSubstitution (F G K P : ℝ → ℝ) (a b p x F' G' : ℝ)
    (hF : HasDerivAt F F' x) (hG : HasDerivAt G G' x) (hpos : 0 < F x)
    (hab : a = b * (p + 1))
    (hP : HasDerivAt P (K (F x ^ (p + 1) * G x)) (F x ^ (p + 1) * G x)) :
    HasDerivAt (fun t => b * P (F t ^ (p + 1) * G t))
      (K (F x ^ (p + 1) * G x) * F x ^ p * (a * F' * G x + b * F x * G')) x := by
  have hz := (hF.rpow_const (p := p + 1) (Or.inl hpos.ne')).mul hG
  convert ((hP.comp x hz).const_mul b) using 1 <;> try rfl
  rw [add_sub_cancel_right, Real.rpow_add_one hpos.ne', hab]
  ring

/-- Cell 14. The power belongs to G and the outside coefficient is a. -/
theorem rightPowerSubstitution (F G K P : ℝ → ℝ) (a b q x F' G' : ℝ)
    (hF : HasDerivAt F F' x) (hG : HasDerivAt G G' x) (hpos : 0 < G x)
    (hab : a * (q + 1) = b)
    (hP : HasDerivAt P (K (F x * G x ^ (q + 1))) (F x * G x ^ (q + 1))) :
    HasDerivAt (fun t => a * P (F t * G t ^ (q + 1)))
      (K (F x * G x ^ (q + 1)) * G x ^ q * (a * F' * G x + b * F x * G')) x := by
  have hz := hF.mul (hG.rpow_const (p := q + 1) (Or.inl hpos.ne'))
  convert ((hP.comp x hz).const_mul a) using 1 <;> try rfl
  rw [add_sub_cancel_right, Real.rpow_add_one hpos.ne', ← hab]
  ring

/-- Cells 16–18 with the extra nonzero divisor required by the formula. -/
theorem twoPowerSubstitution (F G K P : ℝ → ℝ) (a b p q x F' G' : ℝ)
    (hF : HasDerivAt F F' x) (hG : HasDerivAt G G' x)
    (hposF : 0 < F x) (hposG : 0 < G x)
    (hab : a * (q + 1) = b * (p + 1)) (hp : p + 1 ≠ 0)
    (hP : HasDerivAt P (K (F x ^ (p + 1) * G x ^ (q + 1)))
      (F x ^ (p + 1) * G x ^ (q + 1))) :
    HasDerivAt (fun t => a / (p + 1) * P (F t ^ (p + 1) * G t ^ (q + 1)))
      (K (F x ^ (p + 1) * G x ^ (q + 1)) * F x ^ p * G x ^ q *
        (a * F' * G x + b * F x * G')) x := by
  have hz := (hF.rpow_const (p := p + 1) (Or.inl hposF.ne')).mul
    (hG.rpow_const (p := q + 1) (Or.inl hposG.ne'))
  have hb : b = a * (q + 1) / (p + 1) := (eq_div_iff hp).2 hab.symm
  convert ((hP.comp x hz).const_mul (a / (p + 1))) using 1 <;> try rfl
  simp only [add_sub_cancel_right, Real.rpow_add_one hposF.ne', Real.rpow_add_one hposG.ne', hb]
  field_simp

end OSR.Rubi

/-- info: 'OSR.Rubi.primitiveSubstitution' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.primitiveSubstitution

/-- info: 'OSR.Rubi.productSubstitution' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.productSubstitution

/-- info: 'OSR.Rubi.leftPowerSubstitution' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.leftPowerSubstitution

/-- info: 'OSR.Rubi.rightPowerSubstitution' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.rightPowerSubstitution

/-- info: 'OSR.Rubi.twoPowerSubstitution' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.twoPowerSubstitution
