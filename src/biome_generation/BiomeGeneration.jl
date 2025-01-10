"""
TODO: the docstring
"""
module BiomeGeneration

    export Dimension, set_seed!
    export MCMap, similar_expand
    export Nether
    export Scale, @📏_str

    public origin_coords

    include("biomes.jl")
    include("interface.jl")

    include("nether.jl")
    include("_overworld_2.jl")
    # include("end.jl")

end # module