using Python
using Test

@testset "Python.jl" begin

    @test py"1 + 1" === 2
    py"""
    foo = 3
    """
    @test foo === 3
    @test py"foo**3" === 3^3

    for i in 1:100
        @py """
        i$i = $i
        """
    end

    @test i17 === 17
end

# TODO: this doesn't work in a testset because of scope issues.
@test_broken false
# Only globals are transferred, not locals. So python can only be entered at the top level.
y = 4

py"""
y += 7
"""

@test y === 11

y = exp(y)

py"""
z = y/2
"""

@test z ≈ exp(11)/2
@test z isa Float64

py"""
def invert(x):
    return 1/x
"""

@test pyconvert(Any, py"invert(7)") === 1/7

# Automatic language detection fails on the same file as `using Python`
@test_broken false
# import math

include("automatic_language_detection.jl")

# help mode
@test_broken false

include("parse_example_1.jl")
include("parse_example_2.jl")

not = Meta.parse("""begin
    1
    #
    not = 1
end""")

code = """
def mysqrt(x):
    if x > 0.001 and x > 0:
        return math.sqrt(x)
    elif x < -.001:
        return math.sqrt(-x)
    else:
        return math.pi"""
Meta.parse(code) == Expr(:macrocall, Symbol("@pyx_str"), Base.LineNumberNode(2, :none), code[2:end])
