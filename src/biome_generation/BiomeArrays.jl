module BiomeArrays

export WorldMap, view2d, coordinates, true_coordinates

using Base: @propagate_inbounds
using OffsetArrays
using ...Biomes: BIOME_NONE, Biome
using ..BiomeGeneration: Scale

WorldMap{N} = AbstractArray{Biome, N}

"""
    WorldMap{N} where N (N = 2, 3)
    WorldMap(xrange::UnitRange, zrange::UnitRange, yrange::UnitRange)
    WorldMap(xrange::UnitRange, zrange::UnitRange, y::Number)
    WorldMap(xrange::UnitRange, zrange::UnitRange)
    WorldMap(;x, z, y)

A 2D or 3D array of biomes. It is the main data structure used to store the biomes of a
Minecraft world. It is a simple wrapper around `AbstractArray{Biome, N}`. So anything that
works with arrays should work with `WorldMap`.

See also: [`view2d`](@ref), [`coordinates`](@ref)
"""
function WorldMap(range::Vararg{UnitRange, N}) where {N}
    N != 2 && N != 3 && throw(ArgumentError("Only 2D and 3D worlds are supported. Got $N."))
    return fill(BIOME_NONE, range...)
end

to_unit_range(coord::Number) = range(coord, coord)
to_unit_range(coord::UnitRange) = coord

WorldMap(x, z, y) = WorldMap(to_unit_range(x), to_unit_range(z), to_unit_range(y))
WorldMap(; x, z, y) = WorldMap(x, z, y)

"""
    view2d(W::WorldMap{3}) -> WorldMap{2}

View a 3D world as a 2D world. Only works if the y size is 1. Otherwise, it throws an error.
Useful for functions that only work with 2D worlds, even if the y size is 1, like 2d
visualization.

!!! warning
    The returned object is a view, so modifying it will also modify the original world. Use
    `copy` to get a new independent world.
"""
function view2d(W::WorldMap{3})
    size_y = size(W)[3]
    if size_y != 1
        msg = "Cannot view a 3D cube as a 2D square if the y size is greater than 1"
        throw(ArgumentError(msg))
    end
    y = first(axes(W)[3])
    return @view W[:, :, y]
end
view2d(x::WorldMap{2}) = x

"""
    coordinates(M::WorldMap) -> CartesianIndices

Wrapper around `CartesianIndices` to get the coordinates of the biomes in the map. Useful
to iterate over the coordinates of the map.
"""
coordinates(M::WorldMap) = CartesianIndices(M)
true_coordinates(M::WorldMap) = coordinates(M)

struct ScaledWorldMap{S, N, A <: WorldMap{N}} <: WorldMap{N}
    parent::A
end
ScaledWorldMap{S}(x::AbstractArray{Int, N}) where {S, N} = ScaledWorldMap{S, N, typeof(x)}(x)

scale(::ScaledWorldMap{S, N}) where {S, N} = Scale(S)

# TODO: move this outside of the BiomeArrays module and rename it to `rescale` or something
# like that
shift_coord(W::ScaledWorldMap, x) = shift_coord(scale(W), x)
shift_coord(::Scale{1}, x::Real) = x
for shift in 1:8
    S = 1 << shift
    @eval shift_coord(::Scale{$S}, x::Real) = x >> $shift
end
function shift_coord(s::Scale{S}, u::UnitRange) where {S}
    return range(shift_coord(s, first(u)), shift_coord(s, last(u)))
end

function check_ax(s::Scale{S}, ax::UnitRange) where {S}
    if (length(ax) != 1) && (first(ax) % S != 0 || last(ax) % S != 0)
        throw(ArgumentError("The first and last elements of the range must be multiples of the scale. Got $ax for a scale of $S."))
    end
    return s, ax
end

function ScaledWorldMap(s::Scale{S}, range::Vararg{UnitRange, N}) where {S, N}
    parent = WorldMap{N}(map(r -> shift_coord(check_ax(s, r)...), range)...)
    return ScaledWorldMap{S}(parent)
end

# need this because of github.com/JuliaLang/julia/issues/57196
multr(r::OrdinalRange, x::Integer) = range(first(r) * x, last(r) * x; step=step(r) * x)

notscaled(w::ScaledWorldMap) = w.parent
Base.parent(w::ScaledWorldMap) = w.parent
Base.fill!(w::ScaledWorldMap, v) = fill!(w.parent, v)
true_indices(w::ScaledWorldMap{S}) where {S} = map(i -> multr(i, S), axes(w.parent))
coordinates(w::ScaledWorldMap) = CartesianIndices(w)
true_coordinates(w::ScaledWorldMap) = CartesianIndices(true_indices(w))

function Base.axes(fw::ScaledWorldMap{S}) where {S}
    map(ax -> range(first(ax) * S, last(ax) * S), axes(fw.parent))
end
Base.size(fw::ScaledWorldMap{S}) where {S} = map(length, axes(fw))

@propagate_inbounds function Base.getindex(W::ScaledWorldMap, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(W, I...)
    W.parent[map(i -> shift_coord(W, i), I)...]
end

@propagate_inbounds function Base.setindex!(
    W::ScaledWorldMap{S}, v, I::Vararg{Int, N},
) where {S, N}
    coords = map(i -> shift_coord(W, i), I)
    @boundscheck all(map((c, i) -> c * S == i, coords, I)) || throw(BoundsError(W, I))
    @inbounds W.parent[coords...] = v
end

end # module