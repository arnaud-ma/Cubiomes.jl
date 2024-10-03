#==========================================================================================#
# Noise Struct Definition and Noise Generation
#==========================================================================================#

"""
    NetherNoise{S<:Union{Nothing,UInt64}}
    NetherNoise{seed::Integer; with_sha::Bool=true}

The noise type for the nether.

# Arguments
- seed::Integer: the Minecraft seed (view as UInt64)

# Keywords
- with_sha::Bool: If true, compute the `sha` field from the seed. The `sha` is only used
    for the generation with scale 1. It can save some computation time (less than 1ms)
    if not needed.

# Fields
- `temperature::DoublePerlinNoise{2}`: store the noise for the temperature
- `humidity::DoublePerlinNoise{2}`: store the noise for the humidity
- `sha::Union{UInt64, Nothing}`: Optional sha computed from the seed with [`sha256_from_seed`].

# Example
```julia
julia> NetherNoise(1234)
NetherNoise{UInt64}(DoublePerlinNoise{2}(1.1111111111111112, PerlinNoise[..., 0x618d5b164c44f21a)
julia> NetherNoise(1234, with_sha=false)
NetherNoise{Nothing}(DoublePerlinNoise{2}(1.1111111111111112, PerlinNoise[..., nothing)
```
"""
struct NetherNoise{S<:Union{Nothing,UInt64}} <: Noise
    temperature::DoublePerlinNoise{2}
    humidity::DoublePerlinNoise{2}
    sha::S
end

function NetherNoise(seed::Integer; with_sha::Bool=true)
    temperature, humidity = _get_temp_humid(seed)
    if with_sha
        sha = sha256_from_seed(UInt64(unsigned(seed)))
        return NetherNoise{UInt64}(temperature, humidity, sha)
    end
    return NetherNoise{Nothing}(temperature, humidity, nothing)
end

function _get_temp_humid(seed)
    rng_temp = JavaRNG(seed)
    temperature = DoublePerlinNoise🎲(rng_temp, Val(2), -7)
    rng_humidity = JavaRNG(seed + 1)
    humidity = DoublePerlinNoise🎲(rng_humidity, Val(2), -7)
    return temperature, humidity
end

Noise(seed, ::Val{DIM_NETHER}) = NetherNoise(seed)
Noise(seed, sha, ::Val{DIM_NETHER}) = NetherNoise(seed, sha)

Noise(seed::String, ::Val{DIM_NETHER}) = NetherNoise(java_hashcode(seed))
Noise(seed::String, sha::UInt64, ::Val{DIM_NETHER}) = NetherNoise(java_hashcode(seed), sha)

# TODO: Add detailed docstrings for these functions

function get_biome end
function gen_biomes end
function gen_biomes_unsafe! end

#==========================================================================================#
# Nether Biome Point Access (Scale 4 and 1)
#==========================================================================================#

function get_biome(
    nn::NetherNoise, x, z, y=0; scale::Val{S}=Val(1), version::MCVersion=MC_UNDEF
) where {S}
    (version <= MC_1_15 && version != MC_UNDEF) && return nether_wastes
    S == 1 && return get_biome_unsafe(nn, x, z, y, scale)
    return get_biome_unsafe(nn, x, z, scale)
end

# To zoom from the scale 4 to the scale 1, each coordinate at scale 1 is associated with
# a random (taken fro the sha of the seed) source coordinate at scale 4
# where the biome is the same (with a voronoi diagram).
# So we only need to take this source coordinates, with the voronoi_access_3d function,
# and then take the biome with this new coordinates.
# The source_x and source_z DEPENDS on x, z AND on y.
# i.e., if y is modified, source_x and source_z could be modified too.
function get_biome_unsafe(nn::NetherNoise{UInt64}, x, z, y, scale::Val{1})
    source_x, source_z, _ = voronoi_access_3d(nn.sha, x, z, y)
    return get_biome_unsafe(nn, source_x, source_z, Val(4))
end

function get_biome_unsafe(nn::NetherNoise, x, z, scale::Val{4})
    temperature = sample(nn.temperature, x, 0, z)
    humidity = sample(nn.humidity, x, 0, z)
    return find_closest_biomes(temperature, humidity)[1]
end

function get_biome_and_delta(nn::NetherNoise, x, z)
    temperature = sample(nn.temperature, x, 0, z)
    humidity = sample(nn.humidity, x, 0, z)
    biome, dist1, dist2 = find_closest_biomes(temperature, humidity)
    return biome, √dist1 - √dist2
end

function find_closest_biomes(temperature, humidity)
    id = zero(UInt8)
    min_distance1, min_distance2 = Inf, Inf
    for i in 1:5
        nether_point = NETHER_POINTS[i]
        distance_square = calculate_distance_squared(nether_point, temperature, humidity)
        if distance_square < min_distance1
            min_distance2 = min_distance1
            min_distance1 = distance_square
            id = i
        elseif distance_square < min_distance2
            min_distance2 = distance_square
        end
    end
    @inbounds return NETHER_POINTS[id].biome, min_distance1, min_distance2
end

function calculate_distance_squared(nether_point, temperature, humidity)
    Δx = nether_point.x - temperature
    Δy = nether_point.y - humidity
    return Δx^2 + Δy^2 + nether_point.z
end

const NETHER_POINTS = (
    (x=0.0, y=0.0, z=0.0, biome=nether_wastes),
    (x=0.0, y=-0.5, z=0.0, biome=soul_sand_valley),
    (x=0.4, y=0.0, z=0.0, biome=crimson_forest),
    (x=0.0, y=0.5, z=0.375^2, biome=warped_forest),
    (x=-0.5, y=0.0, z=0.175^2, biome=basalt_deltas),
)

#==========================================================================================#
# Biome Generation for 2D and 3D, with scale != 1
#==========================================================================================#

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

"""
    fill_radius!(out::AbstractMatrix{BiomeID}, x, z, id::BiomeID, radius)

Fills a circular area around the point `(x, z)` in `out` with the biome `id`,
within a given `radius`.
"""
function fill_radius!(out::AbstractMatrix{BiomeID}, x, z, id::BiomeID, radius)
    (r = trunc(Int, radius)) <= 0 && return nothing
    r_square = trunc(Int, radius^2)

    # optimization: we do not need to fill the whole map
    # we can just fill the square around the point
    # x_min, x_max, z_min, z_max are the bounds of the square
    x_min = max(first(axes(out, 1)), x - r)
    x_max = min(last(axes(out, 1)), x + r)
    z_min = max(first(axes(out, 2)), z - r)
    z_max = min(last(axes(out, 2)), z + r)

    for x_i in x_min:x_max, z_i in z_min:z_max
        if (x - x_i)^2 + (z - z_i)^2 <= r_square
            out[x_i, z_i] = id
        end
    end
    return nothing
end

# Assume out is filled with BIOME_NONE
function gen_biomes_unsafe!(
    nn::NetherNoise, map2D::MCMap{2}, scale::Val{S}, confidence=1
) where {S}
    S <= 3 && throw(ArgumentError(lazy"Scale must be >= 4"))
    scale = S ÷ 4

    # The Δnoise is the distance between the first and second closest
    # biomes within the noise space. Dividing this by the greatest possible
    # gradient (~0.05) gives a minimum diameter of voxels around the sample
    # cell that will have the same biome.
    inv_grad = 1.0 / (confidence * 0.05 * 2) / scale

    x_is, z_is = axes(map2D)
    for z_i in z_is, x_i in x_is
        if !isnone(map2D[x_i, z_i])
            continue  # Already filled with a specific biome
        end

        x_real_mc, z_real_mc = x_i * scale, z_i * scale
        biome, Δnoise = get_biome_and_delta(nn, x_real_mc, z_real_mc)
        map2D[x_i, z_i] = biome

        # radius around the sample cell that will have the same biome
        cell_radius = Δnoise * inv_grad
        fill_radius!(map2D, x_i, z_i, biome, cell_radius)
    end
    return nothing
end

function gen_biomes_unsafe!(
    nn::NetherNoise, map3d::MCMap{3}, scale::Val{S}, confidence=1
) where {S}
    # At scale != 1, the biome does not change with the y coordinate
    # So we simply take the first y coordinate and fill the other ones with the same biome
    y_is = axes(map3d, 3)
    first_yi = first(y_is)
    first_square_y = @view map3d[:, :, first_yi]
    gen_biomes_unsafe!(nn, first_square_y, scale, confidence)
    for y_i in y_is
        y_i != first_yi && copyto!(map3d[:, :, y_i], first_square_y)
    end
    return nothing
end

function gen_biomes!(
    nn::NetherNoise, mc_map::MCMap, scale::Val{S}, confidence=1, version::MCVersion=MC_UNDEF
) where {S}
    fill!(mc_map, BIOME_NONE)
    _manage_less_1_15!(mc_map, version) && return nothing
    gen_biomes_unsafe!(nn, mc_map, scale, confidence)
    return nothing
end

#==========================================================================================#
# Biome Generation for 2D and 3D, with scale == 1
#==========================================================================================#

# See the comment on get_biome_unsafe for the explanation of the main idea

function gen_biomes_unsafe!(
    nn::NetherNoise{UInt64},
    map3D::MCMap{3},
    ::Val{scale},
    confidence=1,
    version::MCVersion=MC_UNDEF,
) where {scale}

    # If there is only one value, simple wrapper around get_biome_unsafe
    if length(map3D) == 1
        x, z, y = origin_coords(map3D)
        map3D[1] = get_biome_unsafe(nn, x, z, y, Val(4))
        return nothing
    end

    # The minimal map where we are sure we can find the source coordinates at scale 4
    biome_parents = get_voronoi_src_map2D(map3D)
    gen_biomes!(nn, biome_parents, Val(4), confidence, version)

    # Generate the biomes at scale 4
    sha = nn.sha
    x_is, z_is, y_is = axes(map3D)
    for y_i in y_is, z_i in z_is, x_i in x_is
        # See the comment on get_biome_unsafe for the explanation
        source_x, source_z, _ = voronoi_access_3d(sha, x_i, z_i, y_i)
        result = biome_parents[source_x, source_z]
        @inbounds map3D[x_i, z_i, y_i] = result
    end
    return nothing
end

function gen_biomes!(
    nn::NetherNoise, map3D::MCMap{3}, ::Val{1}, confidence=1, version::MCVersion=MC_UNDEF
)
    _manage_less_1_15!(map3D, version) && return nothing
    # we do not need to fill with BIOME_NONE in this case
    gen_biomes_unsafe!(nn, map3D, Val(1), confidence, version)
    return nothing
end

function gen_biomes!(
    nn::NetherNoise{UInt64},
    map2D::MCMap{2},
    ::Val{1},
    confidence=1,
    version::MCVersion=MC_UNDEF,
)
    msg = "generate the nether biomes at scale 1 requires a 3D map because \
            the biomes depend on the y coordinate. You can create a 3D map with \
            a single y coordinate from a 2D map with `MCMap{3}(map, y)`."
    throw(ArgumentError(msg))
end
