module SuperDataStructures

export SuperDict, SuperVector

include("utils.jl")
include("myset.jl")

######## LazyMultipleGetindex ########
struct LazyMultipleGetindex{N, K <: AbstractArray{<:Any, N}, V, D} <: AbstractArray{V, N}
    keys::K
    data::D
end
Base.size(x::LazyMultipleGetindex) = size(x.keys)
Base.axes(x::LazyMultipleGetindex) = axes(x.keys)
Base.getindex(x::LazyMultipleGetindex, inds...) = getindex(x.data, getindex(x.keys, inds...))
Base.setindex!(x::LazyMultipleGetindex, v, inds...) = setindex!(x.data, v, getindex(x.keys, inds...))
struct LazyVcat{T, D} <: AbstractVector{T}
    data::D
end
function find_index(x::LazyVcat, i::Int)
    i <= 0 && throw(BoundsError(x, i))
    i0 = i
    for d in x.data
        Base.require_one_based_indexing(d)
        if i <= length(d)
            return d, i
        end
        i -= length(d)
    end
    throw(BoundsError(x, i0))
end
Base.getindex(x::LazyVcat, i::Int) = getindex(find_index(x, i)...)
function Base.setindex!(x::LazyVcat, v, i::Int)
    d, i = find_index(x, i)
    setindex!(d, v, i)
end
Base.size(x::LazyVcat) = (sum(length, x.data),)
Base.reduce(::typeof(vcat), x::LazyMultipleGetindex{1, D, V}) where {D, V} = LazyVcat{eltype(V), typeof(x)}(x)

struct View{T, P, I} <: AbstractVector{T}
    parent::P
    indices::I
end
View(p, i) = View{eltype(p), typeof(p), typeof(i)}(p, i)
Base.size(v::View) = size(v.indices)
Base.getindex(v::View, i::Int) = getindex(v.parent, getindex(v.indices, i))
Base.setindex!(v::View, val, i::Int) = setindex!(v.parent, val, getindex(v.indices, i))

######## SuperDict ########
# Could be QuicklyPartialsortableUniverseAwareDefaultDict, but SuperDict sounds better
struct SuperDict{K, V <: AbstractVector{Int}} <: AbstractDict{K, V}
    universe::Dict{K, Int}
    cache::Dict{K, V}
    d5::Dict{NTuple{5, K}, MySet}
    d4::Vector{Int}
    d3::Vector{Int}
    instantiated::Ref{Bool}
end

"""
    SuperDict{K, V}(universe) <: AbstractDict{K, V}

Create a read-only default-dictionary mapping keys of type `K` drawn from provided
`universe` to values of type `V`. The default value is an empty `V`, constructed via `V()`.

As a read-only dictionary, `SuperDict` does not support `setindex!` and friends. However,
by using a mutable V, it is possible to mutate the values of the dictionary.

SuperDict is reasonably fast in normal usage, but contains some optimizations that make it
super fast in certain cases.
"""
SuperDict{K, V}(universe) where {K, V} =
    SuperDict{K, V}(
        Dict(k => i for (i, k) in enumerate(sort!(collect(universe)))),
        Dict{K,V}(),
        Dict{NTuple{5, K}, MySet}(),
        fill(0, 6*binomial(length(universe), 4)),
        fill(0, 6*binomial(length(universe), 3)),
        Ref(false))

function Base.getindex(d::SuperDict{K, V}, key::K) where {K, V}
    key in keys(d.universe) || throw(KeyError(key))
    get!(d.cache, key) do
        instantiate!(d)
        res = V()
        k = d.universe[key]
        for i in 1:k-1
            for j in i+1:k-1
                union!(res, getd34(d, i, j, k))
            end
            for j in k+1:length(d.universe)
                union!(res, getd34(d, i, k, j))
            end
        end
        for i in k+1:length(d.universe)-1, j in i+1:length(d.universe)
            union!(res, getd34(d, k, i, j))
        end
        res
    end
end

function instantiate!(d::SuperDict)
    d.instantiated[] && return
    i = tuple(1:4...)
    for k in 1:6:length(d.d4)
        vals = MySetView(d.d4, k)
        for j in 1:4
            # using append! instead of union! may hurt performance in spooky ways (happy halloween!)
            append!(MySetView(d.d3, index(delete_at(i, j)...)), vals)
        end
        i = next(i...)
    end
    d.instantiated[] = true
end

Base.keys(d::SuperDict) = keys(d.universe)
const SUPERDICT_ITERATION_SECRET = :__6da7838fdff8b64e1e25a31da0e3fc99__
function Base.iterate(d::SuperDict, i=SUPERDICT_ITERATION_SECRET)
    ks = keys(d)
    xi = i===SUPERDICT_ITERATION_SECRET ? iterate(ks) : iterate(ks, i)
    xi === nothing && return nothing
    (x, i) = xi
    (x, d[x]), i
end
Base.length(d::SuperDict) = length(keys(d))

getd34(d, args...) = getd34(d, (d.universe[arg] for arg in args)...)
getd34(d, args::Int...) = getd34(d, Val(length(args)), index(args...))
getd34(d, ::Val{3}, index) = MySetView(d.d3, index)
getd34(d, ::Val{4}, index) = MySetView(d.d4, index)

function Base.getindex(d::SuperDict{K}, keys::AbstractArray{K}) where K
    LazyMultipleGetindex{ndims(keys), typeof(keys), valtype(d), typeof(d)}(keys, d)
end

# Speculative optimization
function Base.broadcasted(::typeof(push!), lmg::LazyMultipleGetindex{<:Any, <:Any, <:Any, <:SuperDict}, i::Int)
    if isempty(lmg.data.cache)
        if length(lmg.keys) == 5
            keys = NTuple{5}(lmg.keys)
            lmg.data.d5[keys] = push(get(lmg.data.d5, keys, MySet()), i)
            keysi = tuple((lmg.data.universe[tag] for tag in keys)...)
            for j in 1:5
                push!(MySetView(lmg.data.d4, index(delete_at(keysi, j)...)), i)
            end
            return
        elseif length(lmg.keys) == 4
            keys = NTuple{4}(lmg.keys)
            keysi = tuple((lmg.data.universe[tag] for tag in keys)...)
            push!(MySetView(lmg.data.d4, index(keysi...)), i)
            return
        end
    end
    for key in lmg.keys
        push!(lmg.data[key], i)
    end
end

const Z6 = (0,0,0,0,0,0)
struct SuperVector{T <: Number} <: AbstractVector{T}
    length::Int
    top6::Ref{NTuple{6, Int}}
    state::Ref{Any}
    # ops::Vector{Any}
end
# SuperVector{T}(n) where T = SuperVector{T}(n, Ref(Z), Vector{Any}())
SuperVector{T}(n) where T = SuperVector{T}(n, Ref(Z6), nothing)
function zero!(sv::SuperVector)
    sv.top6[] = Z6
    # empty!(sv.ops)
    sv.state[] = nothing
end
function Base.getindex(sv::SuperVector, i::Int)
    sv.state[] === nothing && return zero(eltype(sv))
    sv.state[] isa Vector && return sv.state[][i]
    instantiate!(sv, sv.state[]...)
    sv.state[][i]
end
function Base.setindex!(sv::SuperVector, v, inds...)
    sv.top6[] = Z6
    setindex_noreset!(sv, v, inds...)
end
function setindex_noreset!(sv::SuperVector, v, inds...)
    if sv.state[] === nothing
        sv.state[] = (setindex!, sv, v, inds...)
    elseif sv.state[] isa Vector
        setindex!(sv.state[], v, inds...)
    else
        instantiate!(sv, sv.state[]...)
        setindex!(sv.state[], v, inds...)
    end
    sv
end
function instantiate!(sv::SuperVector, f, args...)
    sv.state[] = fill(zero(eltype(sv)), length(sv))
    f(args...)
end

Base.size(x::SuperVector) = (x.length,)
Base.to_indices(::SuperVector, inds::Tuple{AbstractVector{<:AbstractVector}}) = (reduce(vcat, only(inds)),)

# optimization
function Broadcast.materialize!(target::View{Int, SuperVector{Int}, LazyVcat{Int, LazyMultipleGetindex{1, Vector{String}, Vector{Int}, SuperDict{String, Vector{Int}}}}}, source::Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1}, Nothing, typeof(+), Tuple{View{Int, SuperVector{Int}, LazyVcat{Int, LazyMultipleGetindex{1, Vector{String}, Vector{Int}, SuperDict{String, Vector{Int}}}}}, Int}})
    if target.parent.state[] === nothing
        data = source.args[1].indices.data
        d = data.data
        instantiate!(d)
        t6 = if length(data.keys) == 5
            keys = NTuple{5, String}(data.keys)
            t6 = copy(d.d5[keys])
            keysi = tuple((d.universe[k] for k in keys)...)
            for j in 1:5
                t6 = union(t6, MySetView(d.d4, index(delete_at(keysi, j)...)))
                if isfull(t6)
                    break
                end
            end
            if !isfull(t6)
                for (j1, j2, j3) in ((1, 2, 3), (1, 2, 4), (1, 3, 4), (2, 3, 4), (1, 2, 5), (1, 3, 5), (2, 3, 5), (1, 4, 5), (2, 4, 5), (3, 4, 5))
                    v = MySetView(d.d3, index(keysi[j1], keysi[j2], keysi[j3]))
                    t6 = union(t6, v)
                    if isfull(t6)
                        break
                    end
                end
            end
            t6
        elseif length(data.keys) == 4
            keys = NTuple{4, String}(data.keys)
            keysi = tuple((d.universe[k] for k in keys)...)
            t6 = copy(MySetView(d.d4, index(keysi...)))
            for j in 1:4
                k = delete_at(keysi, j)
                v = MySetView(d.d3, index(k...))
                t6 = union(t6, v)
                if isfull(t6)
                    break
                end
            end
            t6
        end
        if t6 !== nothing && count(_->true,t6) == 6
            target.parent.top6[] = NTuple{6}(t6)
            target.parent.state[] = (Broadcast.materialize!, Broadcast.combine_styles(target, source), target, source)
            return
        end
    end
    Broadcast.materialize!(Broadcast.combine_styles(target, source), target, source)
end
function Base.materialize!(target::SuperVector, source::Broadcast.Broadcasted{<:Any, <:Any, typeof(identity), <:Tuple{Number}})
    if iszero(only(source.args))
        zero!(target)
        target
    else
        Broadcast.materialize!(Broadcast.combine_styles(target, source), target, source)
    end
end

function Base.partialsortperm(v::SuperVector, k::UnitRange; kwargs...)
    if values(kwargs) === (rev = true,) && k == 1:6 && v.top6[] != Z6
        v.top6[]
    else
        partialsortperm!(similar(Vector{eltype(k)}, axes(v,1)), v, k; kwargs..., initialized=false)
    end
end

Base.view(parent::SuperVector, indices::LazyMultipleGetindex) = View(parent, reduce(vcat, indices))

end