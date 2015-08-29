module BaseTestNext

export @test, @test_throws
export @testset

#-----------------------------------------------------------------------
# All tests produce a result object, that may or may not be stored
# depending on whether the test is part of a test set. Parameteric
# on the test type (:test, :test_throws)
abstract Result{T}

# Pass: condition was true
immutable Pass{T} <: Result{T}
    orig_expr::Expr
    expr::Expr
    value::Bool
end
function Base.show(io::IO, t::Pass{:test})
    print_with_color(:green, io, "Test Passed\n")
    print(io, "  Expression: ", t.orig_expr)
    if t.expr.head == :comparison
        # The test was an expression, so display the term-by-term
        # evaluated version as well
        print(io, "\n   Evaluated: ", t.expr)
    end
end

# Fail: condition was false
type Fail{T} <: Result{T}
    orig_expr::Expr
    expr::Expr
    value::Bool
end
function Base.show(io::IO, t::Fail{:test})
    print_with_color(:red, io, "Test Failed\n")
    print(io, "  Expression: ", t.orig_expr)
    if t.expr.head == :comparison
        # The test was an expression, so display the term-by-term
        # evaluated version as well
        print(io, "\n   Evaluated: ", t.expr)
    end
end

# Error: condition couldn't be evaluated due to an exception, or
# the result of the test wasn't a Boolean
type Error{T} <: Result{T}
    orig_expr::Expr
    value::Any
    backtrace::Any
end
function Base.show(io::IO, t::Error{:test_nonbool})
    print_with_color(:red, io, "Error During Test\n")
    println(io, "  Expression evaluated to non-Boolean")
    println(io, "  Expression: ", t.orig_expr)
    print(  io, "       Value: ", t.value)
end
function Base.show(io::IO, t::Error{:test_error})
    print_with_color(:red, io, "Error During Test\n")
    println(io, "  Test threw an exception of type ", typeof(t.value))
    println(io, "  Expression: ", t.orig_expr)
    # Capture error message and indent to match
    errmsg = sprint(showerror, t.value, t.backtrace)
    print(io, join(map(line->string("  ",line),
                        split(errmsg, "\n")), "\n"))
end

#-----------------------------------------------------------------------
# @test - check if the expression evaluates to true
# In the special case of a comparison, e.g. x == 5, evaluate each term
# in the comparison individually so the results can be displayed
macro test(ex)
    # If the test is a comparison
    if typeof(ex) == Expr && ex.head == :comparison
        # Generate a temporary for every term in the expression
        n = length(ex.args)
        terms = [gensym() for i in 1:n]
        # Create a new block that evaluates each term in the
        # comparison indivudally
        comp_block = Expr(:block)
        comp_block.args = [:(
                            $(terms[i]) = $(esc(ex.args[i]))
                            ) for i in 1:n]
        # The block should then evaluate whether the comparison
        # evaluates to true by splicing in the new terms into the
        # original comparsion. The block returns
        # - an expression with the values of terms spliced in
        # - the result of the comparison itself
        push!(comp_block.args, Expr(:return,
            :(  Expr(:comparison, $(terms...)),  # Terms spliced in
              $(Expr(:comparison,   terms...))   # Comparison itself
            )))
        # Return code that calls do_test with an anonymous function
        # that calls the comparison block
        :(do_test(()->($comp_block), $(Expr(:quote,ex))))
    else
        # Something else, perhaps just a single value
        # Return code that calls do_test with an anonymous function
        # that returns the expression and its value
        :(do_test(()->($(Expr(:quote,ex)), $(esc(ex))), $(Expr(:quote,ex))))
    end
end


function do_test(predicate, orig_expr)
    record(get_testset(),
    try
        # expr, in the case of a comparison, will contain the
        # comparison with evaluated values of each term spliced in.
        # For anything else, just contains the test expression.
        # value is the evaluated value of the whole test expression.
        # Ideally it is true, but it may be false or non-Boolean.
        expr, value = predicate()
        if isa(value, Bool)
            value ? Pass{:test}(orig_expr,expr,value) :
                    Fail{:test}(orig_expr,expr,value)
        else
            Error{:test_nonbool}(orig_expr,value,nothing)
        end
    catch err
        Error{:test_error}(orig_expr,err,catch_backtrace())
    end)
end


#-----------------------------------------------------------------------
# All tests belong to a test set. There is a default, task-level
# test set that throws on first failure. Users can wrap their tests in
# nested test sets to achieve other behaviours like not failing
# immediately or writing test results in special formats.
include("testsets.jl")

end # module