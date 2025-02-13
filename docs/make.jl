using Documenter
using Literate
using Cubiomes
using DocumenterVitepress
try run(`pkill -f vitepress`) catch end

# const LITERATE_INPUT = joinpath(@__DIR__, "src/literate/")
const LITERATE_FILES = [
    "src/guide.jl",
]
const LITERATE_OUTPUTS = [replace(lit, ".jl" => ".md") for lit in LITERATE_FILES]
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
    Literate.markdown(jlfile, dirname(mdfile), preprocess=show_error)  # generate the markdown file
end

makedocs(;
    sitename="Cubiomes.jl",
    modules=[Cubiomes],
    repo=Remotes.GitHub("arnaud-ma", "Cubiomes.jl"),
    # format=Documenter.HTML(
    #     size_threshold=2_000_000,
    # ),
    format=MarkdownVitepress(
        repo="https://github.com/arnaud-ma/Cubiomes.jl",
        # md_output_path=".",
        # build_vitepress=false,
    ),
    # clean=false,
    pages=[
        "Cubiomes.jl" => "index.md",
        "Manual" => [
            "Getting started" => "gettingstarted.md",
            "Guide" => "guide.md",
        ],
        "API Reference" => [
            "Biomes" => "api/Biomes.md",
            "BiomeGeneration" => "api/BiomeGeneration.md",
            "MCBugs" => "api/MCBugs.md",
            "MCVersions" => "api/MCVersions.md",
            "Noises" => "api/Noises.md",
            "SeedUtils" => "api/SeedUtils.md",
            "Utils" => "api/Utils.md",
        ],
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/arnaud-ma/Cubiomes.jl.git",
)


# using LiveServer
# servedocs(literate_dir=, skip_fikes=LITERATE_OUTPUTS)