module BiomeArrays

export World, view2d, coordinates, true_coordinates

using Base: @propagate_inbounds
using OffsetArrays
using ...Biomes: BIOME_NONE, Biome
using ..BiomeGeneration: Scale

World{N} =  AbstractArray{Biome, N}

"""
    World{N} where N (N = 2, 3)
    World(xrange::UnitRange, zrange::UnitRange, yrange::UnitRange)
    World(xrange::UnitRange, zrange::UnitRange, y::Number)
    World(xrange::UnitRange, zrange::UnitRange)
    World(;x, z, y)

A 2D or 3D array of biomes. It is the main data structure used to store the biomes of a
Minecraft world. It is a simple wrapper around `AbstractArray{Biome, N}`. So anything that
works with arrays should work with `World`.

See also: [`view2d`](@ref), [`coordinates`](@ref)
"""
function World(range::Vararg{UnitRange, N}) where {N}
    N != 2 && N != 3 && throw(ArgumentError("Only 2D and 3D worlds are supported. Got $N."))
    return fill(BIOME_NONE, range...)
end

World(x, z, y::Number) = World(x, z, y:y)
World(;x, z, y) = World(x, z, y)

"""
    view2d(W::World{3}) -> World{2}

View a 3D world as a 2D world. Only works if the y size is 1. Otherwise, it throws an error.
Useful for functions that only work with 2D worlds, even if the y size is 1, like 2d
visualization.

!!! warning
    The returned object is a view, so modifying it will also modify the original world. Use
    `copy` to get a new independent world.
"""
function view2d(W::World{3})
    size_y = size(W)[3]
    if size_y != 1
        msg = "Cannot view a 3D cube as a 2D square if the y size is greater than 1"
        throw(ArgumentError(msg))
    end
    y = first(axes(W)[3])
    return @view W[:, :, y]
end
view2d(x::World{2}) = x


"""
    coordinates(M::World) -> CartesianIndices

Wrapper around `CartesianIndices` to get the coordinates of the biomes in the world. Useful
to iterate over the coordinates of the world.
"""
coordinates(M::World) = CartesianIndices(M)
true_coordinates(M::World) = coordinates(M)

struct ScaledWorld{S, N, A <: World{N}} <: World{N}
    parent::A
end
ScaledWorld{S}(x::AbstractArray{Int, N}) where {S, N} = ScaledWorld{S, N, typeof(x)}(x)

scale(::ScaledWorld{S, N}) where {S, N} = Scale(S)

# TODO: move this outside of the BiomeArrays module and rename it to `rescale` or something
# like that
shift_coord(W::ScaledWorld, x) = shift_coord(scale(W), x)
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

function ScaledWorld(s::Scale{S}, range::Vararg{UnitRange, N}) where {S, N}
    parent = World{N}(map(r -> shift_coord(check_ax(s, r)...), range)...)
    return ScaledWorld{S}(parent)
end

# need this because of github.com/JuliaLang/julia/issues/57196
multr(r::OrdinalRange, x::Integer) = range(first(r) * x, last(r) * x; step=step(r) * x)

notscaled(w::ScaledWorld) = w.parent
Base.parent(w::ScaledWorld) = w.parent
Base.fill!(w::ScaledWorld, v) = fill!(w.parent, v)
true_indices(w::ScaledWorld{S}) where {S} = map(i -> multr(i, S), axes(w.parent))
coordinates(w::ScaledWorld) = CartesianIndices(w)
true_coordinates(w::ScaledWorld) = CartesianIndices(true_indices(w))

function Base.axes(fw::ScaledWorld{S}) where {S}
    map(ax -> range(first(ax) * S, last(ax) * S), axes(fw.parent))
end
Base.size(fw::ScaledWorld{S}) where {S} = map(length, axes(fw))

@propagate_inbounds function Base.getindex(W::ScaledWorld, I::Vararg{Int, N}) where {N}
    @boundscheck checkbounds(W, I...)
    W.parent[map(i -> shift_coord(W, i), I)...]
end

@propagate_inbounds function Base.setindex!(
    W::ScaledWorld{S}, v, I::Vararg{Int, N},
) where {S, N}
    coords = map(i -> shift_coord(W, i), I)
    @boundscheck all(map((c, i) -> c * S == i, coords, I)) || throw(BoundsError(W, I))
    @inbounds W.parent[coords...] = v
end

end # module