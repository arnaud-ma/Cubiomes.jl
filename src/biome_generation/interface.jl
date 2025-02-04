using OffsetArrays

using ..Noises
using ..JavaRNG: AbstractJavaRNG
using ..Utils: Utils
using ..SeedUtils: mc_step_seed
using ..MCVersions
using ..Biomes: BIOME_NONE

#region Scale
# ---------------------------------------------------------------------------- #
#                               Scale definition                               #
# ---------------------------------------------------------------------------- #

"""
    Scale{N}
    Scale(N::Integer)

The scale of a map. It represents the ratio between the size of the map an the real world.
For example, a 1:4 scale map means that each block in the map represents a 4x4 area
in the real world. So the coordinates (5, 5) are equal to the real world coordinates
(20, 20).

`N` *MUST* ne to the form 2^(2n) with n >= 0. So the more common scales are 1:1, 1:4, 1:16,
1:64, 1:256. The support for big scales is not guaranteed and depends on the function that
uses it. Read the documentation of the function that uses it to know the supported values.
"""
struct Scale{N}
    function Scale{N}() where {N}
        if N < 1
            throw(ArgumentError("The scale must be to the form 2^(2n) with n >= 0. Got $N."))
        end
        i = log2(sqrt(N))
        if !(isinteger(i))
            ii = floor(Int, i)
            closest_before = 2^(2ii)
            closest_after = 2^(2(ii + 1))
            throw(ArgumentError("The scale must be to the form 2^(2n). Got 1:$N. The closest valid scales are 1:$closest_before and 1:$closest_after."))
        end
        return new()
    end
end
Scale(N::Integer) = Scale{N}()

macro 📏_str(str)
    splitted = split(str, ':')
    if length(splitted) != 2
        throw(ArgumentError("Bad scale format."))
    end
    num, denom = parse.(Int, splitted)
    scale = num // denom
    if numerator(scale) != 1
        throw(ArgumentError("The scale must be simplified to the form 1:N. Got $str -> $num:$denom."))
    end
    return Scale(denominator(scale))
end
const var"@T📏_str" = typeof ∘ var"@📏_str"

include("BiomeArrays.jl")
using BiomeArrays: BiomeArrays

#region Dimension
# ---------------------------------------------------------------------------- #
#                                   Dimension                                  #
# ---------------------------------------------------------------------------- #

"""
    Dimension

An abstract type that represents a dimension in Minecraft. It is used to generate
the noise for the biomes in that dimension.

The concrete type `TheDim` *MUST* implement:

  - An uninitialized constructor `TheDim(::UndefInitializer, ::MCVersion, args...)`
  - An inplace constructor `set_seed!(dim::TheDim, seed::UInt64, args...)`.
    Be aware that the seed must be constrained to `UInt64` dispatch to work.
  - get_biome(dim::TheDim, coord, scale::Scale, args...) -> Biome where
    `coord` can be either (x::Real, z::Real, y::Real) or NTuple{3} or CartesianIndex{3}
  - gen_biomes!(dim::TheDim, out::World, scale::Scale, args...)

See also:
  - [`set_seed!`](@ref), [`get_biome`](@ref), [`gen_biomes!`](@ref) the obligatory functions
  - [`Nether`](@ref), [`Overworld`](@ref) and [`End`](@ref) the default subtypes
"""
abstract type Dimension end

"""
    set_seed!(dim::Dimension, seed, args...)

Set the seed of the dimension generator. It can be any valid seed you can pass like in Minecraft,
but use UInt64 if performance is a concern.
The args are specific to the dimension. See the documentation of the dimension for more information.

See also: [`Nether`](@ref), [`Overworld`](@ref), [`End`](@ref)
"""
set_seed!(dim::Dimension, seed, args...) = set_seed!(dim, Utils.u64_seed(seed), args...)

"""
    get_biome(dim::Dimension, x::Real, z::Real, y::Real, [scale::Scale,], args...) -> Biome
    get_biome(dim::Dimension, coord, [scale::Scale,], args...) -> Biome

Get the biome at the coordinates `(x, z, y)` in the dimension `dim`. The coordinates can be
passed as numbers or as tuples or as `CartesianIndex` (the coords returned by
[`coordinates`](@ref)). The scale is defaulted to 1:1 (the more precise). The args are
specific to the dimension. See the documentation of the dimension for more information.

See also: [`Scale`](@ref), [`Nether`](@ref), [`Overworld`](@ref), [`End`](@ref)
"""
function get_biome end

# the default for the coordinates is:
# x, z, y -> CartesianIndex(x, z, y) -> coord.I -> (x, z, y) -> x, z, y
# so if none of the method is defined, it will throw a StackOverflowError because of
# the infinite recursion
# But the dimension *MUSt* define at least one of the methods so it will never happen
# if the writer of the dimension is not a complete idiot (sorry my future self)

function get_biome(
    dim::Dimension, x::Real, z::Real, y::Real, s::Scale, args::Vararg{Any, N},
) where {N}
    return get_biome(dim, CartesianIndex(x, z, y), s, args...)
end
function get_biome(
    dim::Dimension, x::Real, z::Real, y::Real, args::Vararg{Any, N},
) where {N}
    return get_biome(dim, x, z, y, Scale(1), args...)
end
function get_biome(dim::Dimension, coord::NTuple{3}, args::Vararg{Any, N}) where {N}
    return get_biome(dim, coord..., args...)
end
function get_biome(dim::Dimension, coord::CartesianIndex{3}, args::Vararg{Any, N}) where {N}
    return get_biome(dim, coord.I, args...)
end

"""
    gen_biomes!(dim::Dimension, world::World, [scale::Scale,], args...) -> Nothing

Fill the world with the biomes of the dimension `dim`. The scale is defaulted to 1:1.
The args are specific to the dimension. See the documentation of the dimension for more
information.

See also: [`World`](@ref), [`Scale`](@ref), [`Nether`](@ref), [`Overworld`](@ref), [`End`](@ref)
"""
function gen_biomes!(
    dim::Dimension, world::BiomeArrays.World, args::Vararg{Any, N},
) where {N}
    return gen_biomes!(dim, world, Scale(1), args...)
end

"""
    SomeSha

A struct that holds a `UInt64` or `nothing`. It is used to store the SHA of the seed
if it is needed. Acts like a reference (a zero dimension array) to a `UInt64` or `nothing`.
Use `sha[]` to get or store the value, or directly `set_seed!(sha, seed)` to compute the SHA
of the seed and store it and `reset!(sha)` to set it to `nothing`.
"""
mutable struct SomeSha
    x::Union{Nothing, UInt64}
end
Base.getindex(s::SomeSha) = s.x
Base.setindex!(s::SomeSha, value) = s.x = value
set_seed!(s::SomeSha, seed::UInt64) = s[] = Utils.sha256_from_seed(seed)
reset!(s::SomeSha) = s[] = nothing

#endregion
#region Cache
# ---------------------------------------------------------------------------- #
#                                     Cache                                    #
# ---------------------------------------------------------------------------- #

const FIRST_CACHE_SIZE_VECTOR_BIOMES = 1024
const CACHE_VECTOR_BIOMES = fill(BIOME_NONE, FIRST_CACHE_SIZE_VECTOR_BIOMES)

"""
    view_reshape_cache_like(axes)

Create a view of the cache with the same shape as the axes.

!!! warning
    This function is not thread-safe and should not be used in a multithreaded context.

This is a TODO: maybe use of @init from Floops.jl to create a thread-safe cache
"""
function view_reshape_cache_like(axes, cache=CACHE_VECTOR_BIOMES)
    size_axes = length.(axes)
    required_size = prod(size_axes)
    if length(cache) < required_size
        append!(
            cache,
            fill(BIOME_NONE, required_size - length(cache)),
        )
    end
    buffer_view = @view cache[1:required_size]
    reshaped_view = reshape(buffer_view, size_axes...)
    return OffsetArray(reshaped_view, axes...)
end