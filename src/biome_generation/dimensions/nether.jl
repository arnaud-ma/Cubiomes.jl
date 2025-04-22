using Base.Iterators

#region definition
# ---------------------------------------------------------------------------- #
#                                  Definition                                  #
# ---------------------------------------------------------------------------- #

"""
    Nether(::UndefInitializer, V::MCVersion)

The Nether dimension. See [`Dimension`](@ref) for general usage.

# Minecraft version <1.16

Before version 1.16, the Nether is only composed of nether wastes. Nothing else.

# Minecraft version >= 1.16 specificities

- If the 1:1 scale will never be used, adding `sha=Val(false)` to `setseed!` will
  save a very small amount of time (of the order of 100ns up to 1µs). The sha
  is a precomputed value only used for the 1:1 scale. But the default behavior is
  to compute the sha at each seed change for simplicity.

- In the biome generation functions, a last paramter `confidence` can be passed. It
  is a performance-related parameter between 0 and 1. A bit the same as the
  `scale` parameter, but it is a continuous value, and the scale is not modified.
"""
abstract type Nether{V} <: Dimension{V} end
label(::Nether) = "Nether"

# Nothing to do if version is <1.16. The nether is only composed of nether_wastes
struct Nether1_16Minus{V} <: Nether{V} end
Nether(::UndefInitializer, V::mcvt"<1.16") = Nether1_16Minus{V}()
setseed!(::Nether1_16Minus, seed::UInt64) = nothing
getbiome(::Nether1_16Minus, x::Real, z::Real, y::Real, ::Scale) = Biomes.nether_wastes
genbiomes!(::Nether1_16Minus, out::WorldMap, ::Scale) = fill!(out, Biomes.nether_wastes)

struct Nether1_16Plus{V} <: Nether{V}
    temperature::DoublePerlin{2}
    humidity::DoublePerlin{2}
    sha::SomeSha
    rng_temp::JavaRandom
end

function Nether(::UndefInitializer, V::mcvt">=1.16")
    return Nether1_16Plus{V}(
        DoublePerlin{2}(undef),
        DoublePerlin{2}(undef),
        SomeSha(nothing),
        JavaRandom(undef),
    )
end

Utils.isundef(nether::Nether1_16Plus) = any(is_undef, (nether.temperature, nether.humidity))

function setseed!(nn::Nether1_16Plus, seed::UInt64; sha = true)
    setseed🎲(nn.rng_temp, seed)
    setrng!🎲(nn.temperature, nn.rng_temp, -7)

    setseed🎲(nn.rng_temp, seed + 1)
    setrng!🎲(nn.humidity, nn.rng_temp, -7)

    if sha
        setseed!(nn.sha, seed)
    else
        reset!(nn.sha)
    end
    return nothing
end
#endregion

#region base dispatch
# ---------------------------------------------------------------------------- #
#                                 Base dispatch                                #
# ---------------------------------------------------------------------------- #

Base.show(io::IO, ::Nether1_16Minus{V}) where {V} = print(io, "Nether($V<1.16)")

function Base.show(io::IO, ::MIME"text/plain", ::Nether1_16Minus{V}) where {V}
    println(io, "Nether Dimension ($V<1.16):")
    println(io, "├ MC version: ", V)
    println(io, "└ Only contains nether_wastes biome")
    return nothing
end

function Base.show(io::IO, nether::Nether1_16Plus)
    if isundef(nether)
        print(io, "Nether($V ≥ 1.16, uninitialized)")
        return
    end

    sha_status = isnothing(nether.sha[]) ? "unset" : "set"
    print(io, "Nether($V ≥ 1.16, SHA ", sha_status, ")")
    return nothing
end

function Base.show(io::IO, mime::MIME"text/plain", nether::Nether1_16Plus{V}) where {V}
    if isundef(nether)
        print(io, "Nether Dimension ($V ≥ 1.16, uninitialized)")
        return nothing
    end

    println(io, "Nether Dimension ($V ≥ 1.16):")

    # Display SHA status
    sha_status = isnothing(nether.sha[]) ? "not set" : "set"
    println(io, "├ SHA: ", sha_status)

    # Display temperature noise
    println(io, "├ Temperature noise:")
    _show_noise_to_textplain(io, mime, nether.temperature, '│', '\n')

    # Display humidity noise
    println(io, "└ Humidity noise:")
    _show_noise_to_textplain(io, mime, nether.humidity, ' ', "")
    return nothing
end


Base.:(==)(::Nether1_16Minus{V}, ::Nether1_16Minus{V}) where {V} = true
function Base.:(==)(n1::Nether1_16Plus{V}, n2::Nether1_16Plus{V}) where {V}
    return (n1.humidity == n2.humidity) && (n1.humidity == n2.humidity) && (n1.sha[] == n2.sha[])
end


#region getbiome
# ---------------------------------------------------------------------------- #
#                                   getbiome                                  #
# ---------------------------------------------------------------------------- #

# y coordinate not used in scale != 1
function getbiome(nn::Nether1_16Plus, x::Real, z::Real, y::Real, scale::Scale)
    return getbiome(nn, x, z, scale)
end

function getbiome(nn::Nether1_16Plus, x::Real, z::Real, y::Real, ::Scale{1})
    source_x, source_z, _ = voronoi_access(nn.sha[], x, z, y)
    return getbiome(nn, source_x, source_z, Scale(4))
end

function getbiome(nn::Nether1_16Plus, x::Real, z::Real, ::Scale{S}) where {S}
    scale = S >> 2
    return getbiome(nn, x * scale, z * scale, Scale(4))
end

function getbiome(nn::Nether1_16Plus, x::Real, z::Real, ::Scale{4})
    temperature = sample_noise(nn.temperature, x, z)
    humidity = sample_noise(nn.humidity, x, z)
    return find_closest_biome(temperature, humidity)
end

function getbiome_and_delta(nn::Nether1_16Plus, coord::CartesianIndex)
    temperature = sample_noise(nn.temperature, coord)
    humidity = sample_noise(nn.humidity, coord)
    biome, dist1, dist2 = find_closest_biome_with_dists(temperature, humidity)
    return biome, √dist1 - √dist2
end

function calculate_distance_squared(point, temperature, humidity)
    return (point.x - temperature)^2 + (point.y - humidity)^2 + point.z_square
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
    (x = 0.0, y = 0.0, z_square = 0.0, biome = Biomes.nether_wastes),
    (x = 0.0, y = -0.5, z_square = 0.0, biome = Biomes.soul_sand_valley),
    (x = 0.4, y = 0.0, z_square = 0.0, biome = Biomes.crimson_forest),
    (x = 0.0, y = 0.5, z_square = 0.375^2, biome = Biomes.warped_forest),
    (x = -0.5, y = 0.0, z_square = 0.175^2, biome = Biomes.basalt_deltas),
)
#endregion

#region genbiomes!
# ---------------------------------------------------------------------------- #
#                                  genbiomes!                                 #
# ---------------------------------------------------------------------------- #

function distance_square(coord1::CartesianIndex, coord2::CartesianIndex)
    return sum(abs2, (coord1 - coord2).I)
end

# We could generalize this function to any dimension, but not necessary for now
# and may make the code less readable.
"""
    fill_radius!(out::WorldMap{N}, center::CartesianIndex{2}, id::Biome, radius)

Fills a circular area around the point `center` in `out` with the biome `id`,
within a given `radius`. Assuming `radius`>=0. If `center` is outside the `out`
coordinates, nothing is done.
"""
function fill_radius!(
        out::WorldMap{N}, center::CartesianIndex{2}, id::Biomes.Biome, radius,
    ) where {N}
    r = floor(Int, radius)
    r_square = r^2

    # optimizations:
    # we know that (x, z) is a coord to be filled implies:
    # - (x, z) is in the array coordinates (axes(out, 1) for x, axes(out, 2) for z)
    # - (x, z) is in the square of center `center` and edges of the same size `r`
    # so we can simply iterate over the intersection coordinates.
    coords = CartesianIndices(
        (
            range(center[1] - r, center[1] + r) ∩ axes(out, 1),
            range(center[2] - r, center[2] + r) ∩ axes(out, 2),
        )
    )

    for coord in coords
        if distance_square(coord, center) <= r_square
            @inbounds out[coord] = id
        end
    end
    return nothing
end

# Assume out is filled with BIOME_NONE
function genbiomes_unsafe!(
        nn::Nether1_16Plus, map2d::WorldMap{2}, ::Scale{S};
        confidence = 1,
    ) where {S}
    scale = S >> 2

    # The Δnoise is the distance between the first and second closest
    # biomes within the noise space. Dividing this by the greatest possible
    # gradient (~0.05) gives a minimum diameter of voxels around the sample
    # cell that will have the same biome.
    # inv_grad = 1.0 / (confidence * 0.05 * 2) / scale
    inv_grad = inv(0.05 * 2 * confidence * scale)

    for coord in coordinates(map2d)
        if !Biomes.isnone(map2d[coord])
            continue  # Already filled with a specific biome
        end
        biome, Δnoise = getbiome_and_delta(nn, coord * scale)
        @inbounds map2d[coord] = biome

        # radius around the sample cell that will have the same biome
        cell_radius = Δnoise * inv_grad
        fill_radius!(map2d, coord, biome, cell_radius)
    end
    return nothing
end

function genbiomes_unsafe!(
        nn::Nether1_16Plus, map3d::WorldMap{3}, scale::Scale;
        confidence = 1
    )
    # At scale != 1, the biome does not change with the y coordinate
    # So we simply take the first y coordinate and fill the other ones with the same biome
    ys = axes(map3d, 3)
    first_square_y = @view map3d[:, :, first(ys)]
    genbiomes_unsafe!(nn, first_square_y, scale; confidence)

    for y in Iterators.drop(ys, 1) # skip the first y coordinate
        copyto!(map3d[:, :, y], first_square_y)
    end
    return nothing
end

function genbiomes!(nn::Nether1_16Plus, world::WorldMap, scale::Scale; confidence = 1)
    fill!(world, Biomes.BIOME_NONE)
    return genbiomes_unsafe!(nn, world, scale; confidence)
end

function genbiomes!(nn::Nether1_16Plus, world3d::WorldMap{3}, ::Scale{1}; confidence = 1)
    coords = coordinates(world3d)
    # If there is only one value, simple wrapper around getbiome_unsafe
    if isone(length(coords))
        coord = first(coords)
        world3d[coord] = getbiome(nn, coord.I, Scale(4))
        return nothing
    end

    # The minimal map where we are sure we can find the source coordinates at scale 4
    biome_parent_axes = voronoi_source(world3d, #=dim=# Val(2))
    biome_parents = view_reshape_cache_like(biome_parent_axes)
    genbiomes!(nn, biome_parents, Scale(4); confidence)

    sha = nn.sha[]
    for coord in coords
        x, z, _ = voronoi_access(sha, coord)
        result = biome_parents[x, z]
        @inbounds world3d[coord] = result
    end
    return nothing
end
#endregion
