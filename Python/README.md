# Python

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/Python.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/Python.jl/dev/)
[![Build Status](https://github.com/LilithHafner/Python.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/Python.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/Python.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/Python.jl)

```
julia> import Pkg; Pkg.add(url="https://github.com/LilithHafner/Jokes", subdir="Python"); using Python
[...]

julia> class Greeter:
           def __init__(self, name):
               self.name = name

           def greet(self):
               return "Hello " + self.name + "!\n"

julia> gs = Greeter.(split("Julia Python"))
2-element Vector{Py}:
 <Greeter object at 0x1337a5e50>
 <Greeter object at 0x1337a5e90>

julia> for g in gs
           print(g.greet())
       end
Hello Julia!
Hello Python!

julia> len(gs)
2
```
