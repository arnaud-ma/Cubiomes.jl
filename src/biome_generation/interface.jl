using OffsetArrays

using ..Utils: threading

#region Dimension
# ---------------------------------------------------------------------------- #
#                                   Dimension                                  #
# ---------------------------------------------------------------------------- #

"""
    Dimension{Version}

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
  - [`MCVersion`]
  - [`threading`](@ref)

# Extended help

!!! details "Extended help"

    This section is for developers that want to implement a new dimension. Let's call
    the new dimension type `MyDim`.

    It **MUST** implement the following interface:

    - `MyDim(::UndefInitializer, V::MCVersion, args...) -> MyDim{V}`

      Creates an uninitialized dimension.

    - `setseed!(dim::MyDim, seed::UInt64, args...) -> Nothing`

      See [`setseed!`](@ref). Be aware of the ::UInt64 for the seed, the converion
      is automatically done before calling this function thanks to the interface.

    - `getbiome(dim::MyDim, coord, scale::Scale, args...) -> Biome`

      Seed [`getbiome`](@ref). Only the coordinates to the form of numbers or as a tuple
      can be implemented. If the 3rd coordinate (`y`) is not needed, it can be
      ignored, but only for the form of numbers.

    It **CAN** implement:

    - `genbiomes!(dim::MyDim, world::WorldMap, scale::Scale, threading::Scheduler) -> Nothing`

      See [`genbiomes!`](@ref) The default implementation is to simply loop over the world map
      and to call `getbiome` for each coordinate.

    - `default_threading(::MyDim, ::WorldMap, ::Scale, ::typeof(gen_biomes!)) -> Scheduler`

      See [`threading`](@ref). Should return the default threading mode from the given types.
      The default one is `threading(:off)`, i.e. no threading.
"""
abstract type Dimension{V} end

Base.broadcastable(d::Dimension) = Ref(d)

"""
    mcversion(dim::Dimension) -> MCVersion

Get the Minecraft version of the dimension `dim`. It is a subtype of [`MCVersion`](@ref).

# Examples
```julia
julia> overworld = Overworld(undef, mcv"1.18");
julia> mcversion(overworld)
"""
mcversion(::Dimension{V}) where {V} = V

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
function getbiome(dim::Dimension, coord::NTuple{N, Real}, s::Scale = Scale(1); kwargs...) where {N}
    return getbiome(dim, coord..., s; kwargs...)
end

function getbiome(dim::Dimension, coord::CartesianIndex, s::Scale = Scale(1); kwargs...)
    return getbiome(dim, coord.I, s; kwargs...)
end

function getbiome(::Dimension, ::Real, ::Real, ::Scale; kwargs...)
    throw(
        ArgumentError(
            "The y coordinate is required for this dimension..",
        ),
    )
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
const CACHE_VECTOR_BIOMES = fill(Biomes.BIOME_NONE, FIRST_CACHE_SIZE_VECTOR_BIOMES)

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
            fill(Biomes.BIOME_NONE, required_size - length(cache)),
        )
    end
    buffer_view = @view cache[1:required_size]
    reshaped_view = reshape(buffer_view, size_axes...)
    return OffsetArray(reshaped_view, axes...)
end

# ---------------------------------------------------------------------------- #
#                                  Some utils                                  #
# ---------------------------------------------------------------------------- #

function _show_noise_to_textplain(io, mime, noise, char, last)
    lines = split(repr(mime, noise), '\n')
    for (i, line) in enumerate(lines)
        i == 1 && continue # skip title line
        if i < length(lines)
            println(io, char, " ", line)
        else
            print(io, char, " ", line, last)
        end
    end
    return nothing
end
