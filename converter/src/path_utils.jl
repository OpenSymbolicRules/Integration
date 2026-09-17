# Path utilities: map Mathematica source paths to OSR directory paths

"""
    mathematica_path_to_osr(source_path::String; prefix::String="rules") -> String

Convert a Mathematica rule file path to a OSR directory path.

Example:
    "1 Algebraic functions/1.1 Binomial products/1.1.1 Linear/1.1.1.1 (a+b x)^m.m"
    → "rules/1-algebraic/1.1-binomial/1.1.1-linear/1.1.1.1-(a+b-x)^m.json"
"""
function mathematica_path_to_osr(source_path::String; prefix::String="rules")::String
    # Remove the base directory prefix if present
    # e.g., "Rubi/IntegrationRules/" or "MathematicaSyntaxTestSuite/"
    path = source_path
    for base in ["Rubi/IntegrationRules/", "IntegrationRules/",
                  "MathematicaSyntaxTestSuite/"]
        if startswith(path, base)
            path = path[length(base)+1:end]
            break
        end
    end

    # Split into directory components
    parts = split(path, '/')
    osr_parts = String[]

    for (i, part) in enumerate(parts)
        if i == length(parts)
            # Last part is the filename — convert .m to .json
            osr_name = convert_filename(part)
            push!(osr_parts, osr_name)
        else
            # Directory component — convert to OSR naming
            osr_dir = convert_dirname(part)
            push!(osr_parts, osr_dir)
        end
    end

    joinpath(prefix, osr_parts...)
end

"""
    convert_dirname(dir::AbstractString) -> String

Convert a Mathematica directory name to OSR format.
"1 Algebraic functions" → "1-algebraic"
"1.1 Binomial products" → "1.1-binomial"
"1.1.1 Linear" → "1.1.1-linear"
"""
function convert_dirname(dir::AbstractString)::String
    # Split on first space: section number + rest
    m = match(r"^([\d.]+)\s+(.+)$", dir)
    if m === nothing
        return lowercase(replace(dir, r"\s+" => "-"))
    end
    section = m.captures[1]
    name = m.captures[2]
    # Take only the first word of the name, lowercased
    first_word = lowercase(split(name)[1])
    # Remove trailing "functions", "products", etc. for brevity
    section * "-" * first_word
end

"""
    convert_filename(filename::AbstractString) -> String

Convert a Mathematica rule filename to OSR format.
"1.1.1.1 (a+b x)^m.m" → "1.1.1.1-(a+b-x)^m.json"
"""
function convert_filename(filename::AbstractString)::String
    # Remove .m extension
    name = replace(filename, r"\.m$" => "")
    # Split section number from expression (allow non-numeric suffix like .x, .y)
    m = match(r"^([\d.]+\w*)\s+(.+)$", name)
    if m === nothing
        return replace(lowercase(name), r"\s+" => "-") * ".json"
    end
    section = m.captures[1]
    expr = m.captures[2]
    # Normalize: spaces to hyphens, keep parens/operators
    expr_clean = replace(expr, ' ' => '-')
    section * "-" * expr_clean * ".json"
end

"""
    extract_section_number(source_path::AbstractString) -> String

Extract the section number from a Mathematica source file path.
"1 Algebraic functions/1.1 Binomial products/1.1.1 Linear/1.1.1.1 (a+b x)^m.m"
→ "1.1.1.1"

Uses the filename's section number (most specific).
"""
function extract_section_number(source_path::AbstractString)::String
    filename = basename(source_path)
    # Preserve the complete RUBI leaf identifier.  Most sections are purely
    # numeric, but the source also uses identifiers such as `1.1.2.x` and
    # `7.1.4a`; truncating either form makes distinct rule files share the
    # same OSR `section:id` identity.
    m = match(r"^(\d+(\.[0-9A-Za-z]+)*)", filename)
    if m !== nothing
        return m.captures[1]
    end
    # Fallback: try parent directory for files with no section number in filename
    dir = basename(dirname(source_path))
    m2 = match(r"^(\d+(\.[0-9A-Za-z]+)*)", dir)
    m2 !== nothing ? m2.captures[1] : ""
end

"""
    source_identity(relative_source_path) -> String

Return the stable identity of a RUBI source file.  A section classifies a rule
but is not unique: RUBI has repeated numeric section labels in different
branches.  The source-relative path is therefore retained as an opaque,
human-readable identity namespace.
"""
function source_identity(relative_source_path::AbstractString)::String
    path = replace(String(relative_source_path), '\\' => '/')
    stem = replace(path, r"\.m$" => "")
    return "rubi:" * stem
end

"""
    extract_title(source_path::AbstractString) -> String

Extract the title (expression part) from a Mathematica source filename.
"1.1.1.1 (a+b x)^m.m" → "(a+b x)^m"
"""
function extract_title(source_path::AbstractString)::String
    filename = basename(source_path)
    name = replace(filename, r"\.m$" => "")
    # Match section number (including non-numeric suffix like .x) followed by expression
    m = match(r"^[\d.]+\w*\s+(.+)$", name)
    m === nothing ? name : m.captures[1]
end
