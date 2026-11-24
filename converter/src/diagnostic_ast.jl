# Diagnostic syntax only; original text remains authoritative, especially for
# floating-point literals and unparsed cells. This is not an OSR representation.
function diagnostic_ast(expr::MExpr)
    expr isa MSymbol && return Dict("kind" => "symbol", "name" => expr.name)
    expr isa MInteger && return Dict("kind" => "integer", "value" => string(expr.value))
    expr isa MReal && return Dict("kind" => "real", "value" => string(expr.value))
    expr isa MString && return Dict("kind" => "string", "value" => expr.value)
    expr isa MPattern && return Dict("kind" => "pattern", "name" => expr.name,
        "blank_type" => string(expr.blank_type), "type_head" => expr.type_head)
    expr isa MPrime && return Dict("kind" => "prime", "expr" => diagnostic_ast(expr.expr))
    expr isa MApply && return Dict("kind" => "application", "head" => diagnostic_ast(expr.head),
        "args" => [diagnostic_ast(arg) for arg in expr.args])
    expr isa MFunction && return Dict("kind" => "function", "head" => expr.head,
        "args" => [diagnostic_ast(arg) for arg in expr.args])
    error("Unsupported diagnostic AST node: $(typeof(expr))")
end
