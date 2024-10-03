using cubiomes
using Documenter

DocMeta.setdocmeta!(cubiomes, :DocTestSetup, :(using cubiomes); recursive=true)

makedocs(;
    modules=[cubiomes],
    authors="arnaud-ma <arnaudma.code@gmail.com> and contributors",
    sitename="cubiomes.jl",
    format=Documenter.HTML(;
        canonical="https://arnaud-ma.github.io/cubiomes.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/arnaud-ma/cubiomes.jl",
    devbranch="main",
)
