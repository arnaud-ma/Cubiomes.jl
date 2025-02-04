"""
TODO: the docstring
"""
module BiomeGeneration

using Reexport

export Nether, Overworld, End
export set_seed!, gen_biomes!, get_biome
export Scale, @📏_str

include("interface.jl")
# include("BiomeArrays.jl")
@reexport using .BiomeArrays
include("voronoi.jl")

include("dimensions/nether.jl")
include("dimensions/overworld/overworld.jl")
include("dimensions/end.jl")

end # module