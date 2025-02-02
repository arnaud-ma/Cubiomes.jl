using ..Noises
using ..JavaRNG: JavaRandom, set_seed🎲
using ..Utils: Utils
using ..MCVersions
using ..Biomes: Biomes, BIOME_NONE, Biome, isnone
using .BiomeArrays: World, coordinates
using .Voronoi: voronoi_access, voronoi_source2d

using Base.Iterators

#region nether definition
# ---------------------------------------------------------------------------- #
#                               Nether definition                              #
# ---------------------------------------------------------------------------- #

abstract type Nether <: Dimension end

# Nothing to do if version is <1.16. The nether is only composed of nether_wastes
struct Nether1_16Minus end
Nether(::UndefInitializer, ::mcvt"<1.16") = Nether1_16Minus()
set_seed!(::Nether1_16Minus, seed::UInt64) = nothing
get_biome(::Nether1_16Minus, x::Real, z::Real, y::Real, ::Scale) = Biomes.nether_wastes
gen_biomes!(::Nether1_16Minus, out::World, ::Scale) = fill!(out, Biomes.nether_wastes)

struct Nether1_16Plus <: Nether
    temperature::DoublePerlin{2}
    humidity::DoublePerlin{2}
    sha::SomeSha
end

function Nether(::UndefInitializer, ::mcvt">=1.16")
    return Nether1_16Plus(DoublePerlin{2}(undef), DoublePerlin{2}(undef), SomeSha(nothing))
end

function set_seed!(nn::Nether1_16Plus, seed::UInt64, ::Val{true})
    _set_temp_humid!(seed, nn.temperature, nn.humidity)
    nn.sha[] = Utils.sha256_from_seed(seed)
    return nothing
end
function set_seed!(nn::Nether1_16Plus, seed::UInt64, ::Val{false})
    _set_temp_humid!(seed, nn.temperature, nn.humidity)
    nn.sha[] = nothing
    return nothing
end
set_seed!(nn::Nether1_16Plus, seed::UInt64) = set_seed!(nn, seed, Val(true))

function _set_temp_humid!(seed, temperature, humidity)
    rng_temp = JavaRandom(seed)
    set_rng!🎲(temperature, rng_temp, -7)

    set_seed🎲(rng_temp, seed + 1)
    set_rng!🎲(humidity, rng_temp, -7)
    return nothing
end
#endregion

#region get_biome
# ---------------------------------------------------------------------------- #
#                                   get_biome                                  #
# ---------------------------------------------------------------------------- #

# y coordinate not used in scale != 1
function get_biome(nn::Nether1_16Plus, x::Real, z::Real, y::Real, scale::Scale)
    return get_biome(nn, x, z, scale)
end

function get_biome(nn::Nether1_16Plus, x::Real, z::Real, y::Real, ::Scale{1})
    source_x, source_z, _ = voronoi_access(nn.sha[], x, z, y)
    return get_biome(nn, source_x, source_z, Scale(4))
end

function get_biome(nn::Nether1_16Plus, x::Real, z::Real, ::Scale{S}) where {S}
    scale = S >> 2
    return get_biome(nn, x * scale, z * scale , Scale(4))
end

function get_biome(nn::Nether1_16Plus, x::Real, z::Real, ::Scale{4})
    temperature = sample_noise(nn.temperature, x, z)
    humidity = sample_noise(nn.humidity, x, z)
    return find_closest_biome(temperature, humidity)
end

function get_biome_and_delta(nn::Nether1_16Plus, coord::CartesianIndex)
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
    (x=0.0, y=0.0, z_square=0.0, biome=Biomes.nether_wastes),
    (x=0.0, y=-0.5, z_square=0.0, biome=Biomes.soul_sand_valley),
    (x=0.4, y=0.0, z_square=0.0, biome=Biomes.crimson_forest),
    (x=0.0, y=0.5, z_square=0.375^2, biome=Biomes.warped_forest),
    (x=-0.5, y=0.0, z_square=0.175^2, biome=Biomes.basalt_deltas),
)
#endregion

#region gen_biomes!
# ---------------------------------------------------------------------------- #
#                                  gen_biomes!                                 #
# ---------------------------------------------------------------------------- #

@inline function distance_square(coord1::CartesianIndex, coord2::CartesianIndex)
    return sum(abs2, (coord1 - coord2).I)
end

"""
    fill_radius!(out::World{2}, x, z, id::Biome, radius)

Fills a circular area around the point `(x, z)` in `out` with the biome `id`,
within a given `radius`. Assuming `radius`>=0.
"""
function fill_radius!(
    out::World{N}, center::CartesianIndex{N}, id::Biome, radius,
) where {N}
    r = floor(Int, radius)
    r_square = r^2

    # optimizations:
    # we know that u is a coord to be filled implies:
    # - u is in the array axes (coordinates)
    # - u is in the n dimension cube of center `center` and edges of the same size `r`
    # so we can simply iterate over the intersection coordinates.
    coords = CartesianIndices(ntuple(
        dim -> ((center[dim] - r):(center[dim] + r)) ∩ axes(out, dim),
        Val(N),
    ))

    for coord in coords
        if distance_square(coord, center) <= r_square
            @inbounds out[coord] = id
        end
    end
    return nothing
end

# Assume out is filled with BIOME_NONE
function gen_biomes_unsafe!(
    nn::Nether1_16Plus, map2d::World{2}, ::Scale{S}, confidence=1,
) where {S}
    scale = S >> 2

    # The Δnoise is the distance between the first and second closest
    # biomes within the noise space. Dividing this by the greatest possible
    # gradient (~0.05) gives a minimum diameter of voxels around the sample
    # cell that will have the same biome.
    inv_grad = 1.0 / (confidence * 0.05 * 2) / scale

    for coord in coordinates(map2d)
        if !isnone(map2d[coord])
            continue  # Already filled with a specific biome
        end
        biome, Δnoise = get_biome_and_delta(nn, coord * scale)
        @inbounds map2d[coord] = biome

        # radius around the sample cell that will have the same biome
        cell_radius = Δnoise * inv_grad
        fill_radius!(map2d, coord, biome, cell_radius)
    end
    return nothing
end

function gen_biomes_unsafe!(
    nn::Nether1_16Plus, map3d::World{3}, scale::Scale{S}, confidence=1,
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

function gen_biomes!(
    nn::Nether1_16Plus,
    mc_map::World,
    scale::Scale,
    confidence=1,
)
    fill!(mc_map, BIOME_NONE)
    gen_biomes_unsafe!(nn, mc_map, scale, confidence)
end

function gen_biomes!(nn::Nether1_16Plus, map3D::World{3}, ::Scale{1}, confidence=1)
    coords = coordinates(map3D)
    # If there is only one value, simple wrapper around get_biome_unsafe
    if isone(length(coords))
        coord = first(coords)
        map3D[coord] = get_biome(nn, coord.I..., Scale(4))
        return nothing
    end

    # The minimal map where we are sure we can find the source coordinates at scale 4
    biome_parent_axes = voronoi_source2d(map3D)
    biome_parents = view_reshape_cache_like(biome_parent_axes)
    gen_biomes!(nn, biome_parents, Scale(4), confidence)

    sha = nn.sha[]
    for coord in coords
        # See the comment on get_biome_unsafe for the explanation
        source_x, source_z, _ = voronoi_access(sha, coord)
        result = biome_parents[source_x, source_z]
        @inbounds map3D[coord] = result
    end
    return nothing
end

function gen_biomes!(::Nether1_16Plus, ::World{2}, ::Scale{1}, confidence=1)
    msg = "generate the nether biomes at scale 1 requires a 3D map because \
            the biomes depend on the y coordinate. You can create a 3D map with \
            a single y coordinate with `MCMap(x_coords, z_coords, y)`"
    throw(ArgumentError(msg))
end
