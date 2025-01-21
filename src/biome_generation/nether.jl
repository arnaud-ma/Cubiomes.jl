using ..Noises
using ..JavaRNG: JavaRandom, set_seed🎲
using ..Utils: Utils
using ..Cubiomes: MC_UNDEF, MC_1_15

using Base.Iterators

#region struct definition
# ---------------------------------------------------------------------------- #
#                 Noise Struct Definition and Noise Generation                 #
# ---------------------------------------------------------------------------- #

mutable struct SomeSha
    x::Union{Nothing, UInt64}
end
Base.getindex(s::SomeSha) = s.x
Base.setindex!(s::SomeSha, value) = s.x = value

"""
    Nether{S<:Union{Nothing,UInt64}}
    Nether{seed::Integer; with_sha::Bool=true}

The nether dimension biome generator.
"""
struct Nether <: Dimension
    temperature::DoublePerlin{2}
    humidity::DoublePerlin{2}
    sha::SomeSha
end
Nether(seed, sha=Val(true)) = Dimension(Nether, seed, sha)

function Nether(::UndefInitializer)
    return Nether(DoublePerlin{2}(undef), DoublePerlin{2}(undef), SomeSha(nothing))
end

function _set_temp_humid!(seed, temperature, humidity)
    rng_temp = JavaRandom(seed)
    set_rng!🎲(temperature, rng_temp, -7)

    set_seed🎲(rng_temp, seed + 1)
    set_rng!🎲(humidity, rng_temp, -7)
    return nothing
end

function set_seed!(nn::Nether, seed::UInt64, ::Val{true})
    _set_temp_humid!(seed, nn.temperature, nn.humidity)
    nn.sha[] = Utils.sha256_from_seed(seed)
end
function set_seed!(nn::Nether, seed::UInt64, ::Val{false})
    _set_temp_humid!(seed, nn.temperature, nn.humidity)
    nn.sha[] = nothing
end
set_seed!(nn::Nether, seed::UInt64) = set_seed!(nn, seed, Val(true))

# TODO: Add detailed docstrings for these functions

function get_biome end
function gen_biomes end
function gen_biomes_unsafe! end
#endregion

for get_func in (:get_biome, :get_biome_unsafe)
    @eval function $get_func(
        nn::Nether,
        coords::CartesianIndex{CN},
        args::Vararg{Any, N},
    ) where {CN, N}
        return $get_func(nn, coords.I..., args...)
    end
end

function distance_square(coord1::CartesianIndex{N}, coord2::CartesianIndex{N}) where {N}
    return sum(abs2, (coord1 - coord2).I)
end

#region point 4 and 1
# ---------------------------------------------------------------------------- #
#                   Nether Biome Point Access (Scale 4 and 1)                  #
# ---------------------------------------------------------------------------- #

function get_biome(
    nn::Nether,
    x::Real,
    z::Real,
    y::Real,
    scale::Scale{S},
    version::MCVersion=MC_UNDEF,
) where {S}
    if (version <= MC_1_15 && version != MC_UNDEF)
        return nether_wastes
    end
    return get_biome_unsafe(nn, x, z, y, scale)
end

# To zoom from the scale 4 to the scale 1, each coordinate at scale 1 is associated with
# a random (taken from the sha of the seed) source coordinate at scale 4
# where the biome is the same (with a voronoi diagram).
# So we only need to take this source coordinates, with the voronoi_access_3d function,
# and then take the biome with this new coordinates.
# The source_x and source_z DEPENDS on x, z AND on y.
# i.e., if y is modified, source_x and source_z could be modified too.
function get_biome_unsafe(nn::Nether, x::Real, z::Real, y::Real, ::T📏"1:1")
    source_x, source_z, _ = voronoi_access(nn.sha[], x, z, y)
    return get_biome_unsafe(nn, source_x, source_z, 📏"1:4")
end

function get_biome_unsafe(nn::Nether, x::Real, z::Real, ::T📏"1:4")
    temperature = sample_noise(nn.temperature, x, z)
    humidity = sample_noise(nn.humidity, x, z)
    return find_closest_biome(temperature, humidity)
end

function get_biome_unsafe(nn::Nether, x::Real, z::Real, y::Real, scale::T📏"1:4")
    get_biome_unsafe(nn, x, z, scale)
end

# TODO: get_biome for scale != (1, 4)

function get_biome_and_delta(nn::Nether, coord::CartesianIndex)
    temperature = sample_noise(nn.temperature, coord)
    humidity = sample_noise(nn.humidity, coord)
    biome, dist1, dist2 = find_closest_biome_with_dists(temperature, humidity)
    return biome, √dist1 - √dist2
end

function calculate_distance_squared(nether_point, temperature, humidity)
    return (nether_point.x - temperature)^2 + (nether_point.y - humidity)^2 +
           nether_point.z_square
end

function find_closest_biome_with_dists(temperature, humidity)
    id = 0
    min_distance1, min_distance2 = Inf, Inf
    for i in 1:5
        @inbounds nether_point = NETHER_POINTS[i]
        dist = calculate_distance_squared(nether_point, temperature, humidity)
        if dist < min_distance1
            min_distance2 = min_distance1
            min_distance1 = dist
            id = i
        elseif dist < min_distance2
            min_distance2 = dist
        end
    end
    @inbounds return NETHER_POINTS[id].biome, min_distance1, min_distance2
end

function find_closest_biome(temperature, humidity)
    # equivalent to argmin(np -> calculate_distance_squared(np, temperature, humidity), NETHER_POINTS).biome
    # but faster if we write it manually
    id = 0
    min_dist = Inf
    for i in 1:5
        @inbounds nether_point = NETHER_POINTS[i]
        dist = calculate_distance_squared(nether_point, temperature, humidity)
        if dist < min_dist
            min_dist = dist
            id = i
        end
    end
    @inbounds return NETHER_POINTS[id].biome
end

const NETHER_POINTS = (
    (x=0.0, y=0.0, z_square=0.0, biome=nether_wastes),
    (x=0.0, y=-0.5, z_square=0.0, biome=soul_sand_valley),
    (x=0.4, y=0.0, z_square=0.0, biome=crimson_forest),
    (x=0.0, y=0.5, z_square=0.375^2, biome=warped_forest),
    (x=-0.5, y=0.0, z_square=0.175^2, biome=basalt_deltas),
)
#endregion

#region generation != 1
# ---------------------------------------------------------------------------- #
#                Biome Generation for 2D and 3D, with scale != 1               #
# ---------------------------------------------------------------------------- #

# For basically most of the functions, we need one method for the square and one for the cube.
# We could have a single method and doing something like a reshape if the cube is a square but
# for readability and performance, we prefer to have two methods, even if it is a bit more code.

"""
    _manage_less_1_15!(out::AbstractArray{BiomeID}, version::MCVersion)

Fills the output array `out` with the biome `nether_wastes` if the Minecraft version
is less than or equal to 1.15. Return true if filled, false otherwise.
"""
function _manage_less_1_15!(out::AbstractArray{BiomeID}, version::MCVersion)
    if version <= MC_1_15 && version != MC_UNDEF
        fill!(out, nether_wastes)
        return true
    end
    return false
end
clamp
"""
    fill_radius!(out::AbstractMatrix{BiomeID}, x, z, id::BiomeID, radius)

Fills a circular area around the point `(x, z)` in `out` with the biome `id`,
within a given `radius`. Assuming `radius`>=0.
"""
function fill_radius!(
    out::AbstractArray{BiomeID, N},
    center::CartesianIndex{N},
    id::BiomeID,
    radius,
) where {N}
    r = floor(Int, radius)
    r_square = r^2

    # optimizations:
    # we know that u is a coord to be filled implies:
    # - u is in the array axes (coordinates)
    # - u is in the n dimension cube of center `center` and edges of the same size `r`
    # so we can simply iterate over the intersection coordinates.
    coords = CartesianIndices(ntuple(
        dim -> (center[dim] - r: center[dim] + r) ∩ axes(out, dim),
        Val(N)
    ))

    for coord in coords
        if distance_square(coord, coords) <= r_square
            @inbounds out[coord] = id
        end
    end
    return nothing
end

# Assume out is filled with BIOME_NONE
function gen_biomes_unsafe!(nn::Nether, map2D::MCMap{2}, ::Scale{S}, confidence=1) where {S}
    S <= 3 && throw(ArgumentError(lazy"Scale must be >= 4"))
    scale = S ÷ 4

    # The Δnoise is the distance between the first and second closest
    # biomes within the noise space. Dividing this by the greatest possible
    # gradient (~0.05) gives a minimum diameter of voxels around the sample
    # cell that will have the same biome.
    inv_grad = 1.0 / (confidence * 0.05 * 2) / scale

    # TODO: use of @threads
    #! not thread-safe because fill_radius! modifies the map in place,
    # including areas that are not in the current thread
    # possible solutions:
    # - divide the map into chunks and fill each chunk in parallel
    # - use a lock to prevent multiple threads from writing to the same cell

    for coord in CartesianIndices(map2D)
        if !isnone(map2D[coord])
            continue  # Already filled with a specific biome
        end

        coord_scale4 = coord * scale
        biome, Δnoise = get_biome_and_delta(nn, coord_scale4)
        @inbounds map2D[coord] = biome

        # radius around the sample cell that will have the same biome
        cell_radius = Δnoise * inv_grad
        fill_radius!(map2D, coord, biome, cell_radius)
    end
    return nothing
end

function gen_biomes_unsafe!(
    nn::Nether, map3d::MCMap{3}, scale::Scale{S}, confidence=1,
) where {S}
    # At scale != 1, the biome does not change with the y coordinate
    # So we simply take the first y coordinate and fill the other ones with the same biome
    ys = axes(map3d, 3)
    first_square_y = @view map3d[:, :, first(ys)]
    gen_biomes_unsafe!(nn, first_square_y, scale, confidence)

    for y in Iterators.drop(ys, 1) # skip the first y coordinate
        copyto!(map3d[:, :, y], first_square_y)
    end
    return nothing
end

function _gen_biomes!(nn, mc_map, scale, confidence, version)
    _manage_less_1_15!(mc_map, version) && return nothing
    gen_biomes_unsafe!(nn, mc_map, scale, confidence)
end

function gen_biomes!(
    nn::Nether,
    mc_map::MCMap,
    scale::Scale,
    confidence=1,
    version::MCVersion=MC_UNDEF,
)
    fill!(mc_map, BIOME_NONE)
    _gen_biomes!(nn, mc_map, scale, confidence, version)
end

#endregion

#region generation == 1
# ---------------------------------------------------------------------------- #
#                Biome Generation for 2D and 3D, with scale == 1               #
# ---------------------------------------------------------------------------- #

const _FIRST_SIZE_CACHE_GEN_BIOME_NETHER = 1_000
const _CACHE_GEN_BIOME_NETHER =
    Tuple(fill(BIOME_NONE, _FIRST_SIZE_CACHE_GEN_BIOME_NETHER) for _ in 1:Threads.nthreads())

"""
    view_reshape_cache_like(axes)

Create a view of the cache with the same shape as the axes. It is thread-safe because
it uses a cache per thread. If the cache is too small, it will be automatically resized.
"""
function view_reshape_cache_like(axes)
    size_axes = length.(axes)
    required_size = prod(size_axes)
    cache_vector = _CACHE_GEN_BIOME_NETHER[Threads.threadid()]
    if length(cache_vector) < required_size
        append!(
            cache_vector,
            fill(BIOME_NONE, required_size - length(cache_vector)),
        )
    end
    buffer_view = @view cache_vector[1:required_size]
    reshaped_view = reshape(buffer_view, size_axes...)
    offset_view = OffsetArray(reshaped_view, axes...)
    return offset_view
end

function gen_biomes_unsafe!(
    nn::Nether,
    map3D::MCMap{3},
    ::T📏"1:1",
    confidence=1,
    version::MCVersion=MC_UNDEF,
)
    coords = CartesianIndices(map3D)

    # If there is only one value, simple wrapper around get_biome_unsafe
    if isone(length(coords))
        map3D[1] = get_biome_unsafe(nn, first(coords), 📏"1:4")
        return nothing
    end

    # The minimal map where we are sure we can find the source coordinates at scale 4
    biome_parent_axes = get_voronoi_src_axes2D(map3D)
    biome_parents = view_reshape_cache_like(biome_parent_axes)
    gen_biomes!(nn, biome_parents, 📏"1:4", confidence, version)

    sha = nn.sha[]
    # TODO: we could use @threads but overhead if the size is small (1-10ms overhead)
    for coord in coords
        # See the comment on get_biome_unsafe for the explanation
        source_x, source_z, _ = voronoi_access(sha, coord)
        result = biome_parents[source_x, source_z]
        @inbounds map3D[coord] = result
    end
    return nothing
end

function gen_biomes!(
    nn::Nether, mc_map::MCMap, scale::T📏"1:1", confidence=1, version::MCVersion=MC_UNDEF,
)
    _gen_biomes!(nn, mc_map, scale, confidence, version)
end

function gen_biomes!(
    nn::Nether,
    map2D::MCMap{2},
    ::T📏"1:1",
    confidence=1,
    version::MCVersion=MC_UNDEF,
)
    msg = "generate the nether biomes at scale 1 requires a 3D map because \
            the biomes depend on the y coordinate. You can create a 3D map with \
            a single y coordinate with `MCMap(x_coords, z_coords, y)`"
    throw(ArgumentError(msg))
end
