struct MySet
    data::NTuple{6, Int}
end
function MySet()
    MySet(tuple((0 for _ in 1:6)...))
end
function MySet(x::Int)
    MySet(tuple(x, (0 for _ in 2:6)...))
end
function push(mv::MySet, val::Int)
    for i in 1:6
        mvd = mv.data[i]
        mvd == val && return mv
        if iszero(mvd)
            return MySet(Base.setindex(mv.data, val, i))
        end
    end
    mv
end
function Base.iterate(x::MySet, i::Int = 1)
    if i <= 6 && x.data[i] != zero(typeof(x.data[i]))
        (x.data[i], i+1)
    end
end
isfull(x::MySet) = last(x.data) != 0
Base.copy(x::MySet) = x # TODO: delete all callers
Base.IteratorSize(::Type{MySet}) = Base.SizeUnknown()


######## MySetView ########
struct MySetView
    source::Vector{Int}
    index::Int
end
function Base.push!(mv::MySetView, val::Int)
    for i in mv.index:mv.index+5
        mvd = mv.source[i]
        mvd == val && return
        if iszero(mvd)
            mv.source[i] = val
            break
        end
    end
end
function Base.union!(mv::MySetView, it)
    for val in it
        push!(mv, val)
    end
end
function append!(mv::MySetView, it)
    isempty(it) && return
    for i in mv.index:mv.index+5
        mvd = mv.source[i]
        if mvd == 0
            for val in it
                mv.source[i] = val
                i += 1
                i > mv.index+5 && return
            end
            return
        end
    end
end
function Base.iterate(x::MySetView, i::Int = x.index)
    if i <= x.index+5 && x.source[i] != zero(typeof(x.source[i]))
        (x.source[i], i+1)
    end
end
isfull(x::MySetView) = x.source[x.index+5] != 0
Base.copy(x::MySetView) = MySet(NTuple{6}(x.source[x.index:x.index+5]))
Base.IteratorSize(::Type{MySetView}) = Base.SizeUnknown()
function union(mv::MySet, it::MySetView)
    for val in it
        mv = push(mv, val)
        isfull(mv) && return mv
    end
    mv
end
