using ..MCVersions

abstract type Overworld <: Dimension end

include("biome_trees/BiomeTrees.jl")
include("1_18_plus.jl")

Overworld(undef::UndefInitializer, V::mcvt">=1.18") = BiomeNoise{V}(undef)

