# Getting started

In this section we will provide a condensed overview of the package. In order to keep this overview concise, we will not cover the possible options and parameters of the functions. But this overview should be enough for 90% of the use cases.

## Installation

To install [Cubiomes.jl](https://github.com/arnaud-ma/Cubiomes.jl), start up Julia and type the following code into the REPL:

```julia-repl
julia> ] add github.com/arnaud-ma/Cubiomes.jl
```

Then, you can import Cubiomes.jl into the namespace

```julia-repl
julia> using Cubiomes
```

## Getting help

To get help on specific functionality you can either look up the information here, or you can use the built-in help system in Julia. For example, to get help on the `get_biome` function:

```julia-repl
julia>?

help?> get_biome
search: get_biome gen_biomes!

  get_biome(dim::Dimension, x::Real, z::Real, y::Real, [scale::Scale,], args...; kwargs...) -> Biome
  get_biome(dim::Dimension, coord, [scale::Scale,], args...; kwargs...) -> Biome

  Get the biome at the coordinates (x, z, y) in the dimension dim. The coordinates can be passed as numbers or as ...
```
