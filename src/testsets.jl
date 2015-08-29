# All tests belong to a test set. There is a default, task-level
# test set that throws on first failure. Users can wrap their tests in
# nested test sets to achieve other behaviours like not failing
# immediately or writing test results in special formats.

#-----------------------------------------------------------------------
# The AbstractTestSet interface is defined by two methods:
# record(AbstractTestSet, Result)
#   Called by do_test after a test is evaluated
# finish(AbstractTestSet)
#   Called after the test set has been popped from the test set stack
abstract AbstractTestSet


#-----------------------------------------------------------------------
# We provide a simple fallback test set that throws immediately on a
# failure, but otherwise doesn't do much
immutable DefaultTestSet <: AbstractTestSet
end
default_testset = DefaultTestSet()

# Records nothing, and throws any immediately error whenever an error
# or failure occurs. Does nothing for passing tests.
record(ts::DefaultTestSet, t::Pass) = t
function record(ts::DefaultTestSet, t::Union(Fail,Error))
    println(t)
    error("There was an error during testing")
end
# Does nothing
finish(ts::DefaultTestSet) = nothing


#-----------------------------------------------------------------------
# We provide a basic test set that stores results, and doesn't throw
# any exceptions until the end of the test set.
include("basictestset.jl")


#-----------------------------------------------------------------------
"""
@testset "description" begin ... end
@testset begin ... end

Starts a new test set, by default using the BasicTestSet. If using the
BasicTestSet, the test results will be recorded and displayed at the end
of the test set. If there are any failures, an exception will be thrown.
"""
macro testset(args...)
    # Parse arguments to do determine if any options passed in
    if length(args) == 2
        # Looks like description format
        desc, tests = args
        !isa(desc,String) && error("Unexpected argument to @testset")
    elseif length(args) == 1
        # No description provided
        desc, tests = "", args[1]
    elseif length(args) >= 3
        error("Too many arguments to @testset")
    else
        error("Too few arguments to @testset")
    end

    ts = gensym()
    quote
        $ts = BasicTestSet($desc)
        add_testset($ts)
        $(esc(tests))
        pop_testset()
        finish($ts)
    end
end


#-----------------------------------------------------------------------
# Define various helper methods for test sets
"""
get_testset()

Retrieve the active test set from the task's local storage. If no
test set is active, use the fallback default test set.
"""
function get_testset()
    testsets = get(task_local_storage(), :__BASETESTNEXT__, AbstractTestSet[])
    return length(testsets) == 0 ? default_testset : testsets[end]
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
    ret = length(testsets) == 0 ? default_testset : pop!(testsets)
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
