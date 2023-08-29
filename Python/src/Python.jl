module Python
__precompile__(false) # I never liked precompilation, anyway

using Reexport
@reexport using PythonCall
include("definitely_not_piracy.jl")
# @reexport using PyCall (we can't have both :( tested and failed. It's possible it's possible, but I don't want to keep trying.)

export @py_str, @pyx_str, @pyv_str, @py

macro py_str(str)
    f = occursin('\n', str) ? pyexec : pyeval
    _py(:($f($str, @__MODULE__)))
end

macro pyx_str(str)
    _py(:(pyexec($str, @__MODULE__)))
end
macro pyv_str(str)
    _py(:(pyeval($str, @__MODULE__)))
end

macro py(str)
    str = esc(str)
    _py(:(f = occursin('\n', $str) ? pyexec : pyeval; f($str, @__MODULE__)))
end

const PYTHON_BUILTIN_SYMBOLS = Set{Symbol}()
function transfer_builtins!()
    isempty(PYTHON_BUILTIN_SYMBOLS) || error("oops!")

    builtins = pyeval("globals()", @__MODULE__)["__builtins__"]
    for name in builtins
        sname = Symbol(name)
        push!(PYTHON_BUILTIN_SYMBOLS, sname)
        isdefined(Base, sname) && continue # don't overwrite Julia builtins
        value = builtins[name]
        @eval Base begin # omg this is bad
            const $sname = $value
            export $sname
        end
    end
end
transfer_builtins!()

const PYTHON_LOCK = ReentrantLock()

using REPL
allnames(mod) = (c.mod for c in REPL.REPLCompletions.complete_symbol(nothing, "", (a, b) -> true, mod))

function _py(exp)
    quote
        lock(PYTHON_LOCK) do
            # Init
            if !isdefined(@__MODULE__, :PYTHON_GLOBALS)
                (@__MODULE__).eval(:(const PYTHON_GLOBALS = pyeval("globals()", @__MODULE__)))
                (@__MODULE__).eval(:(const SYMBOLS_THAT_CANNOT_BE_TRANSFERRED_FROM_PYTHON_TO_JULIA = Set{Symbol}()))
            end

            # Copy all globals from Julia to Python
            for name in allnames(@__MODULE__)
                sname = Symbol(name)
                if isdefined(@__MODULE__, sname) && !startswith(name, '#') && sname ∉ PYTHON_BUILTIN_SYMBOLS && sname ∉ $(esc(:SYMBOLS_THAT_CANNOT_BE_TRANSFERRED_FROM_PYTHON_TO_JULIA))
                    $(esc(:PYTHON_GLOBALS))[name] = getglobal(@__MODULE__, sname)
                end
            end

            # Run the thing
            res = $exp

            # Copy all globals from Python to Julia
            for pysym in $(esc(:PYTHON_GLOBALS))
                sym = Symbol(pysym)
                if !isconst(@__MODULE__, sym) && sym ∉ $(esc(:SYMBOLS_THAT_CANNOT_BE_TRANSFERRED_FROM_PYTHON_TO_JULIA))
                    val = $(esc(:PYTHON_GLOBALS))[pysym]
                    T = isdefined(@__MODULE__, sym) ? typeof(getglobal(@__MODULE__, sym)) : Any
                    val_jl = pyconvert(T, val)
                    try
                        setglobal!(@__MODULE__, sym, val_jl)
                    catch
                        push!($(esc(:SYMBOLS_THAT_CANNOT_BE_TRANSFERRED_FROM_PYTHON_TO_JULIA)), sym)
                    end
                end
            end

            pyconvert(Any, res)
        end
    end
end

rand() < .1 && println("Thi"*"s pack"*"age is"*" a jo"*"ke") # don't want people grepping for this (Shhh!)

py"""
import ast
def is_valid(code, mode):
    try:
        ast.parse(code, mode=mode)
    except SyntaxError:
        return False
    return True

def last_valid(code):
    for i in range(len(code), -1, -1):
        if i == len(code) or code[i] == "\n":
            if is_valid(code[:i], "eval"):
                return (False, i)
            elif is_valid(code[:i], "exec"):
                return (True, i)
    return (False, -1)
"""

const LOG = Ref(true)

function enable_in_core!()
    @eval Base.JuliaSyntax begin
        function parse_docstring(ps::ParseState, down=parse_eq)

            k = peek(ps)

            if k !== K"begin"
                io = ps.stream.lexer.io
                Base.mark(io)
                start = _next_byte(ps.stream)
                seek(io, start-1)
                str = read(io, String)
                reset(io)

                exec, valid = $pyconvert(Tuple{Bool, Int}, $last_valid(str))
                if valid >= 0
                    rand() < .001 && error("TabError: inconsistent use of tabs and spaces in indentation") # TODO: mangle stack trace
                    # println("[[",str[1:valid],"]]")
                    mark = position(ps)
                    stop = start
                    ln = 1
                    for _ in 1:valid
                        ln = nextind(str, ln)
                    end
                    stop += ln-1
                    while _next_byte(ps.stream) < stop
                        # println("bump: ", peek(ps))
                        bump(ps)
                    end
                    emit(ps, mark, exec ? K"⊰" : K"⊱")
                    # If, due to the granularity of tokens, we have consumed the newline
                    # following the python snippet, do not return, because that would trigger
                    # an "extra tokens after end of expression" error. Instead, carry on.
                    peek(ps) ∈ KSet"NewlineWs EndMarker" && return
                end
            end

            mark = position(ps)
            down(ps)
            if peek_behind(ps).kind == K"string"
                is_doc = true
                k = peek(ps)
                if is_closing_token(ps, k)
                    # "notdoc" ] ==> (string "notdoc")
                    is_doc = false
                elseif k == K"NewlineWs"
                    k2 = peek(ps, 2)
                    if is_closing_token(ps, k2) || k2 == K"NewlineWs"
                        # "notdoc" \n]      ==> (string "notdoc")
                        # "notdoc" \n\n foo ==> (string "notdoc")
                        is_doc = false
                    else
                        # Allow a single newline
                        # "doc" \n foo ==> (doc (string "doc") foo)
                        bump(ps, TRIVIA_FLAG) # NewlineWs
                    end
                else
                    # "doc" foo    ==> (doc (string "doc") foo)
                    # "doc $x" foo ==> (doc (string "doc " x) foo)
                    # Allow docstrings with embedded trailing whitespace trivia
                    # """\n doc\n """ foo ==> (doc (string-s "doc\n") foo)
                end
                if is_doc
                    down(ps)
                    emit(ps, mark, K"doc")
                end
            end
        end

        function build_tree(::Type{Expr}, stream::ParseStream;
                                                filename=nothing, first_line=1, kws...)
            source = SourceFile(stream, filename=filename, first_line=first_line)
            txtbuf = unsafe_textbuf(stream)
            args = Any[]
            childranges = UnitRange{Int}[]
            childheads = SyntaxHead[]
            entry = build_tree(_BuildExprStackEntry, stream; kws...) do head, srcrange, nodechildren
                if is_trivia(head) && !is_error(head)
                    return nothing
                end
                k = kind(head)
                k in KSet"⊰ ⊱" && return _BuildExprStackEntry(srcrange, SyntaxHead(K"string", EMPTY_FLAGS),
                    Expr(:macrocall,
                        Symbol("@py$(k === K"⊰" ? "x" : "v")_str"),
                        source_location(LineNumberNode, source, first(srcrange)),
                        source.code[first(srcrange):prevind(source.code, last(srcrange)+1)]))

                if isnothing(nodechildren)
                    ex = _leaf_to_Expr(source, txtbuf, head, srcrange, nothing)
                else
                    resize!(childranges, length(nodechildren))
                    resize!(childheads, length(nodechildren))
                    resize!(args, length(nodechildren))
                    for (i,c) in enumerate(nodechildren)
                        childranges[i] = c.srcrange
                        childheads[i] = c.head
                        args[i] = c.ex
                    end
                    ex = _internal_node_to_Expr(source, srcrange, head, childranges, childheads, args)
                end
                return _BuildExprStackEntry(srcrange, head, ex)
            end
            loc = source_location(LineNumberNode, source, first(entry.srcrange))
            only(_fixup_Expr_children!(SyntaxHead(K"None",EMPTY_FLAGS), loc, Any[entry.ex]))
        end
    end

    Base.JuliaSyntax.enable_in_core!()
end

const BE_EVIL = false;

function __init__()
    enable_in_core!()
    try
        BE_EVIL && add_to_startup_file!() # Folks probably want this in their startup.jl file, right?
    catch
        # ignore
    end
end

function add_to_startup_file!()
    path = joinpath(first(DEPOT_PATH), "config", "startup.jl")
    if isfile(path) && occursin("using Python", read(path, String))
        return
    end

    open(path, "a") do io
        println(io, """

        _stderr = stderr
        redirect_stderr(devnull)
        try
            using Python
        catch
            try
                import Pkg
                Pkg.develop(path="$(dirname(@__DIR__))")
                using Python
            catch
                # silently ignore (this is terrible)
            end
        end
        redirect_stderr(_stderr)
        """)
    end
end

end
