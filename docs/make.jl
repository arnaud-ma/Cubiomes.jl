using Documenter
using Literate
using Cubiomes
# using DocumenterVitepress
# try run(`pkill -f vitepress`) catch end

const LITERATE_INPUT = joinpath(@__DIR__, "src/literate/")
const LITERATE_OUTPUT = joinpath(@__DIR__, "src/literate_generated/")

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

for (root, dirs, files) in walkdir(LITERATE_INPUT), file in files
    !endswith(file, ".jl") && continue   # ignore non .jl files
    ifile = joinpath(root, file) # full path to the file
    out = splitdir(replace(ifile, LITERATE_INPUT => LITERATE_OUTPUT))[1]  # output directory
    Literate.markdown(ifile, out, preprocess=show_error)  # generate the markdown file
end

makedocs(;
    sitename="Cubiomes.jl",
    modules=[Cubiomes],
    repo=Remotes.GitHub("arnaud-ma", "Cubiomes.jl"),
    format=Documenter.HTML(
        size_threshold=2_000_000,
    ),
    # format=MarkdownVitepress(
    #     repo="https://github.com/arnaud-ma/Cubiomes.jl"
    # ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "gettingstarted.md",
        "Guide" => "literate_generated/guide.md",
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
# servedocs(literate_dir=LITERATE_INPUT, skip_dir=LITERATE_OUTPUT)