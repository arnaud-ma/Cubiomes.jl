# Guide

## Minecraft versions

To get a Minecraft version, simply use the `mcv` keyword (stands for **M**ine**c**raft **v**ersion). For example:

```julia-repl
julia> mcv"1.18"
mcv"1.18.2"
```

Note that it is returned `mcv"1.18.2"`. This is because Cubiomes.jl only focuses on the latest minor version, and so `mcv"1.18"` is *exactly* the same as `mcv"1.18.2`. Generally, everything remains the same between minor versions. But to be safe, be sure to verify that the version is the same as the one you are looking for.

Comparing versions is possible. But the main uses of the versions is to link them to dimensions.

## Dimension objects

In a lot of cases, you need to specify a dimension to work with. The three dimensions are:

- `Overworld`
- `Nether`
- `End`

They all are subtypes of the abstract type `Dimension`. A dimension object is always associated with a Minecraft version.

```julia-repl
julia> overworld = Overworld(undef, mcv"1.18")
Cubiomes.BiomeGeneration.BiomeNoise{mcv"1.18.2"}(...)
```

As suggests the `undef` argument, the object is "empty" and completely usless. A Minecraft seed must be set to the object before using it:

```julia-repl
julia> set_seed!(overworld, 42)
```

The seed can be any valid Minecraft seed, i.e. a string or an integer. But if performance is a concern, it is better to use an integer.

The "!" at the end of the function name is a Julia convention to indicate that the function modifies the object inplace. In this case, it modifies the `overworld` object to set the seed. It allows to avoid creating a new object each time the seed is set, keeping the same `overworld` object for every seed we want to use, and thus saving time and memory.

## Biome generation

We now have three informations combined in a single `Dimension` object:

- A dimension
- A Minecraft version
- A seed

To get the biome at a specific location, use the `get_biome` function:

```julia-repl
julia> get_biome(overworld, 0, 0, 63)
dark_forest::Biome = 0x1d

julia> get_biome(overworld, (0, 0, 63))  # different syntax
dark_forest::Biome = 0x1d
```

!!! warning
    In Cubiomes.jl, the order of the coordinates is **ALWAYS** `(x, z, y)`. This is different from the order used in Minecraft, which is `(x, y, z)`.

## Biome generation on a WorldMap

To generate a map of biomes, we can think about creating a matrix or a 3D array and using `get_biome` for each block. But Cubiomes.jl provides a more easy and efficient way to do this: the `WorldMap` object combined with the `gen_biomes!` function.

```julia-repl
julia> worldmap = WorldMap(x=-100:100, z=-100:100, y=63)
2001×2001×1 OffsetArray(::Array{Biome, 3}, -1000:1000, -1000:1000, 63:63) with eltype Biome with indices -1000:1000×-1000:1000×63:63:
[:, :, 63] =
 BIOME_NONE::Biome = 0xff ...

julia> gen_biomes!(overworld, worldmap)
2001×2001×1 OffsetArray(::Array{Biome, 3}, -1000:1000, -1000:1000, 63:63) with eltype Biome with indices -1000:1000×-1000:1000×63:63:
[:, :, 63] =
 beach::Biome = 0x10 ...

julia> worldmap[0, 0, 63] # get the biome at the location (0, 0, 63)
dark_forest::Biome = 0x1d
```

The `WorldMap` object is an alias for any 3D / 2D array (depending if `y` is passed or not). The indices of the array are the real coordinates of the world. The `gen_biomes!` function fills the array with the biomes. For some versions / dimensions, `gen_biomes!` can be much faster than calling `get_biome` for each block, because it has a global view of the world, and can use this information to optimize the biome generation.

Same as for the `Dimension` object, the "!" at the end of the function name indicates that the function modifies the world map inplace. So no need to create a new world map each time you want to generate the biomes where a parameter is different (except for the map size of course).

## More about performance: scales
