import Mathlib.Analysis.Calculus.IteratedDeriv.Defs
import Mathlib.Analysis.SpecialFunctions.Trigonometric.Deriv
import Mathlib.Analysis.SpecialFunctions.Pow.Deriv
import Mathlib.Tactic.FieldSimp
import Mathlib.Tactic.Ring

/-! Real interpretations of Rubi 4.17.3.0, section 9.1 cells 2, 4 and 5.
The source guard n > 0 is encoded by writing n = k + 1. R is any primitive
of the residual integrand at the evaluation point. -/

namespace OSR.Rubi

/-- Cell 1 on the positive integer branch, including order one. -/
theorem predecessorDeriv (k : ℕ) (f : ℝ → ℝ) (x : ℝ)
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

private theorem weightDeriv (a b c F p x : ℝ) (hF : 0 < F) (hc : 0 < c) :
    HasDerivAt (fun t => (c * F ^ (a + b * t)) ^ p)
      (b * p * Real.log F * (c * F ^ (a + b * x)) ^ p) x := by
  have hbase : 0 < c * F ^ (a + b * x) := mul_pos hc (Real.rpow_pos_of_pos hF _)
  have hd := (((affineDeriv a b x).const_rpow hF).const_mul c).rpow_const (p := p) (Or.inl hbase.ne')
  convert hd using 1
  rw [Real.rpow_sub_one hbase.ne']
  field_simp

/-- Cell 2. The positive bases give the real branch for both real powers. -/
theorem exponentialParts (k : ℕ) (a b c F p x : ℝ) (f R : ℝ → ℝ)
    (hf : ContDiffAt ℝ (k + 1 : ℕ) f x) (hF : 0 < F) (hc : 0 < c)
    (hR : HasDerivAt R ((c * F ^ (a + b * x)) ^ p * iteratedDeriv k f x) x) :
    HasDerivAt (fun t => (c * F ^ (a + b * t)) ^ p * iteratedDeriv k f t - (b * p * Real.log F) * R t)
      ((c * F ^ (a + b * x)) ^ p * iteratedDeriv (k + 1) f x) x := by
  have hw := weightDeriv a b c F p x hF hc
  convert (hw.mul (predecessorDeriv k f x hf)).sub (hR.const_mul (b * p * Real.log F)) using 1
  ring

/-- Cell 3. V is a chosen primitive of N, the next member of the tower. -/
theorem exponentialPrimitiveParts (a b c F p x : ℝ) (V N R : ℝ → ℝ)
    (hV : HasDerivAt V (N x) x) (hF : 0 < F) (hc : 0 < c)
    (hd : b * p * Real.log F ≠ 0)
    (hR : HasDerivAt R ((c * F ^ (a + b * x)) ^ p * N x) x) :
    HasDerivAt (fun t => (c * F ^ (a + b * t)) ^ p * V t / (b * p * Real.log F) -
      (1 / (b * p * Real.log F)) * R t) ((c * F ^ (a + b * x)) ^ p * V x) x := by
  obtain ⟨hbp, hlog⟩ := mul_ne_zero_iff.mp hd
  obtain ⟨hb, hp⟩ := mul_ne_zero_iff.mp hbp
  convert (((weightDeriv a b c F p x hF hc).mul hV).div_const _).sub
    (hR.const_mul (1 / (b * p * Real.log F))) using 1
  field_simp
  ring

/-- Cell 6 with a coherent adjacent primitive and nonzero affine slope. -/
theorem sinePrimitiveParts (a b x : ℝ) (V N R : ℝ → ℝ) (hb : b ≠ 0)
    (hV : HasDerivAt V (N x) x) (hR : HasDerivAt R (Real.cos (a + b * x) * N x) x) :
    HasDerivAt (fun t => -Real.cos (a + b * t) * V t / b + (1 / b) * R t)
      (Real.sin (a + b * x) * V x) x := by
  convert ((((affineDeriv a b x).cos.neg.mul hV).div_const b).add (hR.const_mul (1 / b))) using 1
  simp only [Pi.neg_apply]
  field_simp
  ring

/-- Cell 7 with the same slope and the sine residual. -/
theorem cosinePrimitiveParts (a b x : ℝ) (V N R : ℝ → ℝ) (hb : b ≠ 0)
    (hV : HasDerivAt V (N x) x) (hR : HasDerivAt R (Real.sin (a + b * x) * N x) x) :
    HasDerivAt (fun t => Real.sin (a + b * t) * V t / b - (1 / b) * R t)
      (Real.cos (a + b * x) * V x) x := by
  convert ((((affineDeriv a b x).sin.mul hV).div_const b).sub (hR.const_mul (1 / b))) using 1
  field_simp
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

/-- info: 'OSR.Rubi.predecessorDeriv' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.predecessorDeriv

/-- info: 'OSR.Rubi.exponentialPrimitiveParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.exponentialPrimitiveParts

/-- info: 'OSR.Rubi.sinePrimitiveParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.sinePrimitiveParts

/-- info: 'OSR.Rubi.cosinePrimitiveParts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms OSR.Rubi.cosinePrimitiveParts
