"""
TODO: the docstring
"""
module BiomeGeneration

export Dimension, set_seed!
export MCMap, similar_expand, origin_coords
export Nether, Overworld, End
export gen_biomes!
export get_biome
export Scale, @📏_str
# export BiomeTrees

include("biomes.jl")
include("interface.jl")

include("nether.jl")

include("overworld/overworld.jl")
include("end.jl")

end # module