# This file is a part of Julia. License is MIT: http://julialang.org/license

"""
DefaultTestSet

If using the DefaultTestSet, the test results will be recorded. If there
are any `Fail`s or `Error`s, an exception will be thrown only at the end,
along with a summary of the test results.
"""
immutable DefaultTestSet <: AbstractTestSet
    description::String
    results::Vector
end
DefaultTestSet() = DefaultTestSet("", [])
DefaultTestSet(desc) = DefaultTestSet(desc, [])

# For a passing result, simply store the result
record(ts::DefaultTestSet, t::Pass) = (push!(ts.results, t); t)
# For the other result types, immediately print the error message
# but do not terminate. Print a backtrace.
function record(ts::DefaultTestSet, t::Union(Fail,Error))
    print_with_color(:white, ts.description, ": ")
    print(t)
    Base.show_backtrace(STDOUT, backtrace())
    println()
    push!(ts.results, t)
    t
end

# When a DefaultTestSet finishes, it records itself to its parent
# testset, if there is one. This allows for recursive printing of
# the results at the end of the tests
record(ts::DefaultTestSet, t::AbstractTestSet) = push!(ts.results, t)

# Called at the end of a @testset, behaviour depends on whether
# this is a child of another testset, or the "root" testset
function finish(ts::DefaultTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return
    end
    # Calculate the alignment of the test result counts by
    # recursively walking the tree of test sets
    align = get_alignment(ts, 0)
    # Calculate the overall number for each type so each of
    # the test result types are aligned
    passes, fails, errors, c_passes, c_fails, c_errors = get_test_counts(ts)
    dig_pass  = passes + c_passes > 0 ? ndigits(passes + c_passes) : 0
    dig_fail  = fails  + c_fails  > 0 ? ndigits(fails  + c_fails)  : 0
    dig_error = errors + c_errors > 0 ? ndigits(errors + c_errors) : 0
    total = passes + c_passes + fails  + c_fails + errors + c_errors
    dig_total = total > 0 ? ndigits(total) : 0
    # Print the outer test set header once
    print_with_color(:white, "Test Summary:\n")
    # Recursively print a summary at every level
    print_counts(ts, 0, align, dig_pass, dig_fail, dig_error, dig_total)
end

# Recursive function that finds the column that the result counts
# can begin at by taking into account the width of the descriptions
# and the amount of indentation
function get_alignment(ts::DefaultTestSet, depth::Int)
    # The minimum width at this depth is...
    ts_width = 2*depth + length(ts.description)
    # Return the maximum of this width and the minimum width
    # for all children (if they exist)
    length(ts.results) == 0 && return ts_width
    child_widths = map(t->get_alignment(t, depth+1), ts.results)
    return max(ts_width, maximum(child_widths))
end
get_alignment(ts, depth::Int) = 0

# Recursive function that counts the number of test results of each
# type directly in the testset, and totals across the child testsets
function get_test_counts(ts::DefaultTestSet)
    passes, fails, errors = 0, 0, 0
    c_passes, c_fails, c_errors = 0, 0, 0
    for t in ts.results
        isa(t, Pass)  && (passes += 1)
        isa(t, Fail)  && (fails  += 1)
        isa(t, Error) && (errors += 1)
        if isa(t, DefaultTestSet)
            np, nf, ne, ncp, ncf, nce = get_test_counts(t)
            c_passes += np + ncp
            c_fails  += nf + ncf
            c_errors += ne + nce
        end
    end
    return passes, fails, errors, c_passes, c_fails, c_errors
end

# Recursive function that prints out the results at each level of
# the tree of test sets
function print_counts(ts::DefaultTestSet, depth, align,
                        dig_pass, dig_fail, dig_error, dig_total)
    # Count results by each type at this level, and recursively
    # through and child test sets
    passes, fails, errors, c_passes, c_fails, c_errors = get_test_counts(ts)
    subtotal = passes + fails + errors + c_passes + c_fails + c_errors

    # Print test set header, with an alignment that ensures all
    # the test results appear above each other
    print(rpad(string("  "^depth, ts.description), align, " "), " | ")

    np = passes + c_passes
    if np > 0
        print_with_color(:green, "Pass: ")
        print(lpad(string(np), dig_pass, " "), "  ")
    elseif dig_pass > 0
        # No passes at this level, but some at another level
        print(" "^(8 + dig_pass))
    end

    nf = fails + c_fails
    if nf > 0
        print_with_color(:red, "Fail: ")
        print(lpad(string(nf), dig_fail, " "), "  ")
    elseif dig_fail > 0
        # No fails at this level, but some at another level
        print(" "^(8 + dig_fail))
    end
    ne = errors + c_errors
    if ne > 0
        print_with_color(:red, "Error: ")
        print(lpad(string(ne), dig_error, " "), "  ")
    elseif dig_error > 0
        # No errors at this level, but some at another level
        print(" "^(9 + dig_error))
    end
    
    if np == 0 && nf == 0 && ne == 0
        print_with_color(:blue, "No tests")
    else
        print_with_color(:blue, "Total: ")
        print(lpad(string(subtotal), dig_total, " "), "  ")
    end
    println()

    for t in ts.results
        if isa(t, DefaultTestSet)
            print_counts(t, depth + 1, align,
                            dig_pass, dig_fail, dig_error, dig_total)
        end
    end
end