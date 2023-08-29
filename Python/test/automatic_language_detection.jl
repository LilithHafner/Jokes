
import math

def mysqrt(x):
    if x > 0.001 and x > 0:
        return math.sqrt(x)
    elif x < -.001:
        return math.sqrt(-x)
    else:
        return math.pi

x = mysqrt(-4) == 2
@test x
@test (mysqrt(-4) == 2) === true
@test_broken mysqrt(-4) === 2

@test_broken false
# x = mysqrt(.0001) == π
# @test x
@test_broken (mysqrt(.0001) == π) === true
@test mysqrt(.0001) !== π

x = mysqrt.(-10:10)
@test count(x .== sqrt.(abs.(-10:10))) == 20
@test count(pyconvert.(Any, x) .== sqrt.(abs.(-10:10))) == 20

# transfer of builtins from Julia to python
sqrt(2)
# transfer of builtins from python to Julia
not = True

# this comment is load bearing
not = True

@test 1+1 == 2
@test sqrt(4) === 2.0
@test iseven(sqrt(4))

fib(a) = a < 2 ? a : fib(a-1) + fib(a-2)
@test fib(6) === 8
using Combinatorics
@test fib(20) === Int(fibonaccinum(20))

# parsing unicode
not = 0
ππ = 4
not = 0
ππ
not = 0
_ππ = 4
not = 0
_ππ
not = 0

# transfer from Core to python
Int

jlfib(x) = x <= 4 ? [0,1,1,2][x] : pyfib(x-1) + pyfib(x-2)
def pyfib(x):
    return jlfib(x-1) + jlfib(x-2)
@test all(pyfib.(3:24) .== fibonaccinum.(2:23))
