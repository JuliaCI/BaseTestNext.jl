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
end

