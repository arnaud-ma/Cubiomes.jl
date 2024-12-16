using StaticArrays: SizedVector
using OffsetArrays: Origin

struct EndNoise{S<:Union{Nothing,UInt64}} <: Noise
    perlin::PerlinNoise
    sha::S
end

function EndNoise(seed::Integer; with_sha::Bool=true)
    perlin = _get_perlin_end(seed)
    if with_sha
        sha = sha256_from_seed(UInt64(unsigned(seed)))
        return EndNoise{UInt64}(perlin, sha)
    end
    return EndNoise{nothing}(perlin, nothing)
end

Noise(seed, ::Type{DIM_END}) = EndNoise(seed)
Noise(seed, sha, ::Type{DIM_END}) = EndNoise(seed, sha)

function _get_perlin_end(seed)
    rng = JavaRandom(seed)
    randjump🎲(rng, Int32, 17_292)
    return PerlinNoise🎲(rng)
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
function original_get_biome(end_noise::EndNoise, x, z, ::Scale{4})
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
            (sample_simplex(end_noise.perlin, real_x, real_z) < -0.9)
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
# Elevations / Heights noise
#==========================================================================================#

function get_elevation(end_noise::EndNoise, x, z)::UInt16
    # if outside of the main island and sample < -0.9
    if (x^2 + z^2 > 4096) && (sample_simplex(end_noise.perlin, x, z) < -0.9)
        return ((abs(x) * 3439 + abs(z) * 147) % 13 + 9)
    end
    return zero(UInt16)
end

function fill_elevations!(end_noise::EndNoise, elevations)
    x_is, z_is = axes(elevations)
    for z_i in z_is, x_i in x_is
        elevations[x_i, z_i] = get_elevation(end_noise, x_i, z_i)
    end
    return nothing
end

# TODO: maybe use sparse matrix instead
function get_elevations(end_noise::EndNoise, mc_map::MCMap{2}, range::Integer=12)
    elevations = similar_expand(UInt16, mc_map, range, range)
    fill_elevations!(end_noise, elevations)
    return elevations
end

const SMOOTH_AXE_POSITIVE, SMOOTH_AXE_NEGATIVE = let
    x = (-25:2:25) .^ 2
    Origin(-12).((x[1:(end - 1)], x[2:end]))
end

Base.@propagate_inbounds function _get_height_sample(
    elevation_getter::Function, x, z, start_height, range::Integer=12
)
    height_sample = start_height

    dist_squared_xs = x < 0 ? SMOOTH_AXE_NEGATIVE : SMOOTH_AXE_POSITIVE
    dist_squared_zs = z < 0 ? SMOOTH_AXE_NEGATIVE : SMOOTH_AXE_POSITIVE

    for z_i in (-range):range
        dist_squared_z = dist_squared_zs[z_i]
        for x_i in (-range):range
            real_x, real_z = x + x_i, z + z_i
            elevation_squared = elevation_getter(real_x, real_z)^2
            if elevation_squared !== zero(UInt16)
                dist_squared_x = dist_squared_xs[x_i]
                noise = (dist_squared_z + dist_squared_x) * elevation_squared
                if noise < height_sample
                    height_sample = noise
                end
            end
        end
    end
    return height_sample
end

function get_height_sample(
    elevations::AbstractMatrix{UInt16}, x, z, start_height, range::Integer=12
)
    # TODO: know how to disable bounds checking (better: propagate_inbounds)
    return _get_height_sample((x, z) -> elevations[x, z], x, z, start_height, range)
end

function get_height_sample(end_noise::EndNoise, x, z, start_height, range::Integer=12)
    return _get_height_sample(
        (x, z) -> get_elevation(end_noise, x, z), x, z, start_height, range
    )
end

function get_height_end(height_value)
    return clamp(-100 - sqrt(height_value), -100, 80)
end

function get_height(end_noise::EndNoise, x, z, range::Integer=12)
    #  64 * (x^2 + z^2) <= 14400 <=> x^2 + z^2 <= 225 (circle of radius 15)
    start = if (abs(x) <= 15 && abs(z) <= 15)
        64 * (x^2 + z^2)
    else
        14_401
    end

    return get_height_end(get_height_sample(end_noise, x, z, start, range))
end

#==========================================================================================#
# Biome Generation
#==========================================================================================#

function biome_from_height(height)::BiomeID
    height > 40 && return end_highlands
    height >= 0 && return end_midlands
    height >= -20 && return end_barrens
    return small_end_islands
end

function biome_from_height_sample(height)::BiomeID
    height < 3600 && return end_highlands  # height < (40 - 100)^2
    height < 10_000 && return end_midlands # height < (0 - 100)^2
    height < 14_400 && return end_barrens  # height < (-20 - 100)^2
    return small_end_islands
end

# equivalent to `biome_from_height_sample ∘ get_height_sample`
function get_biome_unsafe(
    elevation_getter::T, x, z, ::Scale{16}, range::Integer=12
) where {T<:Union{EndNoise,AbstractMatrix{UInt16}}}
    height_sample = get_height_sample(elevation_getter, x, z, 14_401, range)
    return biome_from_height_sample(height_sample)
end

function get_biome(
    elevation_getter::T, x, z, ::Scale{16}, version::MCVersion, range::Integer=12
) where {T}
    if version <= MC_1_0
        throw(
            ArgumentError(
                lazy"Version less than 1.0 does not have the end dimension (got $version)"
            ),
        )
    end
    version <= MC_1_8 && return the_end
    x^2 + z^2 <= 4096 && return the_end
    has_bug_mc_159283(version, x, z) && return small_end_islands
    return get_biome_unsafe(elevation_getter, x, z, Scale(16), range)
end

# helper functions for scale 4 and 64.
# Performance is not impacted by the scale if it is 4, 16 or 64.
# This is just a scaling of the coordinates.
for func_name in (:get_biome_unsafe, :get_biome),
    (S, ω, range) in zip((4, 64), (2, -2), (12, 4))

    @eval begin
        function $func_name(
            height_getter::T, x, z, ::Scale{$S}, version::MCVersion, range::Integer=$range
        ) where {T}
            return $func_name(height_getter, x >> $ω, z >> $ω, Scale(16), version, range)
        end
    end
end

function _gen_biomes!(
    biome_getter::Function, end_noise::EndNoise, map2D::MCMap{2}, range::Integer=12
)
    elevations = get_elevations(end_noise, map2D, range)
    x_is, z_is = axes(map2D)
    for z_i in z_is, x_i in x_is
        map2D[x_i, z_i] = biome_getter(elevations, x_i, z_i)
    end
    return nothing
end

function gen_biomes!(
    end_noise::EndNoise, map2D::MCMap{2}, ::Scale, version::MCVersion, range::Integer=12
) where {Scale}
    return _gen_biomes!(
        (e, x, z) -> get_biome(e, x, z, Scale, version, range), end_noise, map2D, range
    )
end

function gen_biomes_unsafe!(
    end_noise::EndNoise, map2D::MCMap{2}, ::Scale, range::Integer=12
) where {Scale}
    return _gen_biomes!(
        (e, x, z) -> get_biome_unsafe(e, x, z, Scale, range), end_noise, map2D, range
    )
end

#==========================================================================================#
# Biome Generation / Scale 1 ⚠ STILL DRAFT # TODO
#==========================================================================================#

# function gen_biomes_unsafe!(end_noise::EndNoise, mc_map::MCMap{3}, scale::Val{1})
#     biome_parents  = get_voronoi_src_map2D(mc_map)
#     gen_biomes_unsafe!(end_noise, biome_parents, Val(16))
#    # TODO
# end

#==========================================================================================#
# End Height ⚠ STILL DRAFT # TODO
#==========================================================================================#

#TODO: scale 1

# function sample_column_end!(
#     columns::AbstractVector{Float64}, height_getter::T, surface_noise::SurfaceNoise, x, z
# ) where {T}
#     depth = get_height(height_getter, x, z) - 8.0f0
#     for y in axes(columns, 1)
#         noise = sample(surface_noise, x, y, z) + depth
#         noise = clamped_lerp((32 + 46 - y) / 64, -3000, noise)
#         noise = clamped_lerp((y - 1) / 7, -30, noise)
#         columns[y] = noise
#     end
# end

# const END_NOISE_COL_YMIN = 2
# const END_NOISE_COL_YMAX = 18
# const END_NOISE_COL_SIZE = END_NOISE_COL_YMAX - END_NOISE_COL_YMIN + 1
# const UPPER_DROP = Tuple(clamp.([(32 + 46 - y) / 64 for y in 0:32], 0, 1))
# const LOWER_DROP = Tuple(clamp.([(y - 1) / 7 for y in 0:32], 0, 1))

# FullColumnType = OffsetVector{
#     Float64,SizedVector{END_NOISE_COL_SIZE,Float64,Vector{Float64}}
# }

# function create_full_column_end(vec::Vector{Float64})::FullColumnType
#     return Origin(END_NOISE_COL_YMIN)(SizedVector{END_NOISE_COL_SIZE}(vec))
# end

# function sample_column_end!(
#     column::FullColumnType, surface_noise::SurfaceNoiseEnd, height_getter::T, x, z
# ) where {T}
#     # depth is between [-108, +72]
#     # noise is between [-128, +128]
#     # for a sold block we need the upper drop as:
#     #  (72 + 128) * u - 3000 * (1-u) > 0 => upper_drop = u < 15/16
#     # which occurs at y = 18 for the highest relevant noise cell
#     # for the lower drop we need:
#     #  (72 + 128) * l - 30 * (1-l) > 0 => lower_drop = l > 3/23
#     # which occurs at y = 3 for the lowest relevant noise cell

#     # in terms of the depth this becomes:
#     #  l > 30 / (103 + depth)

#     depth = get_height(height_getter, x, z) - 8
#     for y in axes(column, 1)
#         lower_drop = LOWER_DROP[y]
#         if lower_drop * (103 + depth) < 30
#             column[y] = -30
#             continue
#         end
#         upper_drop = UPPER_DROP[y]
#         noise = sample(surface_noise, x, y, z) + depth
#         noise = clamped_lerp(upper_drop, -3000, noise)
#         noise = clamped_lerp(lower_drop, -30, noise)
#         column[y] = noise
#     end
#     return nothing
# end

# function sample_column_end(
#     height_getter::T, surface_noise::SurfaceNoise, x, z
# )::FullColumnType where {T<:Union{EndNoise,AbstractMatrix{UInt16}}}
#     column = create_full_column_end(Vector{Float64}(undef, END_NOISE_COL_SIZE))
#     sample_column_end!(column, surface_noise, height_getter, x, z)
#     return column
# end

# function surface_height(column00, column01, column10, column11, scale, dx, dz)

#     # equivalent to for y_cell in reverse(eachindex(column00)) but
#     # without the first element (the top)
#     y_axis = axes(column00, 1)
#     first_y, last_y = first(y_axis), last(y_axis)
#     @inbounds for y_cell in (last_y - 1):-1:first_y
#         v000 = column00[y_cell]
#         v001 = column01[y_cell]
#         v100 = column10[y_cell]
#         v101 = column11[y_cell]
#         v010 = column00[y_cell + 1]
#         v011 = column01[y_cell + 1]
#         v110 = column10[y_cell + 1]
#         v111 = column11[y_cell + 1]

#         for y in (scale - 1):-1:0
#             dy = y / scale
#             # Note: not dx, dy, dz
#             noise = lerp3(dy, dx, dz, v000, v100, v010, v110, v001, v101, v011, v111)
#             noise > 0 && return y_cell * scale + y
#         end
#     end
#     return 0
# end