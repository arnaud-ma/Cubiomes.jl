# document Noises module
"""
!!! note
    Working over raw noise functions is very low-level and should only be used
    as a last resort or for performance reasons.

Noises is a module to generate and sample various types of noise functions used
in the procedural generation of Minecraft worlds. The result are always floating, but
the input can be any type of number.

A noise object can be quite big in memory, so we can create an undefined noise object
and initialize it without copying it with the `set_rng!🎲` function, saving time and memory.

The main uses are with the functions:
- [`Noise`](@ref) : create an undefined noise object.
- [`set_rng!🎲`](@ref) : initialize the noise object.
- [`Noise🎲`](@ref) : create and initialize the noise object in one step.
- [`sample_noise`](@ref) : sample the noise at a given point.

The noises implemented are:
- [`Perlin`](@ref) : a Perlin noise.
- [`Octaves`](@ref) : a sum of `N` Perlin noises.
- [`DoublePerlin`](@ref) : a sum of two independent and identically distributed Octaves noises.
"""
module Noises

export Noise, Noise🎲, set_rng!🎲
export sample_noise, sample_simplex
export Perlin, Octaves, DoublePerlin

export is_undef, unsafe_set_rng!🎲

include("interface.jl")
include("perlin.jl")
include("octaves.jl")
include("double_perlin.jl")

end # module