using OffsetArrays: OffsetArray, Origin, OffsetMatrix

abstract type Noise end

Noise(seed::String, ::Type{D}) where D<:Dimension  = Noise(java_hashcode(seed), D)


MCMap{N} = OffsetArray{BiomeID,N,Array{BiomeID,N}}
MCMap(A::AbstractArray, args...) = OffsetArray(A, args...)
function MCMap(range::Vararg{UnitRange,N}) where {N}
    N != 2 && N != 3 && throw(ArgumentError("Only 2D and 3D maps are supported"))
    return fill(BIOME_NONE, range...)
end

function MCMap{2}(array::MCMap{3})
    size_x, size_z, size_y = size(array)
    if size_y != 1
        throw(
            ArgumentError(
                "Cannot view a 3D cube as a 2D square if the y size is greater than 1"
            ),
        )
    end
    ax = axes(array)
    return MCMap(reshape(array, size_x, size_z), ax[1], ax[2])
end
function MCMap{3}(array::MCMap{2}, y_index=1)
    return MCMap(reshape(array, size(array)..., 1), axes(array)..., y_index:y_index)
end

origin_coords(arr::OffsetArray) = first.(axes(arr))

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
"""
function similar_expand(
    ::Type{T}, mc_map::OffsetMatrix, expand_x::Int, expand_z::Int
) where {T}
    x, z = origin_coords(mc_map)
    size_x, size_z = size(mc_map)
    return OffsetMatrix{T}(
        undef,
        (x - expand_x):(x + size_x + expand_x - 1),
        (z - expand_z):(z + size_z + expand_z - 1),
    )
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
struct Scale{N} end
Scale(N::Integer) = Scale{N}()

macro scale_str(str)
    x = split(str, ':')
    if length(x) != 2 || x[1] != "1"
        throw(ArgumentError("Bad scale format."))
    end
    return Scale(parse(Int, x[2]))
end
const var"@📏_str" = var"@scale_str"

"""
    get_voronoi_src_map3D(map3D::MCMap{3})::MCMap{3}

Get the 3D map of the 1:1 scale that corresponds to the 1:4 scale map.
"""
function get_voronoi_src_map3D(map3D::MCMap{3})::MCMap{3}
    cx, cy, cz = origin_coords(map3D)
    size_x, size_z, size_y = size(map3D)
    # The >> 2 is equivalent to ÷ 4 but could be faster
    temp_x = cx - 2
    temp_z = cz - 2

    x = temp_x >> 2
    z = temp_z >> 2
    sx = ((temp_x + size_x) >> 2) - x + 2
    sz = ((temp_z + size_z) >> 2) - z + 2

    if size_y < 1
        y, sy = 0, 1
    else
        ty = cy - 2
        y = ty >> 2
        sy = ((ty + size_y) >> 2) - y + 2
    end

    return MCMap(x:(x + sx - 1), y:(y + sy - 1), z:(z + sz - 1))
end

function get_voronoi_src_map2D(mc_map::MCMap)::MCMap{2}
    sx, sz = size(mc_map)[1:2]
    origin_x, origin_z = origin_coords(mc_map)[1:2]
    temp_x = origin_x - 2
    temp_z = origin_z - 2
    x = temp_x >> 2
    z = temp_z >> 2
    sx = ((temp_x + sx) >> 2) - x + 2
    sz = ((temp_z + sz) >> 2) - z + 2
    return MCMap(x:(x + sx - 1), z:(z + sz - 1))
end

function get_voronoi_cell(
    sha::UInt64, x::UInt64, z::UInt64, y::UInt64
)::Tuple{Int32,Int32,Int32}
    s = sha

    s = mc_step_seed(s, x)
    s = mc_step_seed(s, y)
    s = mc_step_seed(s, z)

    s = mc_step_seed(s, x)
    s = mc_step_seed(s, y)
    s = mc_step_seed(s, z)

    new_x = (((s >> 24) & 1023) - 512) * 36
    s = mc_step_seed(s, sha)
    new_y = (((s >> 24) & 1023) - 512) * 36
    s = mc_step_seed(s, sha)
    new_z = (((s >> 24) & 1023) - 512) * 36

    return signed(new_x), signed(new_z), signed(new_y)
end

function get_voronoi_cell(sha::UInt64, x::Int64, z::Int64, y::Int64)
    get_voronoi_cell(sha, unsigned(x), unsigned(z), unsigned(y))
end

# TODO: change this following docstring
"""
    voronoi_access_3d(sha::UInt64, x, y, z)

With 1.15, voronoi changed in preparation for 3D biome generation.
Biome generation now stops at scale 1:4 OceanMix and voronoi is just
an access algorithm, mapping the 1:1 scale onto its 1:4 correspondent.
It is seeded by the first 8-bytes of the SHA-256 hash of the world seed.

Don't ask how it works, it just does.
"""
function voronoi_access_3d(sha::UInt64, x::Integer, z::Integer, y::Integer)
    x -= 2
    y -= 2
    z -= 2

    # Calculate parent cell coordinates by dividing by 4
    parent_cell_x = x >> 2
    parent_cell_y = y >> 2
    parent_cell_z = z >> 2

    # Scale the offsets by 10240 to match the 1:1 scale
    offset_x = (x & 3) * 10240
    offset_y = (y & 3) * 10240
    offset_z = (z & 3) * 10240

    # Initialize variables to track the closest cell
    closest_x, closest_y, closest_z = 0, 0, 0
    min_distance_squared = typemax(UInt64)

    # Iterate over the 8 neighboring cells
    for i in 0:7
        # Determine the offsets for the neighboring cells
        neighbor_offset_x = !iszero(i & 4)  # true for i = 4, 5, 6, 7
        neighbor_offset_y = !iszero(i & 2)  # true for i = 2, 3, 6, 7
        neighbor_offset_z = !iszero(i & 1)  # true for i = 1, 3, 5, 7

        # Calculate the coordinates of the neighboring cell
        neighbor_cell_x = parent_cell_x + neighbor_offset_x
        neighbor_cell_y = parent_cell_y + neighbor_offset_y
        neighbor_cell_z = parent_cell_z + neighbor_offset_z

        voronoi_x, voronoi_z, voronoi_y = get_voronoi_cell(
            sha, neighbor_cell_x, neighbor_cell_z, neighbor_cell_y
        )

        # Adjust the Voronoi cell coordinates by the offsets
        voronoi_x += offset_x - 40 * 1024 * neighbor_offset_x
        voronoi_y += offset_y - 40 * 1024 * neighbor_offset_y
        voronoi_z += offset_z - 40 * 1024 * neighbor_offset_z

        # Update the closest cell if this one is closer
        distance_squared =
            voronoi_x * UInt64(unsigned(voronoi_x)) +
            voronoi_y * UInt64(unsigned(voronoi_y)) +
            voronoi_z * UInt64(unsigned(voronoi_y))

        if distance_squared < min_distance_squared
            min_distance_squared = distance_squared
            closest_x = neighbor_cell_x
            closest_y = neighbor_cell_y
            closest_z = neighbor_cell_z
        end
    end

    return closest_x, closest_z, closest_y
end