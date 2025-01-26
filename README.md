# Cubiomes.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/cubiomes.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://arnaud-ma.github.io/cubiomes.jl/dev/)
[![Build Status](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml?query=branch%3Amain)

A rewrite of [Cubiomes](https://github.com/Cubitect/cubiomes) but in [Julia](https://julialang.org/), intended to be (much) easier to use and to contribute to, and faster.

> [!WARNING]
> The code is still in early development, and everything can change at any time. This repo should be seen as a proof of concept and nothing else.

## Why Cubiomes.jl?

- **Readability and ease of use**: Julia is a high-level language, which makes the code easier to read and understand. Of course to be fast, it is sometimes necessary to write more complex code, but if it is simply to use an API (like the one of Cubiomes), it a very easy Python-like language.

- **Performance**: Julia is almost as fast as C. For this case, it is in fact faster because is it very easy to parallelize the code or to easily know where the bottlenecks are with the built-in profiler.

## Installation

The package is still early in development, so it is not yet registered. You can install it via the github repository, in the Julia REPL:

```julia
julia> ] add github.com/arnaud-ma/cubiomes.jl
```

## Usage

It is still a work in progress, so the API is not yet stable at all. The nether generation and the overworld 1.18+ generation should be working, here is an example:

```julia
using Cubiomes

overworld = Overworld(undef, mcv"1.20")    # (1)
set_seed!(overworld, 42)                   # (2)
mc_map = MCMap(-1000:1000, -1000:1000, 63) # (3)
gen_biomes!(overworld, mc_map, 📏"1:1")    # (4)

using FileIO  # using Pkg; Pkg.add("FileIO")
save("mcmap.png", to_color(mc_map))        # (5)
```

Let's explain step by step:

1. We need to create a dimension object with a given version, which will serve as a generator. `undef` means that it is an empty object at the moment. The Minecraft version must **always** be prefixed with `mcv` (stands for minecraft version). It allows the code to have completely different behaviors depending on the version.
2. We set the seed to the generator. The seed can be any valid seed as in Minecraft (a string or a number). It will automatically be converted to a `UInt64` number.
3. We create a `MCMap` object, that will store the biomes. It can be 2D or 3D (depending if the y coordinate is provided or not). You can access to the biomes by simply indexing with the exact same coordinates as in Minecraft (e.g. `mc_map[0, 0, 0]` will give you the biome at the origin of the world). At the moment of the code, the map is full of `BIOME_NONE` values because we did not generate the biomes yet. The syntax `a:b` in Julia means any integer between `a` and `b` (inclusive).
4. We generate the biomes with the `gen_biomes!` function. It will fill the `MCMap` with the biomes. The argument with a `📏` (a ruler) is the scale of the biomes, i.e. how many blocks in the world correspond to one biome value in the map. For example, with a scale of 4, one biome value in the map corresponds to a square of 4x4 blocks in the world. The only supported values are `📏"1:1"`, `📏"1:4"`, `📏"1:16"` and `📏"1:64"`. The symbol name is ":straight_ruler:". You can use `Scale(1)` or `Scale(4)` instead if you don't like emojis.
5. We can visualize / save the map using other Julia packages (such as FileIO to save into an image file) and `to_color` to transform the biomes into nice colors and other Julia packages.

## TODO

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

- [ ] Nether generation
- [ ] Overworld 1.18+ generation
- [ ] Overworld beta generation
- [ ] Overworld generation
- [ ] End generation
- [ ] Structure generation
- [ ] Use of [recipes](https://docs.juliaplots.org/stable/recipes/) for the plots of maps without the need of depending on Plots.jl

### Performance

- [ ] Threading for the biome generation
- [ ] GPU acceleration for the biome generation

### Infrastructure changes

- [X] Make the Minecraft version types instead of enums and dispatch the functions instead of if checks.

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
