
# Getting Started {#Getting-Started}

If you are already familiar with Julia, you can skip this section and go directly to the [guide](guide.md).

To install Julia and learn how to run Julia code, refer to the [Getting Started](https://docs.julialang.org/en/v1/manual/getting-started/) section of the Julia documentation.

## Installation

To install [Cubiomes.jl](https://github.com/arnaud-ma/Cubiomes.jl), start up Julia and enter the following command in the REPL:

```julia
julia> using Pkg
julia> Pkg.add(url="https://github.com/arnaud-ma/Cubiomes.jl")
```


Then, you can import Cubiomes.jl into the namespace

```julia
julia> using Cubiomes
```


## Getting help {#Getting-help}

To get help on specific functionality you can either look up the information here, or you can use the built-in help system in Julia. For example, to get help on the `get_biome` function:

```julia
julia>?

help?> get_biome
search: get_biome gen_biomes!

  get_biome(dim::Dimension, x::Real, z::Real, y::Real, [scale::Scale,], args...; kwargs...) -> Biome
  get_biome(dim::Dimension, coord, [scale::Scale,], args...; kwargs...) -> Biome

  Get the biome at the coordinates (x, z, y) in the dimension dim. The coordinates can be passed as numbers or as ...
```

