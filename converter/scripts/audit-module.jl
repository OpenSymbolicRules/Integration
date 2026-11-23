#!/usr/bin/env julia
# Read-only AST diagnostics, not a Module implementation or proof.
using RubiConverter
using JSON3

function count_head(expr, head)
    expr isa RubiConverter.MPrime && return count_head(expr.expr, head)
    expr isa RubiConverter.MApply && return count_head(expr.head, head) + sum((count_head(a, head) for a in expr.args); init=0)
    expr isa RubiConverter.MFunction || return 0
    (expr.head == head ? 1 : 0) + sum((count_head(a, head) for a in expr.args); init=0)
end

function audit_modules(expressions)
    result = Dict("modules" => 0, "initialized_locals" => 0,
        "uninitialized_locals" => 0, "unsupported_declarations" => 0,
        "body_assignments" => 0, "compound_bodies" => 0)
    function visit(expr)
        if expr isa RubiConverter.MPrime
            visit(expr.expr)
            return
        end
        if expr isa RubiConverter.MApply
            visit(expr.head)
            foreach(visit, expr.args)
            return
        end
        expr isa RubiConverter.MFunction || return
        if expr.head == "Module"
            result["modules"] += 1
            if length(expr.args) != 2 || !(expr.args[1] isa RubiConverter.MFunction) || expr.args[1].head != "List"
                result["unsupported_declarations"] += 1
            else
                for item in expr.args[1].args
                    if item isa RubiConverter.MSymbol
                        result["uninitialized_locals"] += 1
                    elseif item isa RubiConverter.MFunction && item.head == "Set" && length(item.args) == 2 && item.args[1] isa RubiConverter.MSymbol
                        result["initialized_locals"] += 1
                    else
                        result["unsupported_declarations"] += 1
                    end
                end
                result["body_assignments"] += count_head(expr.args[2], "Set")
                result["compound_bodies"] += count_head(expr.args[2], "CompoundExpression")
            end
        end
        foreach(visit, expr.args)
    end
    foreach(visit, expressions)
    result
end

function audit_blocked_modules(report_file, vendor)
    report = JSON3.read(read(report_file, String))
    files = []
    for row in report["files"]
        row["status"] == "blocked" || continue
        relative = String(row["source"])
        (isabspath(relative) || ".." in splitpath(relative)) && error("Invalid source path")
        source = joinpath(vendor, "Rubi", "IntegrationRules", relative)
        item = Dict{String,Any}("source" => relative)
        try
            expressions = RubiConverter.parse_file_expressions(read(source, String))
            item["status"] = "parsed"
            item["counts"] = audit_modules(expressions)
        catch e
            item["status"] = "parse_error"
            item["reason"] = sprint(showerror, e)
        end
        push!(files, item)
    end
    Dict("status" => "syntax audit only; not evidence of semantic equivalence",
        "limitations" => "Legacy line-based inputs may omit source expressions; nested Module body counts can overlap.",
        "files" => files)
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 2 || error("Usage: julia --project=converter converter/scripts/audit-module.jl RECOVERY_REPORT VENDOR_RUBI")
    JSON3.pretty(stdout, audit_blocked_modules(ARGS...))
    println()
end
