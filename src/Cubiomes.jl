module Cubiomes

export MCMap, Scale, @scale_str, @📏_str
export Nether
export gen_biomes!, gen_biomes, get_biome

# include("utils.jl")
# include("random/rng.jl")
# include("random/noise/noise.jl")

# include("mc_bugs.jl")
# include("biome_generation/biomes.jl")
# include("biome_generation/infra.jl")
include("biome_generation/nether.jl")
# include("biome_generation/end.jl")
# # include("biome_generation/overworld_1_18_plus.jl")

# include("display.jl")

end