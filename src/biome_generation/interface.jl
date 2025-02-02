using OffsetArrays

using ..Noises
using ..JavaRNG: AbstractJavaRNG
using ..Utils: Utils
using ..SeedUtils: mc_step_seed
using ..MCVersions
using ..Biomes: BIOME_NONE

#region Noise
# ---------------------------------------------------------------------------- #
#                             Noise infrastructure                             #
# ---------------------------------------------------------------------------- #

"""
    Dimension

An abstract type that represents a dimension in Minecraft. It is used to generate
the noise for the biomes in that dimension.

The concrete type must implement:

  - An uninitialized constructor `Dimension(::Type{TheDim}, u::UndefInitializer, args...)` or
    `TheDim(::UndefInitializer, args...)` where `TheDim` is the concrete type.
  - An inplace constructor `set_seed!(dim::TheDim, seed::UInt64, args...)` where `TheDim`
    is the concrete type. Be aware that the seed must be constrained to `UInt64` dispatch to work.
"""
abstract type Dimension end

"""
    set_seed!(dim::Dimension, seed, args...)

Set the seed of the dimension generator. It can be any valid seed you can pass like in Minecraft,
but use UInt64 if performance is a concern.

The args are specific to the dimension. See the documentation of the dimension for more information.

See also: [`Nether`](@ref)
"""
set_seed!(dim::Dimension, seed, args...) = set_seed!(dim, Utils.u64_seed(seed), args...)

function Dimension(
    ::Type{D}, version::MCVersion, u::UndefInitializer, args::Vararg{Any, N},
) where {D <: Dimension, N}
    return D{version}(u, args...)
end

"""
    Scale{N}
    Scale(N::Integer)

The scale of a map. It represents the ratio between the size of the map an the real world.
For example, a 1:4 scale map means that each block in the map represents a 4x4 area
in the real world. So the coordinates (5, 5) are equal to the real world coordinates
(20, 20).

The supported values for N are usually 1, 4, 16, 64, 256. But it can vary from the function
that uses it. Read the documentation of the function that uses it to know the supported values.
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

#region MCMap
# ---------------------------------------------------------------------------- #
#                             MCMap infrastructure                             #
# ---------------------------------------------------------------------------- #


"""
    similar_expand{T}(mc_map::OffsetMatrix, expand_x::Int, expand_z::Int) where T

Create an uninitialized OffsetMatrix of type `T` but with additional rows and columns
on each side of the original matrix.

# Examples

```julia
julia> arr = OffsetMatrix(zeros(3, 3))
3×3 OffsetArray(::Matrix{Float64}, 1:3, 1:3) with eltype Float64 with indices 1:3×1:3:
 0  0  0
 0  0  0
 0  0  0

julia> similar_expand(Float64, arr, 1, 1)
5×5 OffsetArray(::Matrix{Float64}, 0:4, 0:4) with eltype Float64 with indices 0:4×0:4:
 6.90054e-310  6.90054e-310  6.90054e-310  1.0e-323      6.90054e-310
 6.90054e-310  6.90054e-310  6.90054e-310  6.90054e-310  5.0e-324
 6.90054e-310  6.90054e-310  6.90054e-310  6.90054e-310  1.56224e-319
 6.90054e-310  6.90054e-310  6.90054e-310  6.90054e-310  6.90054e-310
 6.90055e-310  6.90054e-310  1.56224e-319  6.90054e-310  6.90054e-310
```
"""
function similar_expand(
    ::Type{T}, mc_map::OffsetMatrix, expand_x::Int, expand_z::Int,
) where {T}
    x, z = map(first, axes(mc_map))
    size_x, size_z = size(mc_map)
    return OffsetMatrix{T}(
        undef,
        (x - expand_x):(x + size_x + expand_x - 1),
        (z - expand_z):(z + size_z + expand_z - 1),
    )
end

mutable struct SomeSha
    x::Union{Nothing, UInt64}
end
Base.getindex(s::SomeSha) = s.x
Base.setindex!(s::SomeSha, value) = s.x = value

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
    offset_view = OffsetArray(reshaped_view, axes...)
    return offset_view
end