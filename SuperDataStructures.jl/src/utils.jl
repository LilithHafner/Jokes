delete_at(t, i) = ntuple(j -> t[j + (j >= i)], length(t)-1)

index(a, b, c) = a*6 + evalpoly(b, (0,-9,3)) + evalpoly(c, (-5,11,-6,1))
index(a, b, c, d) = index(a, b, c) + evalpoly(d, (24,-50,35,-10,1)) >> 2

next(x) = x + one(x)
next(x, xs...) = reverse(_next(reverse((x, xs...))...))
_next(x) = next(x)
function _next(x, xs...)
    candidate = _next(xs...)
    candidate[1] < x ? (x, candidate...) : (x+1, (length(xs):-1:1)...)
end
