"""
TODO: the docstring
"""
module BiomeGeneration

    export Dimension, set_seed!
    export MCMap, similar_expand
    export Nether
    export gen_biomes, gen_biomes!, gen_biomes_unsafe!
    export get_biome, get_biome_unsafe
    export Scale, @📏_str
    export BiomeTrees

    public origin_coords

    include("biomes.jl")
    include("interface.jl")

    include("nether.jl")

    include("overworld/biome_trees/BiomeTrees.jl")
    include("overworld/1_18_plus.jl")
    # include("end.jl")

end # module