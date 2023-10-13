# SuperDataStructures

Provides two types `SuperDict <: AbstractDict` and `SuperVector <: AbstractVector` that
behave similarly to their `Base` counterparts, except with different performance
characteristics including speculative optimization and aggressive broadcast fusion in
certain rare cases.

`SuperDict` is a read-only and universe-aware default dictionary. It is constructed via
`SuperDict{K, V}(universe)` which returns a dictionary that maps every `key::K ∈ universe`
to a lazily constructed `V()` object. This is useful when `V` is a mutable type so you can
do things like `push!(my_super_dict[key], value)`.

`SuperVector` is and `AbstractVector` and behaves like `Vector` except that it supports
an indexing mode that regular vectors do not support, namely indexing by a list of lists
of indices. For example `my_super_vector[[[1,2],[3,4]]]` will return a vector of length
4 equal to `my_super_vector[1:4]`.

-----

This package is also a demonstration of how it is possible to perform arbitrarily complex
and specific optimizations within a general purpose API such as the `AbstractVector` and
`AbstractDict` APIs. It's also very sneaky.

-----

This package is also a total joke. Don't use it for anything serious (benchmarking is not a
serious use, feel free to use this in benchmarking).
