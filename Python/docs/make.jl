using Python
using Documenter

DocMeta.setdocmeta!(Python, :DocTestSetup, :(using Python); recursive=true)

makedocs(;
    modules=[Python],
    authors="Lilith Hafner <Lilith.Hafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/Python.jl/blob/{commit}{path}#{line}",
    sitename="Python.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/Python.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/Python.jl",
    devbranch="main",
)
