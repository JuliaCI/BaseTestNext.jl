using BaseTestNext
#=
macro foo(ex)
   dump(ex)
   for e in ex.args
       if isa(e, LineNumberNode)
           return :($(e.line))
       elseif (e.head == :line)
           return :($(e.args[1]))
       end
   end
end
#@foo (1==2)
@show (@foo begin
           1+1
           2+2
           3+3
       end)
=#

#println()
@testset "outer" begin
    @testset "inner1" begin
        @test 1 == 1
        @test 2 == 2
        @test 3 == 3
        @testset "d" begin
          @test 4 == 4
        end
    end
    #println()
    @testset "inner1" begin
        @test 1 == 1
        @test 2 == 2
        @test 3 == 3
        @test 4 == 4
    end
    #println()

    @testset "loop with desc" begin
        @testloop "loop1 $T" for T in (Float32, Float64)
            @test 1 == T(1)
        end
    end
    @testset "loops without desc" begin
        @testloop for T in (Float32, Float64)
            @test 1 == T(1)
        end
        @testloop for T in (Float32, Float64), S in (Int32,Int64)
            @test S(1) == T(1)
        end
    end
end

@testset "should print" verbosity=0 begin
    @testset "should not print" begin
        @test 1 == 1
        @test 2 == 2
        @test 3 == 3
        @testset "should not print" begin
          @test 4 == 4
        end
    end
    # this should print because a child will print
    @testset "should print" begin
        @test 1 == 1
        @test 2 == 2
        @test 3 == 3
        @testset "should print" verbosity=1 begin
          @test 4 == 4
        end
    end
    # this should print because it has an error
    @testset "should print" begin
        @test 1 == 1
        @test 2 == 1
        @test 3 == 3
        @test 4 == 4
    end
end
