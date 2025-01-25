"""
TODO: the docstring
"""
module BiomeGeneration

    export Dimension, set_seed!
    export MCMap, similar_expand, origin_coords
    export Nether, BiomeNoise
    export gen_biomes, gen_biomes!
    export get_biome
    export Scale, @📏_str
    # export BiomeTrees

    include("biomes.jl")
    include("interface.jl")

    include("nether.jl")

    include("overworld/biome_trees/BiomeTrees.jl")
    include("overworld/1_18_plus.jl")
    # include("end.jl")

end # module