using OffsetArrays

using ..Noises
using ..JavaRNG: AbstractJavaRNG
using ..SeedUtils: SeedUtils, mc_step_seed
using ..MCVersions
using ..Biomes: BIOME_NONE
using ..Utils: threading
using OhMyThreads: OhMyThreads, Scheduler, tforeach

#region Scale
# ---------------------------------------------------------------------------- #
#                               Scale definition                               #
# ---------------------------------------------------------------------------- #

"""
    Scale{N}
    Scale(N::Integer)
    📏"1:N"

The scale of a map. It represents the ratio between the size of the map an the real world.
For example, a 1:4 scale map means that each block in the map represents a 4x4 area
in the real world. So the coordinates (5, 5) are equal to the real world coordinates
(20, 20).

`N` **MUST** ne to the form ``4^n, n \\geq 0``. So the more common scales are 1:1, 1:4, 1:16,
1:64, 1:256. The support for big scales is not guaranteed and depends on the function that
uses it. Read the documentation of the function that uses it to know the supported values.

It is possible to use the alternative syntax `📏"1:N"`. The emoji name is `:straight_ruler:`.

# Examples
```julia
julia> Scale(4)
Scale{4}()

julia> Scale(5)
ERROR: ArgumentError: The scale must be to the form 4^n. Got 1:5. The closest valid scales are 1:4 and 1:16.

julia> 📏"1:4" === Scale(4) === Scale{4}()
true

```
"""
struct Scale{N}
    function Scale{N}() where {N}
        if N < 1
            throw(ArgumentError("The scale must be to the form 2^(2n) with n >= 0. Got $N."))
        end
        i = log(4, N)
        if !(isinteger(i))
            ii = floor(Int, i)
            closest_before = 4^ii
            closest_after = 4^(ii + 1)
            throw(ArgumentError("The scale must be to the form 4^n. Got 1:$N. The closest valid scales are 1:$closest_before and 1:$closest_after."))
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
using .BiomeArrays: WorldMap

#region Dimension
# ---------------------------------------------------------------------------- #
#                                   Dimension                                  #
# ---------------------------------------------------------------------------- #

"""
    Dimension

The parent type of every Minecraft dimension. There is generally three steps to use a dimension:

1. Create one dimension with a specific [`MCVersion`](@ref) and maybe some specific arguments.
2. Set the seed of the dimension with [`setseed!`](@ref).
3. Do whatever you want with the dimension: get biomes, generate biomes, etc.

# Examples
```julia
julia> overworld = Overworld(undef, mcv"1.18");

julia> setseed!(overworld, 42)

julia> getbiome(overworld, 0, 0, 63)
dark_forest::Biome = 0x1d

julia> setseed!(overworld, "I love cats")

julia> world = WorldMap(x=-100:100, z=-100:100, y=63);

julia> genbiomes!(overworld, world, scale=📏"1:4")
```

See also:
  - [`Nether`](@ref), [`Overworld`](@ref), [`End`](@ref)
  - [`setseed!`](@ref), [`getbiome`](@ref), [`genbiomes!`](@ref)
  - [`WorldMap`](@ref), [`Scale`](@ref)
  - [`threading`](@ref)

# Extended help

!!! details "Extended help"

    This section is for developers that want to implement a new dimension. Let's call
    the new dimension type `MyDim`.

    It **MUST** implement the following interface:

    - `MyDim(::UndefInitializer, ::MCVersion, args...) -> MyDim`
       This is the constructor that creates an uninitialized dimension. It is used to
        create a dimension with a specific version and some arguments.

    - `setseed!(dim::MyDim, seed::UInt64, args...) -> Nothing`
        It should modify the internal state of the dimension to use the seed. Be aware
        of the ::UInt64 for the auto-conversion to work (i.e. the user can automatically
        pass any seed type). See [`setseed!`](@ref).

    - `getbiome(dim::MyDim, coord, scale::Scale, args...) -> Biome`
        This function should return the biome at the coordinates `coord` in the dimension
        `dim`. The coordinates can be either (x::Real, z::Real, y::Real) or NTuple{3}.
        If the 3rd coordinate (y, the height) is not needed, a method
        `getbiome(dim::MyDim, x::Real, z::Real, scale::Scale, args...)` can be added. But
        the first one is **always** mandatory.

    It **CAN** implement:

    - `genbiomes!(dim::MyDim, world::WorldMap, scale::Scale, threading::Scheduler) -> Nothing`
        Fill inplace the world map with the biomes of the dimension `dim`. The default
        implementation is to simply loop over the world map and call `getbiome` for each
        coordinate. See [`genbiomes!`](@ref).

    - `default_threading(::MyDim, ::WorldMap, ::Scale, ::typeof(gen_biomes!)) -> Scheduler`
        Should return the default threading mode from the given types. The default one
        is `threading(:off)`, i.e. no threading. See [`threading`](@ref).

"""
abstract type Dimension end

Base.broadcastable(d::Dimension) = Ref(d)

"""
    setseed!(dim::Dimension, seed; kwargs...)

Set the seed of the dimension generator. It can be any valid seed you can pass like in
Minecraft, but UInt64 is better if performance is a concern. To transform an UInt64 seed to
a "normal" one, use `signed(seed)`.

Other keyword arguments can be passed, specific to the dimension / minecraft version. They
are often related to some micro-optimizations. See the documentation of the specific
dimension for more information.

See also: [`Nether`](@ref), [`Overworld`](@ref), [`End`](@ref)
"""
setseed!(dim::Dimension, seed; kwargs...) =
    setseed!(dim, SeedUtils.u64_seed(seed); kwargs...)

"""
    getbiome(dim::Dimension, x::Real, z::Real, y::Real, scale=📏"1:1", args...; kwargs...) -> Biome
    getbiome(dim::Dimension, coord, scale=📏"1:1", args...; kwargs...) -> Biome

Get the biome at the coordinates `(x, z, y)` in the dimension `dim`. The coordinates can be
passed as numbers or as tuples or as `CartesianIndex` (the coords returned by
[`coordinates`](@ref)).

The scale is defaulted to 1:1, i.e. the exact coordinates. The args are specific to the
dimension. The `y` coord can be unnecessary sometimes, and so not passed. See the documentation
of the dimension for more information.

See also:
    - [`Scale`](@ref), [`genbiomes!`](@ref), [`Dimension`](@ref)
"""
function getbiome end

# assuming any subtype of Dimension has a specific getbiome method with either
# (x, z, y) or NTuple{3} as coordinates.
# Otherwise infinite recursion
function getbiome(dim::Dimension, x::Real, z::Real, y::Real, s::Scale = Scale(1); kwargs...)
    return getbiome(dim, (x, z, y), s; kwargs...)
end
function getbiome(dim::Dimension, coord::NTuple{3, Real}, s::Scale = Scale(1); kwargs...)
    return getbiome(dim, coord..., s; kwargs...)
end

function getbiome(dim::Dimension, coord::CartesianIndex, s::Scale = Scale(1); kwargs...)
    return getbiome(dim, coord.I, s; kwargs...)
end

"""
    genbiomes!(dim::Dimension, world::WorldMap, scale=📏"1:1", threading=...; kwargs...) -> Nothing

Fill the world map with the biomes of the dimension `dim`.
The args are specific to the dimension. See the documentation of the dimension for more
information.

See also: [`WorldMap`](@ref), [`Scale`](@ref), [`Dimension`](@ref), [`getbiome`](@ref)
"""
function genbiomes! end

function genbiomes!(dim::Dimension, world::WorldMap, scale::Scale, threading::Scheduler; kwargs...)
    tforeach(coordinates(world); scheduler = threading) do coord
        @inbounds world[coord] = getbiome(dim, coord, scale; kwargs...)
    end
    return nothing
end

# default scale if 1:1
function genbiomes!(dim::Dimension, world::WorldMap, threading::Scheduler; kwargs...)
    return genbiomes!(dim, world, Scale(1), threading; kwargs...)
end
function genbiomes!(dim::Dimension, world::WorldMap; kwargs...)
    return genbiomes!(dim, world, Scale(1); kwargs...)
end

# default threading
function genbiomes!(dim::Dimension, world::WorldMap, scale::Scale; kwargs...)
    td = default_threading(dim, world, scale, genbiomes!)
    return genbiomes!(dim, world, scale, td; kwargs...)
end

"""
    default_threading(::Dimension, ::WorldMap, ::Scale, ::typeof(genbiomes!)) -> Scheduler

Should only be used by dimensions creators. Its only function is to be overloaded for the
given dimension / worldmap / scale to be the default value if not provied by the user of the
`threading` parameter in [`genbiomes!`](@ref).

For example:
```julia
default_threading(::MyDim, ::WorldMap, ::Scale{4}, ::typeof(genbiomes!)) =
    threading(:dynamic, minchunksize = 4)
```

See also: [`threading`](@ref), [`genbiomes!`](@ref), [`Dimension`](@ref)
"""
default_threading(::Dimension, ::WorldMap, ::Scale, ::typeof(genbiomes!)) = threading(:off)


"""
    SomeSha

A struct that holds a `UInt64` or `nothing`. It is used to store the SHA of the seed
if it is needed. Acts like a reference (a zero dimension array) to a `UInt64` or `nothing`.
Use `sha[]` to get or store the value, or directly `setseed!(sha, seed)` to compute the SHA
of the seed and store it and `reset!(sha)` to set it to `nothing`.
"""
mutable struct SomeSha
    x::Union{Nothing, UInt64}
end
SomeSha() = SomeSha(nothing)
Base.getindex(s::SomeSha) = s.x
Base.setindex!(s::SomeSha, value) = s.x = value
setseed!(s::SomeSha, seed::UInt64) = s[] = SeedUtils.sha256_from_seed(seed)
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

"""
function view_reshape_cache_like(axes, cache = CACHE_VECTOR_BIOMES)
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
