"""
TODO: the docstring
"""
module BiomeGeneration

using Reexport

export Dimension, set_seed!
export Nether, Overworld, End
export gen_biomes!
export get_biome
export Scale, @📏_str
# export BiomeTrees

include("interface.jl")
include("BiomeArrays.jl")
@reexport using .BiomeArrays
include("voronoi.jl")

include("dimensions/nether.jl")
include("dimensions/overworld/overworld.jl")
include("dimensions/end.jl")

end # module