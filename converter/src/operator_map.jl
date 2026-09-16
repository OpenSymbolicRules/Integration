# Mathematica → OSR-Expr operator name mapping
# Based on EARS spec §4 and osr-expr.schema.json enums

const OPERATOR_MAP = Dict{String, String}(
    # §4.3 Core arithmetic (Mathematica FullForm → OSR)
    "Plus"      => "Add",
    "Times"     => "Multiply",
    "Power"     => "Power",
    "Minus"     => "Negate",      # unary minus in FullForm

    # These are identity mappings (same name in both)
    "Divide"    => "Divide",
    "Subtract"  => "Subtract",
    "Negate"    => "Negate",
    "Sqrt"      => "Sqrt",
    "Abs"       => "Abs",
    "Factorial" => "Factorial",

    # §4.4 Direct trigonometric
    "Sin" => "Sin", "Cos" => "Cos", "Tan" => "Tan",
    "Cot" => "Cot", "Sec" => "Sec", "Csc" => "Csc",

    # §4.4 Hyperbolic
    "Sinh" => "Sinh", "Cosh" => "Cosh", "Tanh" => "Tanh",
    "Coth" => "Coth", "Sech" => "Sech", "Csch" => "Csch",

    # §4.5 Inverse trigonometric (key divergence from Mathematica naming)
    "ArcSin" => "Asin", "ArcCos" => "Acos", "ArcTan" => "Atan",
    "ArcCot" => "Acot", "ArcSec" => "Asec", "ArcCsc" => "Acsc",

    # §4.5 Inverse hyperbolic
    "ArcSinh" => "Asinh", "ArcCosh" => "Acosh", "ArcTanh" => "Atanh",
    "ArcCoth" => "Acoth", "ArcSech" => "Asech", "ArcCsch" => "Acsch",

    # §4.6 Exponential and logarithmic
    "Exp" => "Exp", "Log" => "Log",

    # §4.7 Special functions
    "Gamma" => "Gamma", "LogGamma" => "LogGamma",
    "Beta" => "Beta", "Zeta" => "Zeta",
    "PolyLog" => "PolyLog", "ProductLog" => "ProductLog",
    "EllipticF" => "EllipticF", "EllipticE" => "EllipticE",
    "EllipticPi" => "EllipticPi", "EllipticK" => "EllipticK",
    "Erf" => "Erf", "Erfc" => "Erfc", "Erfi" => "Erfi",
    "FresnelS" => "FresnelS", "FresnelC" => "FresnelC",
    "ExpIntegralE" => "ExpIntegralE", "ExpIntegralEi" => "ExpIntegralEi",
    "LogIntegral" => "LogIntegral",
    "SinIntegral" => "SinIntegral", "CosIntegral" => "CosIntegral",
    "SinhIntegral" => "SinhIntegral", "CoshIntegral" => "CoshIntegral",
    "Hypergeometric2F1" => "Hypergeometric2F1",
    "HypergeometricPFQ" => "HypergeometricPFQ",
    "AppellF1" => "AppellF1",
    "BesselJ" => "BesselJ", "BesselY" => "BesselY",
    "BesselI" => "BesselI", "BesselK" => "BesselK",
    "Pochhammer" => "Pochhammer",
    "Binomial" => "Binomial",

    # §4.8 Integration-specific operators
    "Int"              => "Int",
    "Dist"             => "Dist",
    "Subst"            => "Subst",
    "Simp"             => "Simp",
    "ExpandIntegrand"  => "ExpandIntegrand",
    "Unintegrable"     => "Unintegrable",
    "CannotIntegrate"  => "CannotIntegrate",

    # §4.9 Mathematical constants
    "Pi"       => "Pi",
    "E"        => "E",
    "I"        => "ImaginaryI",
    "Infinity" => "Infinity",
    "ComplexInfinity" => "ComplexInfinity",
    "Indeterminate"   => "Indeterminate",
    "True"     => "True",
    "False"    => "False",

    # §4.11 Utility functions — normalization
    "NormalizeIntegrand"     => "NormalizeIntegrand",
    "SimplifyIntegrand"      => "SimplifyIntegrand",
    "SimplifyAntiderivative" => "SimplifyAntiderivative",
    "NormalizeLeadTermSigns" => "NormalizeLeadTermSigns",
    "NormalizeSumFactors"    => "NormalizeSumFactors",
    "AbsorbMinusSign"        => "AbsorbMinusSign",
    "FixSimplify"            => "FixSimplify",
    "SmartSimplify"          => "SmartSimplify",
    "TogetherSimplify"       => "TogetherSimplify",
    "ContentFactor"          => "ContentFactor",
    "RemoveContent"          => "RemoveContent",

    # §4.11 Utility functions — polynomial
    "Coefficient"  => "Coefficient",
    "Exponent"     => "Exponent",
    "IntPart"      => "IntPart",
    "FracPart"     => "FracPart",
    "Together"     => "Together",
    "Apart"        => "Apart",
    "Cancel"       => "Cancel",
    "Factor"       => "Factor",
    "Expand"       => "Expand",
    "ExpandAll"    => "ExpandAll",
    "Numerator"    => "Numerator",
    "Denominator"  => "Denominator",
    "SmartNumerator"   => "SmartNumerator",
    "SmartDenominator" => "SmartDenominator",
    "Rt"           => "Rt",

    # §4.11 Utility functions — trig
    "TrigReduce"       => "TrigReduce",
    "TrigExpand"       => "TrigExpand",
    "TrigToExp"        => "TrigToExp",
    "ExpToTrig"        => "ExpToTrig",
    "SmartTrigExpand"  => "SmartTrigExpand",
    "SmartTrigReduce"  => "SmartTrigReduce",
    "TrigSimplifyAux"  => "TrigSimplifyAux",
    "ActivateTrig"     => "ActivateTrig",
    "DeactivateTrig"   => "DeactivateTrig",

    # §4.11 Utility functions — structural
    "LeadTerm"           => "LeadTerm",
    "RemainingTerms"     => "RemainingTerms",
    "LeadFactor"         => "LeadFactor",
    "RemainingFactors"   => "RemainingFactors",
    "LeadBase"           => "LeadBase",
    "LeadDegree"         => "LeadDegree",
    "MergeFactor"        => "MergeFactor",
    "MergeFactors"       => "MergeFactors",

    # §4.11 Utility functions — substitution
    "SubstFor"                                   => "SubstFor",
    "SubstForFractionalPowerOfLinear"             => "SubstForFractionalPowerOfLinear",
    "SubstForFractionalPowerOfQuotientOfLinears"  => "SubstForFractionalPowerOfQuotientOfLinears",
    "SubstForInverseFunction"                     => "SubstForInverseFunction",
    "SubstForExpn"                                => "SubstForExpn",

    # §4.11 Utility functions — calculus/misc
    "D"           => "D",
    "Dif"         => "Dif",
    "Map"         => "Map",
    "Simplify"    => "Simplify",
    "FullSimplify" => "FullSimplify",
    "ReplaceAll"  => "ReplaceAll",
    "Mods"        => "Mods",

    # §4.12 Structural and utility operators
    "List"                 => "List",
    "Piecewise"            => "Piecewise",
    "Condition"            => "Condition",
    "If"                   => "If",
    "With"                 => "With",
    "Module"               => "Module",
    "CompoundExpression"   => "CompoundExpression",
    "Rule"                 => "Rule",
    "Set"                  => "Set",
    "Floor"                => "Floor",
    "Ceiling"              => "Ceiling",
    "Round"                => "Round",
    "Mod"                  => "Mod",
    "Max"                  => "Max",
    "Min"                  => "Min",
    "Sign"                 => "Sign",
    "Conjugate"            => "Conjugate",
    "Re"                   => "Re",
    "Im"                   => "Im",
    "Head"                 => "Head",
    "Length"               => "Length",
    "Part"                 => "Part",
    "Apply"                => "Apply",
    "Scan"                 => "Scan",
    "Catch"                => "Catch",
    "Throw"                => "Throw",
    "Hold"                 => "Hold",
    "HoldForm"             => "HoldForm",
    "Sum"                  => "Sum",
    "Product"              => "Product",
    "Table"                => "Table",
    "Do"                   => "Do",

    # Additional Rubi utility functions found in actual .m files
    "FracPart"             => "FracPart",
    "IntLinearQ"           => "IntLinearQ",
    "RemoveContentAux"     => "RemoveContentAux",
    "SumSimplerQ"          => "SumSimplerQ",
    "Rational"             => "Rational",
    "Complex"              => "Complex",
    "Pattern"              => "Pattern",
    "Blank"                => "Blank",
    "BlankSequence"        => "BlankSequence",
    "BlankNullSequence"    => "BlankNullSequence",
    "Optional"             => "Optional",
    "SetDelayed"           => "SetDelayed",
    "RuleDelayed"          => "RuleDelayed",
    "Alternatives"         => "Alternatives",
)

"""
    map_operator(mathematica_name::String) -> String

Map a Mathematica operator/function name to its OSR-Expr equivalent.
Returns the name unchanged if no mapping exists (pass-through for
unknown operators — the OSR schema accepts any PascalCase name).
"""
function map_operator(name::String)::String
    get(OPERATOR_MAP, name, name)
end
