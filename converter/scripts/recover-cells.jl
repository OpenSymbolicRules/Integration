#!/usr/bin/env julia
# Read-only, experimental per-cell recovery. Output is not a loadable rule file.
using RubiConverter
using JSON3

function cell_contains(node, head)
    node isa AbstractVector || return false
    (!isempty(node) && first(node) == head) || any(child -> cell_contains(child, head), node)
end

# Diagnostic syntax only; original text remains authoritative, especially for
# floating-point literals and unparsed cells. This is not an OSR representation.
function diagnostic_ast(expr::RubiConverter.MExpr)
    expr isa RubiConverter.MSymbol && return Dict("kind" => "symbol", "name" => expr.name)
    expr isa RubiConverter.MInteger && return Dict("kind" => "integer", "value" => string(expr.value))
    expr isa RubiConverter.MReal && return Dict("kind" => "real", "value" => string(expr.value))
    expr isa RubiConverter.MString && return Dict("kind" => "string", "value" => expr.value)
    expr isa RubiConverter.MPattern && return Dict("kind" => "pattern", "name" => expr.name,
        "blank_type" => string(expr.blank_type), "type_head" => expr.type_head)
    expr isa RubiConverter.MPrime && return Dict("kind" => "prime", "expr" => diagnostic_ast(expr.expr))
    expr isa RubiConverter.MApply && return Dict("kind" => "application", "head" => diagnostic_ast(expr.head),
        "args" => [diagnostic_ast(arg) for arg in expr.args])
    expr isa RubiConverter.MFunction && return Dict("kind" => "function", "head" => expr.head,
        "args" => [diagnostic_ast(arg) for arg in expr.args])
    error("Unsupported diagnostic AST node: $(typeof(expr))")
end

"""Report every notebook code cell, retaining failures and source order.

The result is diagnostic data, not an executable profile. `show_steps` is an
explicit source configuration; arbitrary conditionals remain blocked.
"""
function recover_cells(source::AbstractString; show_steps::Bool)
    marker = "(* ::Code:: *)"
    occursin(marker, source) || throw(ArgumentError("Notebook code-cell markers are required"))
    rows = Dict{String,Any}[]
    for (ordinal, cell) in enumerate(split(source, marker)[2:end])
        row = Dict{String,Any}("cell" => ordinal)
        try
            expressions = RubiConverter.parse_file_expressions(marker * cell)
            if isempty(expressions)
                row["status"] = "empty"
                push!(rows, row)
                continue
            end
            length(expressions) == 1 || error("Expected one expression per cell")
            expr = only(expressions)
            row["source_ast"] = diagnostic_ast(expr)
            if expr isa RubiConverter.MFunction && expr.head == "If"
                expr = RubiConverter.select_show_steps_branch(expr; show_steps=show_steps)
                row["selected_show_steps"] = show_steps
            end
            expr isa RubiConverter.MFunction && expr.head == "SetDelayed" &&
                expr.args[1] isa RubiConverter.MFunction && expr.args[1].head == "Int" ||
                error("Cell is not a supported Int definition")
            RubiConverter.validate_experimental_scope(expr)
            rule = RubiConverter.rule_to_osr(expr, ordinal)
            row["status"] = "candidate"
            row["rule"] = rule
            row["syntax_features_detected"] = [head for head in ("Star", "With") if
                any(key -> cell_contains(rule[key], head), ("pattern", "result", "constraints"))]
        catch e
            row["status"] = "blocked"
            row["source_text"] = cell
            row["reason"] = sprint(showerror, e)
        end
        push!(rows, row)
    end
    rows
end

function source_revision(path::AbstractString)
    dir = dirname(abspath(path))
    while true
        if isfile(joinpath(dir, "PacletInfo.m"))
            root = dirname(dir)
            ispath(joinpath(root, ".git")) || return nothing
            return try
                strip(read(pipeline(`git -C $root rev-parse HEAD`; stderr=devnull), String))
            catch
                nothing
            end
        end
        parent = dirname(dir)
        parent == dir && return nothing
        dir = parent
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 3 && ARGS[2] == "--show-steps" && ARGS[3] in ("true", "false") ||
        error("Usage: julia --project=converter converter/scripts/recover-cells.jl SOURCE --show-steps true|false")
    path = abspath(ARGS[1])
    show_steps = ARGS[3] == "true"
    rows = recover_cells(read(path, String); show_steps=show_steps)
    JSON3.pretty(stdout, Dict("source" => path, "source_version" => RubiConverter.rubi_source_version(path),
        "source_revision" => source_revision(path),
        "show_steps" => show_steps,
        "status" => "experimental diagnostic; not verified or approved for execution",
        "limitations" => ["Cell positions are not RUBI runtime priorities or rule identifiers.",
            "Blocked cells are retained; candidates are not a complete or executable rule file.",
            "Source AST is diagnostic; original source text is authoritative, particularly for real literals.",
            "With, Star, helper functions and conditions require semantic and consumer review."],
        "cells" => rows))
    println()
end
