import Mathlib.Analysis.SpecialFunctions.Complex.Arg
import Mathlib.Analysis.Calculus.Deriv.Abs
import Mathlib.Analysis.Calculus.Deriv.Mul
import Mathlib.Analysis.Calculus.Deriv.Pow
import Mathlib.Tactic.FieldSimp
import Mathlib.Tactic.Ring

/-! Real antiderivatives of the angle of a point on the vertical axis
(`osr-supplement:axis-angle`). The point has horizontal coordinate zero and real
vertical coordinate `u`; its principal angle is `Complex.arg ⟨0, u⟩`, which is
`π/2` for `u > 0` and `-π/2` for `u < 0`. The sign guard excludes the origin. -/

namespace OSR.AxisAngle

/-- `π |g| / 2` has derivative `g' · arg ⟨0, g⟩` wherever `g` is nonzero. -/
private theorem chain {g : ℝ → ℝ} {s x : ℝ} (hg : HasDerivAt g s x)
    (h : 0 < g x ∨ g x < 0) :
    HasDerivAt (fun t => Real.pi * |g t| / 2) (s * Complex.arg ⟨0, g x⟩) x := by
  rcases h with hp | hn
  · rw [Complex.arg_eq_pi_div_two_iff.mpr ⟨rfl, hp⟩]
    convert (((hasDerivAt_abs_pos hp).comp x hg).const_mul Real.pi).div_const 2 using 1 <;> first | rfl | ring
  · rw [Complex.arg_eq_neg_pi_div_two_iff.mpr ⟨rfl, hn⟩]
    convert (((hasDerivAt_abs_neg hn).comp x hg).const_mul Real.pi).div_const 2 using 1 <;> first | rfl | ring

/-- Real statement of `osr-supplement:axis-angle:1`. -/
theorem affine (a b x : ℝ) (ha : a ≠ 0) (h : b + a * x > 0 ∨ b + a * x < 0) :
    HasDerivAt (fun t : ℝ => Real.pi * |b + a * t| / (2 * a)) (Complex.arg ⟨0, b + a * x⟩) x := by
  have hc := (chain (((hasDerivAt_id x).const_mul a).const_add b) h).div_const a
  convert hc using 1
  · funext t
    simp only [id]
    field_simp
  · simp only [id]
    field_simp

/-- Real statement of `osr-supplement:axis-angle:2`. -/
theorem quadratic (a b x : ℝ) (ha : a ≠ 0) (h : b + a * x ^ 2 > 0 ∨ b + a * x ^ 2 < 0) :
    HasDerivAt (fun t : ℝ => Real.pi * |b + a * t ^ 2| / (4 * a))
      (x * Complex.arg ⟨0, b + a * x ^ 2⟩) x := by
  have hc := (chain (((hasDerivAt_pow 2 x).const_mul a).const_add b) h).div_const (2 * a)
  convert hc using 1
  · funext t
    field_simp
    ring
  · field_simp
    ring

end OSR.AxisAngle

/-- info: 'OSR.AxisAngle.affine' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.AxisAngle.affine

/-- info: 'OSR.AxisAngle.quadratic' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.AxisAngle.quadratic
