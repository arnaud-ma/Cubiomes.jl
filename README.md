# Cubiomes.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/cubiomes.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://arnaud-ma.github.io/cubiomes.jl/dev/)
[![Build Status](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

## ⚠️⚠️⚠️ WARNING ⚠️⚠️⚠️
The code is still in early development, and everything can change at any time. This repo should be seen as a proof of concept and nothing else.

The faster and easy-to-use Minecraft biome finder, written in ~~rust~~ Julia, the best ~~llvm wrapper~~ programming language for this specific task!

It is in fact a complete rewrite of the original [Cubiomes](https://github.com/Cubitect/cubiomes) C library, line by line, while using every advantage of the Julia language.

## Why Cubiomes.jl?

- **Readability and ease of use**: Julia is a high-level language, which makes the code easier to read and understand. It is garbage-collected, so nothing to worry about memory management.

- **Performance**: Julia is almost as fast as C. For this case, it is in fact faster because is it very easy to parallelize the code or to easily know where the bottlenecks are with the built-in profiler.

## Installation

The package is still early in development, so it is not yet registered. You can install it via the github repository, in the Julia REPL:

```julia
julia> ] add github.com/arnaud-ma/cubiomes.jl
```

## Usage

It is still a work in progress, so the API is not yet stable at all. The nether generation should be working, here is an example:

```julia
using Cubiomes
using Plots

seed = "hello world" # (1)
nether_generator = Nether(seed) # (2)
mc_map = MCMap(-1000:1000, -1000:1000) # (3)
gen_biomes!(nether_generator, mc_map, 📏"1:4") # (4)

plot(mc_map) # (5)
```

Let's explain step by step:

1. The seed is exactly the same as in Minecraft. It can be any string or integer.
2. We create a generator, that is mandatory to generate the biomes. It's there that we can pass a seed.
3. We create a `MCMap` object, that will store the biomes. It can be 2D or 3D (depending if the y coordinate is provided or not). Biomes are stored as enum values. You can access to it with the exact same coordinates as in Minecraft (e.g. `mc_map[0, 0, 0]` will give you the biome at the origin of the world). At the moment of the code, the map is full of `BIOME_NONE` values because we did not generate the biomes yet.
4. We generate the biomes with the `gen_biomes!` function. It will fill the `MCMap` with the biomes. The last argument is the scale of the biomes, i.e. how many blocks in the world correspond to one biome value in the map. For example, with a scale of 1, one biome value in the map corresponds to one block in the world. The only supported values are `📏"1:1"`, `📏"1:4"`, `📏"1:16"` and `📏"1:64"`. The symbol name is ":straight_ruler:".
5. We can visualize a 2D slice of the map with `plot`. The colors are the same as in Minecraft, so you can easily recognize the biomes.

## Contributing

### Conventions

- The code should be formatted with the [BlueStyle](https://github.com/JuliaDiff/BlueStyle) code style.
- For random generator, each function that modifies the state inplace should be prefixed with a `🎲`.
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