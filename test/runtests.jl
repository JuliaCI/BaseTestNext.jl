using BaseTestNext

@testset "outer" begin
    @testset "inner1" begin
        @test true
        @test false
        @test 1 == 1
        @test 2 == :foo
        @test 3 == 3
        @testset "d" begin
            @test 4 == 4
        end
    end
    @testset "inner1" begin
        @test 1 == 1
        @test 2 == 2
        @test 3 == :bar
        @test 4 == 4
        @testset "errrrr" begin
            @test "not bool"
            @test error()
        end
    end

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
