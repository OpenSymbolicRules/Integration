# Wildcard mapping: Mathematica pattern syntax → OSR wildcard notation
# Per EARS spec §5 (Wildcards)

"""
    map_wildcard(name::String, blank_type::Symbol, type_head::Union{String,Nothing}) -> String

Convert a Mathematica pattern variable to OSR wildcard notation.

- `name`: the variable name (e.g., "x", "a", "m")
- `blank_type`: `:blank` (_), `:optional` (_.), `:blankseq` (__), `:blanknullseq` (___)
- `type_head`: optional type constraint (e.g., "Integer", "Symbol", "Rational")

Returns the OSR wildcard string.

Examples:
- `map_wildcard("x", :blank, nothing)` → `"x_"`
- `map_wildcard("a", :optional, nothing)` → `"a."`
- `map_wildcard("m", :blank, "Integer")` → `"m_integer"`
- `map_wildcard("x", :blank, "Symbol")` → `"x_"` (Symbol type is dropped)
- `map_wildcard("xs", :blankseq, nothing)` → `"xs__"`
- `map_wildcard("xs", :blanknullseq, nothing)` → `"xs___"`
"""
function map_wildcard(name::String, blank_type::Symbol, type_head::Union{String,Nothing}=nothing)::String
    if blank_type == :optional
        return name * "."
    elseif blank_type == :blankseq
        return name * "__"
    elseif blank_type == :blanknullseq
        return name * "___"
    else  # :blank
        if type_head === nothing || type_head == "Symbol"
            return name * "_"
        else
            return name * "_" * lowercase(type_head)
        end
    end
end
