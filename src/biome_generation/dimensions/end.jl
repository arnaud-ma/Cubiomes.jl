using StaticArrays: SMatrix
using OffsetArrays: Origin

using ..Noises
using ..JavaRNG: JavaRandom, randjump🎲
using ..MCBugs: has_bug_mc159283
using .BiomeArrays: WorldMap, coordinates
using ..MCVersions
using ..Biomes: the_end, end_highlands, end_midlands, end_barrens, small_end_islands

"""
    End(::UndefInitializer, version::MCVersion)

The Minecraft End dimension.
"""
abstract type End <: Dimension end

function End(::UndefInitializer, ::mcvt"<1.0")
    throw(ArgumentError("Version less than 1.0 does not have the end dimension"))
end

struct End1_9Minus <: End end
End(::UndefInitializer, ::mcvt"1.0 <= x < 1.9") = End1_9Minus()
set_seed!(::End1_9Minus, seed::UInt64) = nothing
get_biome(::End1_9Minus, x::Real, z::Real, y::Real, ::Scale) = the_end
gen_biomes!(::End1_9Minus, out::WorldMap) = fill!(out, the_end)

struct End1_9Plus{V} <: End
    perlin::Perlin
    sha::SomeSha
    rng_temp::JavaRandom
end

function End(::UndefInitializer, version::mcvt">=1.9")
    return End1_9Plus{version}(Perlin(undef), SomeSha(nothing), JavaRandom(undef))
end

function set_seed!(nn::End1_9Plus, seed::UInt64; sha=true)
    set_seed🎲(nn.rng_temp, seed)
    randjump🎲(nn.rng_temp, Int32, 17_292)
    set_rng!🎲(perlin, rng)

    if sha
        set_seed!(nn.sha, seed)
    else
        reset!(nn.sha)
    end
    return nothing
end

#==========================================================================================#
# Original Algorithm
#==========================================================================================#

"""
    original_get_biome(end_noise::EndNoise, x, z)

Original algorithm to get the biome at a given point in the End dimension.
It is only here for documentation purposes, because everything else is just
optimizations and scaling on this basis (for scale >= 4).

But not so sure that the optimizations are really important, most of ones are
just avoid √ operations, but hypot is already really fast in Julia.
"""
function original_get_biome(end_::End1_9Plus, x, z, ::Scale{4})
    x >>= 2
    z >>= 2

    # inside the main island
    if x^2 + z^2 <= 4096
        return the_end
    end

    x = 2x + 1
    z = 2z + 1

    scaled_x, odd_x = divrem(x, 2)
    scaled_z, odd_z = divrem(z, 2)

    height = 100 - hypot(x, z) * 8
    height = clamp(height, -100, 80)

    for z_i in -12:12, x_i in -12:12
        real_x = scaled_x + x_i
        real_z = scaled_z + z_i
        if real_x^2 + real_z^2 > 4096 &&
           (sample_simplex(end_.perlin, real_x, real_z) < -0.9)
            elevation = (abs(real_x) * 3439 + abs(real_z) * 147) % 13 + 9
            smooth_x = odd_x - x_i * 2
            smooth_z = odd_z - z_i * 2
            noise = 100 - hypot(smooth_x, smooth_z) * elevation
            noise = clamp(noise, -100, 80)
            height = max(height, noise)
        end
    end

    height > 40 && return end_highlands
    height >= 0 && return end_midlands
    height >= -20 && return end_barrens
    return small_end_islands
end

#==========================================================================================#
# Elevation / Height
#==========================================================================================#

struct Elevations{V, A}
    inner::A
end
Elevations{V}(a::AbstractMatrix) where {V} = Elevations{V, typeof(a)}(a)

elevation_val(x, z) = ((abs(x) * 3439 + abs(z) * 147) % 13) + 9

function get_elevation_outside_center(perlin, x, z)
    (sample_simplex(perlin, x, z) < -0.9) ? elevation_val(x, z) : zero(UInt16)
end

function get_elevation(end_::End1_9Plus, x, z)::UInt16
    x^2 + z^2 > 4096 && return get_elevation_outside_center(end_.perlin, x, z)
    return zero(UInt16)
end

function fill_elevations!(end_noise::End1_9Plus, elevations)
    inner = elevations.inner
    for coord in CartesianIndices(inner)
        inner[coord] = get_elevation(end_noise, coord.I...)
    end
    return nothing
end

"""
    similar_expand{T}(mc_map::OffsetMatrix, expand_x::Int, expand_z::Int) where T

Create an uninitialized OffsetMatrix of type `T` but with additional rows and columns
on each side of the original matrix.
"""
function similar_expand(
    ::Type{T}, mc_map::OffsetMatrix, expand_x::Int, expand_z::Int,
) where {T}
    xs, zs = axes(mc_map)
    return OffsetMatrix{T}(
        undef,
        (first(xs) - expand_x):(last(xs) + expand_x),
        (first(zs) - expand_z):(last(zs) + expand_z),
    )
end

# TODO: maybe use sparse matrix instead
function Elevations(end_noise::End1_9Plus{V}, A::WorldMap{2}, range::Integer=12) where {V}
    #! memory allocation
    elevations = Elevations{V}(similar_expand(UInt16, A, range, range))
    fill_elevations!(end_noise, elevations)
    return elevations
end

function get_cache_dist_squared()
    row = (-25:2:25) .^ 2
    rowpos, rowneg = row[begin:(end - 1)], row[(begin + 1):end]
    colpos, colneg = copy(rowpos), copy(rowneg)
    mats = (
        (
            rowpos .+ colpos',
            rowpos .+ colneg',
        ),
        (
            rowneg .+ colpos',
            rowneg .+ colneg',
        ),
    )
    map(twomat -> map(x -> Origin(-12, -12)(SMatrix{25, 25}(x)), twomat), mats)
end
const CACHE_D2_END = get_cache_dist_squared()

const SMOOTH_AXE_POSITIVE, SMOOTH_AXE_NEGATIVE = let
    x = (-25:2:25) .^ 2
    Origin(-12).((x[1:(end - 1)], x[2:end]))
end

function _get_height_sample(
    elevation_getter, x, z, start_height, range::Integer=12,
)
    height_sample = start_height

    # Determine the index for the cache based on the sign of x and z
    index_x, index_z = ifelse(x < 0, 1, 2), ifelse(z < 0, 1, 2)
    dists_squared = CACHE_D2_END[index_x][index_z]

    for z_i in (-range):range, x_i in (-range):range
        real_x, real_z = x + x_i, z + z_i
        elevation_squared = elevation_getter(real_x, real_z)^2
        if !iszero(elevation_squared)
            @inbounds noise = (dists_squared[x_i, z_i]) * elevation_squared
            if noise < height_sample
                height_sample = noise
            end
        end
    end
    return height_sample
end

function get_height_sample(elevations::Elevations, x, z, start_height, range::Integer=12)
    # TODO: know how to disable bounds checking
    return _get_height_sample((x, z) -> elevations.inner[x, z], x, z, start_height, range)
end

function get_height_sample(end_noise::End1_9Plus, x, z, start_height, range::Integer=12)
    return _get_height_sample(
        (x, z) -> get_elevation(end_noise, x, z), x, z, start_height, range,
    )
end

function get_height_sample_outside_center(
    end_noise::End1_9Plus, x, z, start_height, range::Integer=12,
)
    return _get_height_sample(
        (x, z) -> get_elevation_outside_center(end_noise, x, z), x, z, start_height, range,
    )
end

get_height_end(height_value) = clamp(-100 - sqrt(height_value), -100, 80)

function get_height(end_noise::End1_9Plus, x, z, range::Integer=12)
    #  64 * (x^2 + z^2) <= 14400 <=> x^2 + z^2 <= 225 (circle of radius 15)
    start = (abs(x) <= 15 && abs(z) <= 15) ? 64(x^2 + z^2) : 14_401
    return get_height_end(get_height_sample(end_noise, x, z, start, range))
end

#==========================================================================================#
# Biome Generation
#==========================================================================================#

ElevationGetter{V} = Union{End1_9Plus{V}, Elevations{V}} where {V}

function biome_from_height(height)
    height > 40 && return end_highlands
    height >= 0 && return end_midlands
    height >= -20 && return end_barrens
    return small_end_islands
end

function biome_from_height_sample(height)
    height < 3600 && return end_highlands  # height < (40 - 100)^2
    height < 10_000 && return end_midlands # height < (0 - 100)^2
    height < 14_400 && return end_barrens  # height < (-20 - 100)^2
    return small_end_islands
end

# we need to do like this instead of ::Union{End1_9Plus, Elevations} because it leads to
# ambiguity with the  get_biome(end_::Cubiomes.BiomeGeneration.End1_9Plus, x::Real, z::Real, ::Scale{S}, range) where S
# below
for type in (:End1_9Plus, :Elevations)
    @eval function get_biome(
        eg::$type{V}, x::Real, z::Real, ::Scale{16}, range::Integer=12,
    ) where {V}
        x^2 + z^2 <= 4096 && return the_end
        has_bug_mc159283(V, x, z) && return small_end_islands
        return biome_from_height_sample(
            get_height_sample(eg, x, z, 14_401, range)
        )
    end

    @eval function get_biome(eg::$type, x::Real, z::Real, ::Scale{4}, range=12)
        return get_biome(eg, x >> 2, z >> 2, Scale(16), range)
    end
end

# For scale > 16
function get_biome(end_::End1_9Plus, x::Real, z::Real, ::Scale{S}, range=4) where {S}
    scale = S >> 3
    return get_biome(end_, x * scale, z * scale, Scale(16), range)
end

function gen_biomes!(end_noise::End1_9Plus, map2D::WorldMap{2}, s::Scale{16})
    #! memory allocation
    # TODO: remove this allocation
    elevations = Elevations(end_noise, map2D, 12)
    for coord in coordinates(map2D)
        map2D[coord] = get_biome(elevations, coord.I, s)
    end
    return nothing
end

function gen_biomes!(::End1_9Plus, ::WorldMap{2}, ::Scale{4})
    throw(ArgumentError(
        "1:4 end generation is the same as 1:16 but simply rescaled by 4. \
        Use 1:16 scale instead. The scale 1:4 could be supported in the future."
    ))
end

# scale > 16
function gen_biomes!(end_noise::End1_9Plus, map2D::WorldMap{2}, s::Scale{S}) where {S}
    for coord in coordinates(map2D)
        map2D[coord] = get_biome(end_noise, coord, s)
    end
    return nothing
end

# #==========================================================================================#
# # Biome Generation / Scale 1 ⚠ STILL DRAFT # TODO
# #==========================================================================================#

function get_biome(end_::End1_9Plus, x::Real, z::Real, ::Scale{1})
    error("scale 1:1 end generation is not implemented yet.")
end

function gen_biomes!(end_noise::End1_9Plus, map2D::WorldMap{2}, ::Scale{1})
    error("scale 1:1 end generation is not implemented yet.")
end