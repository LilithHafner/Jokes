using Test, SuperDataStructures

@testset "special SuperVector indexing" begin
    sv = SuperVector{Int}(10)
    sv .= 10:-1:1
    a = [1,2,3]
    b = [3,2,4]
    c = [a,b,a]
    @test sv[c] == [10,9,8,8,9,7,10,9,8]
end
