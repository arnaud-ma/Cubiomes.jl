using Documenter
using Cubiomes
# using Documenter.Remotes

makedocs(;
    sitename="Cubiomes.jl",
    modules=[Cubiomes],
    repo=Remotes.GitHub("arnaud-ma", "Cubiomes.jl"),
    format=Documenter.HTML(;
        canonical="https://arnaud-ma.github.io/Cubiomes.jl/stable/",
        warn_outdated=true,
    ),
    pages=[
        "Home" => "index.md",
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
#=deploydocs(
    repo = "<repository url>"
)=#
