# High-level interface

## Minecraft versions

To get a Minecraft version, simply use the `mcv` keyword (stands for **M**ine**c**raft **v**ersion). For example:

```julia-repl
julia> mcv"1.18"
mcv"1.18.2"
```

Note that it is returned `mcv"1.18.2"`. This is because Cubiomes.jl only focuses on the latest minor version, and so `mcv"1.18"` is *exactly* the same as `mcv"1.18.2`. Generally, everything remains the same between minor versions. But to be safe, be sure to verify that the version is the same as the one you are looking for.

Comparing versions is possible. But the main uses of the versions is to link them to the dimension objects

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

As suggest the `undef` argument, the object is "empty" and completely usless. A Minecraft seed must be set to the object before using it:

```julia-repl
julia> set_seed!(overworld, 42)
```

The seed can be any valid Minecraft seed, i.e. a string or an integer. But if performance is a concern, it is better to use an integer. Use `signed` and `unsigned` to convert between the two number types.

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
```

!!! warning
    In Cubiomes.jl, the order of the coordinates is **ALWAYS** `(x, z, y)`. This is different from the order used in Minecraft, which is `(x, y, z)`.
