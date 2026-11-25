import Mathlib.Analysis.SpecialFunctions.Complex.Arg
import Mathlib.Analysis.Calculus.Deriv.Abs
import Mathlib.Analysis.Calculus.Deriv.Mul
import Mathlib.Analysis.Calculus.Deriv.Pow
import Mathlib.Tactic.Ring

/-! Real antiderivatives for the Maxima vertical-axis supplement.
The horizontal and vertical coordinates are the real and imaginary parts of the
point whose principal angle is taken. The strict sign guard excludes the origin. -/

namespace OSR.Maxima

private theorem axisAngleChain {g : ℝ → ℝ} {s x : ℝ} (hg : HasDerivAt g s x)
    (h : 0 < g x ∨ g x < 0) :
    HasDerivAt (fun t => Real.pi * |g t| / 2) (s * Complex.arg ⟨0, g x⟩) x := by
  rcases h with hp | hn
  · rw [Complex.arg_eq_pi_div_two_iff.mpr ⟨rfl, hp⟩]
    convert (((hasDerivAt_abs_pos hp).comp x hg).const_mul Real.pi).div_const 2 using 1 <;> first | rfl | ring
  · rw [Complex.arg_eq_neg_pi_div_two_iff.mpr ⟨rfl, hn⟩]
    convert (((hasDerivAt_abs_neg hn).comp x hg).const_mul Real.pi).div_const 2 using 1 <;> first | rfl | ring

/-- Real statement of cas-supplement:maxima-axis-angle:1. -/
theorem axisAngleLinear (b x : ℝ) (h : b + x > 0 ∨ b + x < 0) :
    HasDerivAt (fun t : ℝ => Real.pi * |b + t| / 2) (Complex.arg ⟨0, b + x⟩) x := by
  simpa using axisAngleChain ((hasDerivAt_id x).const_add b) h

/-- Real statement of cas-supplement:maxima-axis-angle:2. -/
theorem axisAngleQuadratic (b x : ℝ) (h : b + x ^ 2 > 0 ∨ b + x ^ 2 < 0) :
    HasDerivAt (fun t : ℝ => Real.pi * |b + t ^ 2| / 4) (x * Complex.arg ⟨0, b + x ^ 2⟩) x := by
  have hc := (axisAngleChain ((hasDerivAt_pow 2 x).const_add b) h).div_const 2
  convert hc using 1
  · funext t
    ring
  · ring

/-- With b = 0, the linear rule's proposed primitive has no derivative at the origin. -/
theorem axisAngleLinear_origin :
    ¬ DifferentiableAt ℝ (fun t : ℝ => Real.pi * |t| / 2) 0 := by
  intro h
  apply not_differentiableAt_abs_zero
  convert h.const_mul (2 / Real.pi) using 1
  funext t
  field_simp

end OSR.Maxima

/-- info: 'OSR.Maxima.axisAngleLinear' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Maxima.axisAngleLinear

/-- info: 'OSR.Maxima.axisAngleQuadratic' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Maxima.axisAngleQuadratic

/-- info: 'OSR.Maxima.axisAngleLinear_origin' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Maxima.axisAngleLinear_origin
