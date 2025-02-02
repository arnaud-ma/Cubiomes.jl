module Voronoi

using ..BiomeArrays: World
using ...SeedUtils: mc_step_seed

firsts(coord, ::Val{2}) = coord[1], coord[2]
firsts(coord, ::Val{3}) = coord[1], coord[2], coord[3]
function voronoi_source(ax::AbstractUnitRange)
    return range((first(ax) - 2) >> 2, (last(ax) - 1) >> 2 + 1)
end
function voronoi_source(W::World{N}, dim::Val{D}=Val(N)) where {N, D}
    return map(voronoi_source, firsts(axes(W), dim))
end
voronoi_source2d(W) = voronoi_source(W, Val(2))

new_coord_voronoi(t) = (((t >> 24) & 1023) - 512) * 36

function voronoi_cell(sha::UInt64, x::UInt64, z::UInt64, y::UInt64)
    s = sha

    s = mc_step_seed(s, x)
    s = mc_step_seed(s, y)
    s = mc_step_seed(s, z)

    s = mc_step_seed(s, x)
    s = mc_step_seed(s, y)
    s = mc_step_seed(s, z)

    new_x = new_coord_voronoi(s)
    s = mc_step_seed(s, sha)
    new_y = new_coord_voronoi(s)
    s = mc_step_seed(s, sha)
    new_z = new_coord_voronoi(s)

    return signed(new_x), signed(new_z), signed(new_y)
end

function voronoi_cell(sha::UInt64, x::Int64, z::Int64, y::Int64)
    voronoi_cell(sha, unsigned(x), unsigned(z), unsigned(y))
end
voronoi_cell(sha, coord::NTuple{3}) = voronoi_cell(sha, coord...)

𝟙₀(x) = ifelse(iszero(x), zero(x), one(x))
const OFFSETS = Tuple(Tuple(𝟙₀(i & t) for t in (4, 1, 2)) for i in 0:7)

const CELL_SCALE = 10240
const NEIGHBOR_SCALE = 40 * 1024

function adjust_voronoi_cell(cell, offset, neighbor_offset)
    cell + offset - NEIGHBOR_SCALE * neighbor_offset
end

"""
    voronoi_access(sha::UInt64, coord::Union{CartesianIndex{3}, NTuple{3, T}}) where {T}
    voronoi_access(sha::UInt64, x, z, y)

Compute the closest Voronoi cell based on the given coordinates (at 1:4 scale). Used
by Minecraft to translate the 1:4 scale coordinates to the 1:1 scale.

For example we can find in some part of the biome generation source code:
```julia
>>> function get_biome(dimension, x, z, y, ::Scale{1})
        sx, sz, zy = voronoi_access(dimension, x, z, y)
        get_biome(dimension, sx, sz, sy, Scale(4))
    end
```
"""
function voronoi_access(sha::UInt64, coord::NTuple{3, T}) where {T}
    coord = coord .- 2
    parent = coord .>> 2
    offset = (coord .& 3) .* CELL_SCALE

    closest = (zero(T), zero(T), zero(T))
    min_distance_squared = typemax(UInt64)

    for neighbor_offset in OFFSETS
        neighbors = parent .+ neighbor_offset
        cell = voronoi_cell(sha, neighbors)
        voronoi = adjust_voronoi_cell.(cell, offset, neighbor_offset)
        distance_squared = sum(voronoi .* unsigned.(voronoi))
        if distance_squared < min_distance_squared
            min_distance_squared = distance_squared
            closest = neighbors
        end
    end
    return closest
end
voronoi_access(sha::UInt64, coord::CartesianIndex{3}) = voronoi_access(sha, coord.I)
voronoi_access(sha::UInt64, x, z, y) = voronoi_access(sha, (x, z, y))

end # module