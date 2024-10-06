module Cubiomes

export DIM_NETHER, DIM_END, DIM_OVERWORLD
export Noise, MCMap, Scale, @scale_str, gen_biomes!, gen_biomes, get_biome

include("utils.jl")
include("constants.jl")

include("random/rng.jl")
include("random/noise.jl")

include("mc_bugs.jl")
include("biome_generation/infra.jl")
include("biome_generation/nether.jl")
include("biome_generation/end.jl")
include("biome_generation/overworld_1_18_plus.jl")

include("display.jl")

end
