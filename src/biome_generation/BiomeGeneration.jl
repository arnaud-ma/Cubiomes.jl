"""
    BiomeGeneration

Module for generating biomes in Minecraft worlds.

!!! warning
    Like almost everything in this package, the coordinates order is always`(x, z, y)`, not
    `(x, y, z)` weither it is for function calls, world indexing, etc. If it is too
    confusing, hide the order by working directly over the coordinate objects, or use
    keyword arguments.

The typical workflow is:

1. Create a dimension object (e.g. `Overworld`, `Nether`, `End`) -> [`Dimension`](@ref)
2. Set the seed of the dimension -> [`setseed!`](@ref)
3. Get the biome at a specific coordinate -> [`getbiome`](@ref)

Or:

3. Create a world object -> [`WorldMap`](@ref)
4. Generate the biomes in the world -> [`genbiomes!`](@ref)

The biomes are stored in a [`WorldMap`](@ref) object, which is a 3D array of biomes. To get the
coordinates of the biomes, use the [`coordinates`](@ref) function. It gives an iterator of
`CartesianIndex` objects, a built-in Julia type. So any intuitive indexing should work out of
the box.
"""
module BiomeGeneration

using Reexport

export Dimension, Nether, Overworld, End
export setseed!, genbiomes!, getbiome
export Scale, @📏_str

include("interface.jl")
include("voronoi.jl")

include("dimensions/nether.jl")
include("dimensions/overworld/overworld.jl")
include("dimensions/end.jl")

@reexport using .BiomeArrays
end # module
