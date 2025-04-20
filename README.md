# Cubiomes.jl

<!--- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/Cubiomes.jl/stable/)
--->
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://arnaud-ma.github.io/Cubiomes.jl/stable/)
[![Build Status](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/arnaud-ma/cubiomes.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/arnaud-ma/Cubiomes.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/arnaud-ma/Cubiomes.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)

A rewrite of [Cubiomes](https://github.com/Cubitect/cubiomes) but in [Julia](https://julialang.org/), intended to be (much) easier to use and to contribute to, and faster. Even though it is possible to call Java/C code from Julia, here everything is rewritten by hand, exploiting the possibilities of Julia to be fast and easy to use at the same time.

Please look at the [documentation](https://arnaud-ma.github.io/Cubiomes.jl/stable/). In particular:

- The [getting started](https://arnaud-ma.github.io/Cubiomes.jl/stable/gettingstarted) page if you are new to Julia
- The [guide](https://arnaud-ma.github.io/Cubiomes.jl/stable/guide) that should cover 90% of the use cases

This readme is a small summary of the documentation.

## Audience

The goal is to provide a library that generate the biomes and structures of Minecraft worlds, in a fast and easy way, while still having the flexibility given by writing code.

You should be familiar to programming. That's all. Julia syntax is quite simple so you could be able to learn it by using the library / reading the [documentation](https://arnaud-ma.github.io/Cubiomes.jl/stable/). Same for the Minecraft world generation concepts.

## Why Cubiomes.jl?

- **Readability and ease of use**: Julia is a high-level language, which makes the code easier to read and understand. Of course to be fast, it is sometimes necessary to write more complex code, but if it is simply to use an API (like the one of Cubiomes), it a very easy Python-like language (see the [examples](#examples))

- **Performance**: Julia is almost as fast as C. For this case, it is in fact faster because uh so actually I don't know why lol but i always measure 2-3x speedup. In addition to this speedup, we can very easily add multireading. We'll see in the future to set it by default in certain cases.

## Installation

The package is still early in development, so it is not yet registered. You can install it via the github repository, in the Julia REPL:

```julia
julia> ] add github.com/arnaud-ma/cubiomes.jl
```

## Usage

You can look at the [documentation](https://arnaud-ma.github.io/Cubiomes.jl/stable/). In particular:

- The [getting started](https://arnaud-ma.github.io/Cubiomes.jl/stable/gettingstarted) page if you are new to Julia
- The [guide](https://arnaud-ma.github.io/Cubiomes.jl/stable/guide) that should cover 90% of the use cases

## Examples

### Biome generation

Search a seed for a mushroom fields biome at a predefined location.

```julia
using Cubiomes

function search_biome_at(gen, x, z, y)
    seed = 0
    while true
        setseed!(gen, seed)
        if getbiome(gen, x, z, y) == Biomes.mushroom_fields
            println("Seed $seed has a Mushroom Fields at $((x, z, y))")
            break
        end
        seed += 1
    end
end

const gen = Overworld(undef, mcv"1.18")
search_biome_at(gen, 0, 0, 63)
```

### World map generation

Generate a map of biomes and save it as an image. Using `genbiomes!` can be much faster than iterating over the world map
and calling `getbiome` for each coordinate.

```julia
using Cubiomes
using FileIO

const overworld1_18 = Overworld(undef, mcv"1.18")
const worldmap = WorldMap(x=-1000:1000, z=-1000:1000, y=63)

setseed!(overworld1_18, 42)
genbiomes!(overworld1_18, worldmap, 📏"1:16")
save("world.png", to_color(view2d(worldmap)))
```

<details>
<summary>show world.png</summary>
<img src="docs/src/assets/world.png" alt="World map"/>
</details>

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
- [ ] Make a type `World(dimension, version)` similar to each dimension objects, with `setseed!`, etc. But would act
more like an immutable array of biomes, implementing `getindex` instead of the current `getbiome(dim, coord)`. For slices,
it would return a array WorldMap. So the current `genbiomes!` should still exist to allow inplace generation, with a buffer
`WorldMap` to store the biomes.

## Contributing

### Conventions

- The code should be formatted with [Runic.jl](https://github.com/fredrikekre/Runic.jl)
- For random generator, each function that modifies the state inplace should be prefixed with a `🎲` (:game_die:)
- For array manipulation, each function that modifies the array inplace should be prefixed with a `!`.
- Each new feature should be tested with unit tests (with the `Test` module) and if possible with property-based tests (with [Suppositions.jl](https://github.com/Seelengrab/Supposition.jl))

### Testing

Java >= 17 is required to run the tests.
You can run the tests with:

```julia
julia> ] test Cubiomes
```

To run the tests with the coverage:

```julia
julia> using Cubiomes, LocalCoverage

julia> LocalCoverage.generate_coverage("Cubiomes")
```
