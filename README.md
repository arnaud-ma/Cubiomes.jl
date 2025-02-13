# Cubiomes.jl

<!--- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/Cubiomes.jl/stable/)
--->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://arnaud-ma.github.io/Cubiomes.jl/dev/)
[![Build Status](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml?query=branch%3Amain)

A rewrite of [Cubiomes](https://github.com/Cubitect/cubiomes) but in [Julia](https://julialang.org/), intended to be (much) easier to use and to contribute to, and faster.

> [!WARNING]
> The code is still in early development, and everything can change at any time. This repo should be seen as a proof of concept and nothing else.

## Why Cubiomes.jl?

- **Readability and ease of use**: Julia is a high-level language, which makes the code easier to read and understand. Of course to be fast, it is sometimes necessary to write more complex code, but if it is simply to use an API (like the one of Cubiomes), it a very easy Python-like language.

- **Performance**: Julia is almost as fast as C. For this case, it is in fact faster because uh so actually I don't know why lol but i always measure 2-3x speedup.

## Installation

The package is still early in development, so it is not yet registered. You can install it via the github repository, in the Julia REPL:

```julia
julia> ] add github.com/arnaud-ma/cubiomes.jl
```

## Usage

### Biome generation

Let's create a simple program which tests seeds for a mushroom fields biome at a predefined location.

```julia
using Cubiomes
using Base.Iterators: countfrom

function search_biome_at(x, z, y)
    overworld = Overworld(undef, mcv"1.18")

    for seed in countfrom(zero(UInt64))
        set_seed!(overworld, seed)
        biome = get_biome(overworld, x, z, y)

        if biome == Biomes.mushroom_fields
            println("Seed $(signed(seed)) has a Mmushroom Fields at $((x, z, y))")
            break
        end
    end
end

search_biome_at(0, 0, 63)
```

Notice:

- The order of the coordinates is `(x, z, y)` and **never** `(x, y, z)` in the entire package.
- The syntax `mcv"1.18"` represent the Minecraft version.
- The `!` at the end of the function `set_seed!` is a Julia convention to indicate that the function modifies the object inplace. In this case, it modifies the overworld object to set the seed. This is more import in the next example, when we are dealing with containers of biomes.

### World map generation

To generate a map of biomes, you need to create a `World` object that is simply a 3D / 2D array of biomes, with the real coordinates of the world as indices. Use `gen_biomes!`
to fill the world with the biomes. It can be much faster than calling `get_biome` for each block.
Here is an example that generate the biomes and save the map as an image:

```julia
using Cubiomes
using FileIO

const overworld1_18 = Overworld(undef, mcv"1.18")
const worldmap = WorldMap(x=-1000:1000, z=-1000:1000, y=63)

function save_as_img!(worldmap, seed, path)
    set_seed!(overworld1_18, seed)
    gen_biomes!(overworld1_18, worldmap, 📏"1:16")

    world2d = view2d(worldmap)
    save(path, to_color(world2d))
end

save_as_img!(worldmap, 42, "world.png")
```

<details>
<summary>show world.png</summary>
<img src="docs/src/assets/world.png" alt="World map"/>
</details>

Some comments:

- In Julia, constants global variables must be declared with `const` to avoid performance penalties.
- The emoji `📏` is an optional argument used to represent the scale of the biomes. For example here, `📏"1:16"` means that one biome value in the map corresponds to a square of 16x16 blocks in the world, so we are in fact generating from -16000 to 16000 in each direction. The emoji name is ":straight_ruler:". You can use `Scale(N)` instead of `📏"1:N"` if you don't like emojis.
- In many cases (here to save as an image), the map need to be in 2D. Here, even if the size of the `y` coordinate is 1, it is
  still considered as a 3D map. This is why we use the `view2d` function to have a 2D view of the world. ⚠ It is only a view, so if you modify the 2D map, it will also modify the 3D map.
- Like the first example, the `!` at the end of function names indicates that the function modifies the object inplace. Here our function modifies in fact two objects: the `overworld1_18` object and the `worldmap` object.

## TODOs

### Java implementation of rng

- [X] JavaRandom
- [X] Xoroshiro128PlusPlus
- [X] Test with [Suppositions.jl](https://github.com/Seelengrab/Supposition.jl)

### Noise

- [X] Perlin noise
- [X] Octaves noise
- [ ] Simplex noise
- [X] Double Perlin noise

### Features

- [X] Nether generation
- [X] Overworld 1.18+ generation
- [ ] Overworld beta generation
- [ ] Overworld generation
- [ ] End generation
- [ ] Structure generation
- [ ] Use of [recipes](https://docs.juliaplots.org/stable/recipes/) for the plots of maps without the need of depending on Plots.jl

### Performance

- [ ] Threading for the biome generation. `Polyester.jl` with `@batch` macro would be a nice option. But
there is [#24(Polyester)](https://github.com/JuliaSIMD/Polyester.jl/issues/24) that only enable threading for the outer loop, in our case it's the y coord that is very often.. only 1. I think the only option
is to do everything by hand by following [this](https://discourse.julialang.org/t/how-can-i-arrange-to-only-use-threads-if-the-number-of-iteration-is-higher-than-minimum/68177/16)
- [ ] GPU acceleration for the biome generation

### Infrastructure changes

- [X] Make the Minecraft version types instead of enums and dispatch the functions instead of if checks.
- [ ] Make a type `World(dimension, version)` similar to each dimension objects, with `set_seed!`, etc. But would act
more like an immutable array of biomes, implementing `getindex` instead of the current `get_biome(dim, coord)`. For slices,
it would return a array WorldMap. So the current `gen_biomes!` should still exist to allow inplace generation, with a buffer
`WorldMap` to store the biomes.

## Contributing

### Conventions

- The code should be formatted with `using JuliaFormatter; format(".")`.
- For random generator, each function that modifies the state inplace should be prefixed with a `🎲` (:game_die:)
- For array manipulation, each function that modifies the array inplace should be prefixed with a `!`.
- Each new feature should be tested with unit tests (with the `Test` module) and if possible with property-based tests (with [Suppositions.jl](https://github.com/Seelengrab/Supposition.jl))

### Testing

Java >= 17 is required to run the tests.
You can run the tests with:

```julia
julia> ] test Cubiomes
```

To not include [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl) tests:

```julia
julia> using Pkg; Pkg.test("Cubiomes"; test_args=["not_aqua"])
```

To run the tests with the coverage:

```julia
julia> using Cubiomes, LocalCoverage

julia> LocalCoverage.generate_coverage("Cubiomes")
```
