# This file is a part of Julia. License is MIT: http://julialang.org/license

# The AbstractTestSet interface is defined by two methods:
# record(AbstractTestSet, Result)
#   Called by do_test after a test is evaluated
# finish(AbstractTestSet)
#   Called after the test set has been popped from the test set stack
abstract AbstractTestSet

#-----------------------------------------------------------------------

"""
FallbackTestSet

A simple fallback test set that throws immediately on a failure.
"""
immutable FallbackTestSet <: AbstractTestSet
end
fallback_testset = FallbackTestSet()

# Records nothing, and throws an error immediately whenever a Fail or
# Error occurs. Takes no action in the event of a Pass result
record(ts::FallbackTestSet, t::Pass) = t
function record(ts::FallbackTestSet, t::Union(Fail,Error))
    println(t)
    error("There was an error during testing")
    t
end
# We don't need to do anything as we don't record anything
finish(ts::FallbackTestSet) = nothing

#-----------------------------------------------------------------------

# We provide a default test set that stores results, and doesn't throw
# any exceptions until the end of the test set.
include("defaulttestset.jl")

#-----------------------------------------------------------------------

"""
@testset "description" begin ... end
@testset begin ... end

Starts a new test set. The test results will be recorded, and if there
are any `Fail`s or `Error`s, an exception will be thrown only at the end,
along with a summary of the test results.
"""
macro testset(args...)
    # Parse arguments to do determine if any options passed in
    if length(args) == 2
        # Looks like description format
        desc, tests = args
        !isa(desc, String) && error("Unexpected argument to @testset")
    elseif length(args) == 1
        # No description provided
        desc, tests = "", args[1]
    elseif length(args) >= 3
        error("Too many arguments to @testset")
    else
        error("Too few arguments to @testset")
    end
    # Generate a block of code that initializes a new testset, adds
    # it to the task local storage, evaluates the test(s), before
    # finally removing the testset and giving it a change to take
    # action (such as reporting the results)
    ts = gensym()
    quote
        $ts = DefaultTestSet($desc)
        add_testset($ts)
        $(esc(tests))
        pop_testset()
        finish($ts)
    end
end


"""
@testloop "description \$v" for v in (...) ... end
@testloop for x in (...), y in (...) ... end

Starts a new test set for each iteration of the loop. The description
string accepts interpolation from the loop indices. If no description
is provided, one is constructed based on the variables.
"""
macro testloop(args...)
    # Parse arguments to do determine if any options passed in
    if length(args) == 2
        # Looks like description format
        desc, testloop = args        
        isa(desc,String) || (isa(desc,Expr) && desc.head == :string) || error("Unexpected argument to @testloop")
        isa(testloop,Expr) && testloop.head == :for || error("Unexpected argument to @testloop")

    elseif length(args) == 1
        # No description provided
        testloop = args[1]
        isa(testloop,Expr) && testloop.head == :for || error("Unexpected argument to @testloop")
        loopvars = testloop.args[1]
        if loopvars.head == :(=)
            # 1 variable
            v = loopvars.args[1]
            desc = Expr(:string,"$v = ",v)
        else
            # multiple variables
            v = loopvars.args[1].args[1]
            desc = Expr(:string,"$v = ",v) # first variable
            for l = loopvars.args[2:end]
                v = l.args[1]
                push!(desc.args,", $v = ")
                push!(desc.args,v)
            end
        end
    elseif length(args) >= 3
        error("Too many arguments to @testloop")
    else
        error("Too few arguments to @testloop")
    end
    
    # Uses a similar block as for `@testset`, except that it is
    # wrapped in the outer loop provided by the user
    ts = gensym()
    tests = testloop.args[2]  
    blk = quote
        $ts = DefaultTestSet($(esc(desc)))
        add_testset($ts)
        $(esc(tests))
        pop_testset()
        finish($ts)
    end
    Expr(:for,esc(testloop.args[1]),blk)
end


#-----------------------------------------------------------------------
# Various helper methods for test sets

"""
get_testset()

Retrieve the active test set from the task's local storage. If no
test set is active, use the fallback default test set.
"""
function get_testset()
    testsets = get(task_local_storage(), :__BASETESTNEXT__, AbstractTestSet[])
    return length(testsets) == 0 ? fallback_testset : testsets[end]
end

"""
add_testset(ts::AbstractTestSet)

Adds the test set to the task_local_storage.
"""
function add_testset(ts::AbstractTestSet)
    testsets = get(task_local_storage(), :__BASETESTNEXT__, AbstractTestSet[])
    push!(testsets, ts)
    setindex!(task_local_storage(), testsets, :__BASETESTNEXT__)
end

"""
pop_testset()

Pops the last test set added to the task_local_storage. If there are no
active test sets, returns the default test set.
"""
function pop_testset()
    testsets = get(task_local_storage(), :__BASETESTNEXT__, AbstractTestSet[])
    ret = length(testsets) == 0 ? fallback_testset : pop!(testsets)
    setindex!(task_local_storage(), testsets, :__BASETESTNEXT__)
    return ret
end

"""
get_testset_depth()

Returns the number of active test sets, not including the defaut test set
"""
function get_testset_depth()
    testsets = get(task_local_storage(), :__BASETESTNEXT__, AbstractTestSet[])
    return length(testsets)
end
