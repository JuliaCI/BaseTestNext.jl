# This file is a part of Julia. License is MIT: http://julialang.org/license

"""
Simple unit testing functionality:

* `@test`
* `@test_throws`

All tests belong to a *test set*. There is a default, task-level
test set that throws on the first failure. Users can wrap their tests
in (nested) test sets to achieve other behaviours like not failing
immediately or writing test results in special formats. See:

* `@testset`
* `@testloop`

for more information.
"""
module BaseTestNext

export @test, @test_throws
export @testset, @testloop

#-----------------------------------------------------------------------

"""
Result

All tests produce a result object. This object may or may not be
'stored', depending on whether the test is part of a test set.
"""
abstract Result

"""
Pass

The test condition was true, i.e. the expression evaluated to true or
the correct exception was thrown.
"""
immutable Pass <: Result
    test_type::Symbol
    orig_expr
    expr
    value
end
function Base.show(io::IO, t::Pass)
    print_with_color(:green, io, "Test Passed\n")
    print(io, "  Expression: ", t.orig_expr)
    if !isa(t.expr, Expr)
        # Maybe just a constant, like true
        print(io, "\n   Evaluated: ", t.expr)
    elseif t.test_type == :test && t.expr.head == :comparison
        # The test was an expression, so display the term-by-term
        # evaluated version as well
        print(io, "\n   Evaluated: ", t.expr)
    elseif t.test_type == :test_throws
        # The correct type of exception was thrown
        print(io, "\n      Thrown: ", t.value)
    end
end

"""
Pass

The test condition was false, i.e. the expression evaluated to false or
the correct exception was not thrown.
"""
type Fail <: Result
    test_type::Symbol
    orig_expr
    expr
    value
end
function Base.show(io::IO, t::Fail)
    print_with_color(:red, io, "Test Failed\n")
    print(io, "  Expression: ", t.orig_expr)
    if !isa(t.expr, Expr)
        # Maybe just a constant, like false
        print(io, "\n   Evaluated: ", t.expr)
    elseif t.test_type == :test && t.expr.head == :comparison
        # The test was an expression, so display the term-by-term
        # evaluated version as well
        print(io, "\n   Evaluated: ", t.expr)
    elseif t.test_type == :test_throws
        # Either no exception, or wrong exception
        extest, occurred = t.value
        print(io, "\n    Expected: ", extest)
        print(io, "\n      Thrown: ", occurred)
    end
end

"""
Error

The test condition couldn't be evaluated due to an exception, or
it evaluated to something other than a `Bool`.
"""
type Error <: Result
    test_type::Symbol
    orig_expr
    value::Any
    backtrace::Any
end
function Base.show(io::IO, t::Error)
    print_with_color(:red, io, "Error During Test\n")
    if t.test_type == :test_nonbool
        println(io, "  Expression evaluated to non-Boolean")
        println(io, "  Expression: ", t.orig_expr)
        print(  io, "       Value: ", t.value)
    elseif t.test_type == :test_error
        println(io, "  Test threw an exception of type ", typeof(t.value))
        println(io, "  Expression: ", t.orig_expr)
        # Capture error message and indent to match
        errmsg = sprint(showerror, t.value, t.backtrace)
        print(io, join(map(line->string("  ",line),
                            split(errmsg, "\n")), "\n"))
    end
end


#-----------------------------------------------------------------------

# @test - check if the expression evaluates to true
# In the special case of a comparison, e.g. x == 5, generate code to
# evaluate each term in the comparison individually so the results
# can be displayed nicely.
"""
@test ex

Tests that the expression `ex` evaluates to `true`.
Returns a `Pass` `Result` if it does, a `Fail` `Result` if it is
`false`, and an `Error` `Result` is it could not be evaluated.
"""
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

# An internal function, called by the code generated by the @test
# macro to actually perform the evaluation and manage the result.
function do_test(predicate, orig_expr)
    # get_testset() returns the most recently added tests set
    # We then call record() with this test set and the test result
    record(get_testset(),
    try
        # expr, in the case of a comparison, will contain the
        # comparison with evaluated values of each term spliced in.
        # For anything else, just contains the test expression.
        # value is the evaluated value of the whole test expression.
        # Ideally it is true, but it may be false or non-Boolean.
        expr, value = predicate()
        if isa(value, Bool)
            value ? Pass(:test, orig_expr, expr, value) :
                    Fail(:test, orig_expr, expr, value)
        else
            # If the result is non-Boolean, this counts as an Error
            Error(:test_nonbool, orig_expr, value, nothing)
        end
    catch err
        # The predicate couldn't be evaluated without throwing an
        # exception, so that is an Error and not a Fail
        Error(:test_error, orig_expr, err, catch_backtrace())
    end)
end

#-----------------------------------------------------------------------

"""
@test_throws extype ex

Tests that the expression `ex` throws an exception of type `extype`.
"""
macro test_throws(extype, ex)
    :(do_test_throws( ()->($(esc(ex))), $(Expr(:quote,ex)),
                      backtrace(), $(esc(extype)) ))
end

# An internal function, called by the code generated by @test_throws
# to evaluate and catch the thrown exception - if it exists
function do_test_throws(predicate, orig_expr, bt, extype)
    record(get_testset(),
    try
        predicate()
        # If we hit this line, no exception was thrown. We treat
        # this as equivalent to the wrong exception being thrown.
        Fail(:test_throws, orig_expr, orig_expr, (extype, nothing))
    catch err
        # Check the right type of exception was thrown
        if isa(err, extype)
            Pass(:test_throws, orig_expr, orig_expr, extype)
        else
            Fail(:test_throws, orig_expr, orig_expr, (extype,err))
        end
    end)
end


#-----------------------------------------------------------------------

include("testsets.jl")

end # module