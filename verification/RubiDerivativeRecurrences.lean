import Mathlib.Analysis.Calculus.IteratedDeriv.Defs
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Deriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.Tactic.FieldSimp
import Mathlib.Tactic.Ring

/-! Real interpretations of Rubi 4.17.3.0, section 9.1 cells 2, 4 and 5.
The source guard n > 0 is encoded by writing n = k + 1. R is any primitive
of the residual integrand at the evaluation point. -/

namespace OSR.Rubi

private theorem predecessorDeriv (k : ℕ) (f : ℝ → ℝ) (x : ℝ)
    (hf : ContDiffAt ℝ (k + 1 : ℕ) f x) :
    HasDerivAt (iteratedDeriv k f) (iteratedDeriv (k + 1) f x) x := by
  have hu := hf.contDiffWithinAt (s := Set.univ)
  have hd := hu.differentiableWithinAt_iteratedDerivWithin (m := k)
    (Nat.cast_lt.mpr k.lt_succ_self) (by simp)
  have h : DifferentiableAt ℝ (iteratedDeriv k f) x := by
    simpa only [iteratedDerivWithin_univ, differentiableWithinAt_univ] using hd
  simpa only [iteratedDeriv_succ] using h.hasDerivAt

private theorem affineDeriv (a b x : ℝ) : HasDerivAt (fun t => a + b * t) b x := by
  simpa using (((hasDerivAt_id x).const_mul b).const_add a)

/-- Cell 4. The sine recurrence applies to every positive integer order. -/
theorem sineParts (k : ℕ) (a b x : ℝ) (f R : ℝ → ℝ) (hf : ContDiffAt ℝ (k + 1 : ℕ) f x)
    (hR : HasDerivAt R (Real.cos (a + b * x) * iteratedDeriv k f x) x) :
    HasDerivAt (fun t => Real.sin (a + b * t) * iteratedDeriv k f t - b * R t)
      (Real.sin (a + b * x) * iteratedDeriv (k + 1) f x) x := by
  convert ((affineDeriv a b x).sin.mul (predecessorDeriv k f x hf)).sub (hR.const_mul b) using 1
  ring

/-- Cell 5. The cosine recurrence adds the sine residual. -/
theorem cosineParts (k : ℕ) (a b x : ℝ) (f R : ℝ → ℝ) (hf : ContDiffAt ℝ (k + 1 : ℕ) f x)
    (hR : HasDerivAt R (Real.sin (a + b * x) * iteratedDeriv k f x) x) :
    HasDerivAt (fun t => Real.cos (a + b * t) * iteratedDeriv k f t + b * R t)
      (Real.cos (a + b * x) * iteratedDeriv (k + 1) f x) x := by
  convert ((affineDeriv a b x).cos.mul (predecessorDeriv k f x hf)).add (hR.const_mul b) using 1
  ring

/-- Cell 2. The positive bases give the real branch for both real powers. -/
theorem exponentialParts (k : ℕ) (a b c F p x : ℝ) (f R : ℝ → ℝ)
    (hf : ContDiffAt ℝ (k + 1 : ℕ) f x) (hF : 0 < F) (hc : 0 < c)
    (hR : HasDerivAt R ((c * F ^ (a + b * x)) ^ p * iteratedDeriv k f x) x) :
    HasDerivAt (fun t => (c * F ^ (a + b * t)) ^ p * iteratedDeriv k f t - (b * p * Real.log F) * R t)
      ((c * F ^ (a + b * x)) ^ p * iteratedDeriv (k + 1) f x) x := by
  have hbase : 0 < c * F ^ (a + b * x) := mul_pos hc (Real.rpow_pos_of_pos hF _)
  have hd := (((affineDeriv a b x).const_rpow hF).const_mul c).rpow_const (p := p) (Or.inl hbase.ne')
  have hw : HasDerivAt (fun t => (c * F ^ (a + b * t)) ^ p)
      (b * p * Real.log F * (c * F ^ (a + b * x)) ^ p) x := by
    convert hd using 1
    rw [Real.rpow_sub_one hbase.ne']
    field_simp
  convert (hw.mul (predecessorDeriv k f x hf)).sub (hR.const_mul (b * p * Real.log F)) using 1
  ring

end OSR.Rubi

/-- info: 'OSR.Rubi.sineParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.sineParts

/-- info: 'OSR.Rubi.cosineParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.cosineParts

/-- info: 'OSR.Rubi.exponentialParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.exponentialParts
