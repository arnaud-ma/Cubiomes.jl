using Documenter
using Literate
using Cubiomes

LITERATE_FILES = map(
    p -> joinpath(@__DIR__, p),
    [
        "src/guide.jl",
    ]
)

const LITERATE_OUTPUTS = map(LITERATE_FILES) do f
    paths = splitpath(f)
    last_ = last(paths)
    if endswith(paths[end], ".jl")
        paths[end] = paths[end][1:(end - 3)] * ".md"
    else
        @warn "File extension is not .jl: $last_"
    end
    joinpath(paths...)
end

function show_error(jl::String)
    return replace(
        jl,
        r"\n(.*)# *show_error *\n" =>
            s"""\n
            try # hide
            \1
            catch err ;showerror(stderr, err) end # hide
            """
    )
end

for (jlfile, mdfile) in zip(LITERATE_FILES, LITERATE_OUTPUTS)
    Literate.markdown(jlfile, dirname(mdfile), preprocess = show_error, documenter = true)  # generate the markdown file
end

makedocs(;
    sitename = "Cubiomes.jl",
    modules = [Cubiomes],
    repo = Remotes.GitHub("arnaud-ma", "Cubiomes.jl"),
    format = Documenter.HTML(
        size_threshold = 2_000_000,
    ),
    pages = [
        "Cubiomes.jl" => "index.md",
        "Manual" => [
            "Getting started" => "gettingstarted.md",
            "Guide" => "guide.md",
        ],
        "API Reference" => [
            "Index" => "api/index.md",
            "Core Components" => [
                "Biomes" => "api/Biomes.md",
                "Biome Generation" => "api/BiomeGeneration.md",
                "MC Versions" => "api/MCVersions.md",
            ],
            "Seeds" => [
                "Seed Utilities" => "api/SeedUtils.md",
                "Random Number Generators" => "api/JavaRNG.md",
            ],
            "Visualization" => [
                "Display" => "api/Display.md",
            ],
            "Low-Level Components" => [
                "Noises" => "api/Noises.md",
                "MC Bugs" => "api/MCBugs.md",
                "Utils" => "api/Utils.md",
            ],
        ],
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/arnaud-ma/Cubiomes.jl.git",
)

# To display locally:
# using LiveServer; servedocs(literate_dir="docs/src")
