include("interface.jl")

using OffsetArrays: OffsetVector
using StaticArrays: MVector
#region RNG
# ---------------------------------------------------------------------------- #
#                            Specific rng for Perlin                           #
# ---------------------------------------------------------------------------- #

"""
    next_perlin🎲(rng::JavaRandom, ::Type{Int32}; start=0, stop) -> Int32
    next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}; start=0, stop) -> Int3

Same as [`next🎲`](@ref) but with a different implementation specific for the perlin noise.
Don't ask why this is different, it's just how Minecraft does it.

See also: [`next🎲`](@ref)
"""
function next_perlin🎲 end

next_perlin🎲(rng::JavaRandom, ::Type{Int32}, stop::Real) = next🎲(rng, Int32, stop)

function next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}, stop::Real)::Int32
    stop += 1
    mask = typemax(UInt32)
    r = (next🎲(rng, UInt64) & mask) * stop
    if (r & mask) < stop
        while (r & mask) < ((~stop + 1) % stop)
            r = (next🎲(rng, UInt64) & mask) * stop
        end
    end
    return r >> 32
end

function next_perlin🎲(rng::AbstractJavaRNG, ::Type{T}, start::Real, stop::Real) where {T}
    return next_perlin🎲(rng, Int32, stop - start) + start
end

function next_perlin🎲(rng::AbstractJavaRNG, ::Type{T}, range::AbstractRange) where {T}
    return next_perlin🎲(rng, T, first(range), last(range))
end

#endregion
#region Perlin
# ---------------------------------------------------------------------------- #
#                                 Perlin Noise                                 #
# ---------------------------------------------------------------------------- #

PermsType = OffsetVector{UInt8,MVector{257,UInt8}}
Perms(::UndefInitializer) = OffsetVector(MVector{257,UInt8}(undef), 0:256)

@inline function init_perlin_noise_perm!(perms::PermsType)
    # we restrain the type to PermsType to be able to use the @inbounds macro
    # in a safe way
    @inbounds for i in 0x0:0xFF
        perms[i] = i
    end
end

"""
    Perlin
The type for the perlin noise. See https://en.wikipedia.org/Perlin_Noise to know how it works.

See also: [`Noise`](@ref), [`sample_noise`](@ref), [`sample_simplex`](@ref), [`OctaveNoise`](@ref)
"""
mutable struct Perlin <: Noise
    permutations::PermsType
    x::Float64
    y::Float64
    z::Float64
    const_y::Float64
    const_index_y::UInt8
    const_smooth_y::Float64
    amplitude::Float64
    lacunarity::Float64
end

function Perlin(::UndefInitializer)
    return Perlin(
        Perms(undef),
        NaN, #x
        NaN, #y
        NaN, #z
        NaN, #const_y
        zero(UInt8), #const_index_y
        NaN, #const_smooth_y
        NaN, #amplitude
        NaN, #lacunarity
    )
end

function is_undef(p::Perlin)
    return any(isnan, (p.x, p.y, p.z, p.const_y, p.const_smooth_y, p.amplitude, p.lacunarity))
end

function set_rng!🎲(perlin::Perlin, rng::AbstractJavaRNG)
    x = next🎲(rng, Float64, 0:256)
    y = next🎲(rng, Float64, 0:256)
    z = next🎲(rng, Float64, 0:256)

    permutations = perlin.permutations
    init_perlin_noise_perm!(permutations)
    fill_permutations!🎲(rng, permutations)
    perlin.const_y, perlin.const_index_y, perlin.const_smooth_y = init_coord_values(y)
    perlin.amplitude = one(Float64)
    perlin.lacunarity = one(Float64)
    perlin.x, perlin.y, perlin.z = x, y, z
    return nothing
end

"""
    fill_permutations!🎲(rng::AbstractRNG_MC, perms::PermsType)

Fill the permutations vector with the values [|0, 255|] in a random order.
"""
function fill_permutations!🎲(rng::AbstractJavaRNG, perms::PermsType)
    @inbounds for i in 0:255
        perms[i] = i
    end
    # shuffle the values
    @inbounds for i in 0:255
        j = next_perlin🎲(rng, Int32, i:255)
        perms[i], perms[j] = perms[j], perms[i]
    end
    perms[256] = perms[0]
    return nothing
end

"""
    smoothstep_perlin_unsafe(x)

Compute ``6x^5 - 15x^4 + 10x^3``, the smoothstep function used in Perlin noise. See
https://en.wikipedia.org/wiki/Smoothstep#Variations for more details.

This function is unsafe because it is assuming that 0 <= x <= 1 (it does not clamp the input).
"""
smoothstep_perlin_unsafe(x) = x^3 * muladd(x, muladd(6, x, -15), 10)

"""
    init_coord_values(coord)

Initialize one coordinate for the Perlin noise sampling.

# Returns:
- the fractional part of `coord`
- the integer part of `coord`, modulo UInt8
- the smoothstep value of the fractional part of `coord`

See also: [`smoothstep_perlin_unsafe`](@ref)
"""
function init_coord_values(coord)
    # We can't use `modf` because use `trunc` instead of `floor`
    # but it's the same idea
    index = floor(coord)
    frac_coord = coord - index

    #! the following line is the most critical
    # because it is used a lot, and conversion from Int then to UInt8 is not instantaneous
    # TODO: find a way to optimize this
    # We can't simply use `UInt8(index % 256)` which is faster because
    # if index is negative, an error will be thrown. We need to be sure that
    # it will have the same behavior as the original Java/C code when a float
    # is casted to an uint8
    index = Int(index) % UInt8
    return frac_coord, index, smoothstep_perlin_unsafe(frac_coord)
end

"""
    indexed_lerp(idx::Integer, x, y, z)

Use the lower 4 bits of `idx` as a simple hash to combine the `x`, `y`, and `z` values into
a single number (a new index), to be used in the Perlin noise interpolation.
"""
function indexed_lerp(idx::Integer, x, y, z)
    lower_4bits = UInt8(idx & 0xF)
    lower_4bits == 0x0 && return x + y
    lower_4bits == 0x1 && return -x + y
    lower_4bits == 0x2 && return x - y
    lower_4bits == 0x3 && return -x - y
    lower_4bits == 0x4 && return x + z
    lower_4bits == 0x5 && return -x + z
    lower_4bits == 0x6 && return x - z
    lower_4bits == 0x7 && return -x - z
    lower_4bits == 0x8 && return y + z
    lower_4bits == 0x9 && return -y + z
    lower_4bits == 0xA && return y - z
    lower_4bits == 0xB && return -y - z
    lower_4bits == 0xC && return x + y
    lower_4bits == 0xD && return -y + z
    lower_4bits == 0xE && return -x + y
    lower_4bits == 0xF && return -y - z

    return error(lazy"lower 4 bits are in fact more than 4 bits ???")
end

"""
    interpolate_perlin(idx::PermsType, d1, d2, d3, h1, h2, h3, t1, t2, t3) -> Real

Interpolate the Perlin noise at the given coordinates.

# Arguments
- The `idx` parameter is the permutations
array.
- The `d1`, `d2`, and `d3` parameters are the fractional parts of the `x`, `y`, and `z`
coordinates.
- The `h1`, `h2`, and `h3` parameters are the integer parts of the `x`, `y`, and `z`
coordinates.
- The `t1`, `t2`, and `t3` parameters are the smoothstep values of the fractional parts
of the `x`, `y`, and `z` coordinates.

See also: [`init_coord_values`](@ref)
"""
function interpolate_perlin(idx::PermsType, d1, d2, d3, h1, h2, h3, t1, t2, t3)
    # TODO: "@inbounds begin" once we are sure that the code is correct
    a1 = idx[h1] + h2
    b1 = idx[h1 + 1] + h2

    a2 = idx[a1] + h3
    b2 = idx[b1] + h3
    a3 = idx[a1 + 1] + h3
    b3 = idx[b1 + 1] + h3

    #! format: off
    l1 = indexed_lerp(idx[a2],     d1    , d2    , d3    )
    l2 = indexed_lerp(idx[b2],     d1 - 1, d2    , d3    )
    l3 = indexed_lerp(idx[a3],     d1    , d2 - 1, d3    )
    l4 = indexed_lerp(idx[b3],     d1 - 1, d2 - 1, d3    )
    l5 = indexed_lerp(idx[a2 + 1], d1    , d2    , d3 - 1)
    l6 = indexed_lerp(idx[b2 + 1], d1 - 1, d2    , d3 - 1)
    l7 = indexed_lerp(idx[a3 + 1], d1    , d2 - 1, d3 - 1)
    l8 = indexed_lerp(idx[b3 + 1], d1 - 1, d2 - 1, d3 - 1)
    #! format: on
    # end
    l1 = lerp(t1, l1, l2)
    l3 = lerp(t1, l3, l4)
    l5 = lerp(t1, l5, l6)
    l7 = lerp(t1, l7, l8)

    l1 = lerp(t2, l1, l3)
    l5 = lerp(t2, l5, l7)
    return lerp(t3, l1, l5)
end

function sample_noise(noise::Perlin, x, y, z, yamp=0, ymin=0)
    if iszero(y)
        y, index_y, smooth_y = noise.const_y, noise.const_index_y, noise.const_smooth_y
    else
        y, index_y, smooth_y = init_coord_values(y + noise.y)
    end
    x, index_x, smooth_x = init_coord_values(x + noise.x)
    z, index_z, smooth_z = init_coord_values(z + noise.z)
    if !iszero(yamp)
        yclamp = ymin < y ? ymin : y
        y -= floor(yclamp / yamp) * yamp
    end

    #! format: off
    return interpolate_perlin(
        noise.permutations,
        x,        y,       z,
        index_x,  index_y, index_z,
        smooth_x, smooth_y, smooth_z
    )
    #! format: on
end

function sample_perlin_beta17_terrain(noise::Perlin, v, d1, d2, d3, yLacAmp)
    # TODO
    error("not implemented")
    return nothing
end

#endregion
#region simplex
# ---------------------------------------------------------------------------- #
#          Simplex Noise (https://en.wikipedia.org/wiki/Simplex_noise)         #
# ---------------------------------------------------------------------------- #
"""
    simplex_gradient(idx, x, y, z, d)

Compute the gradient of the simplex noise at the given coordinates.

See also: [`sample_simplex`](@ref)
"""
function simplex_gradient(idx, x, y, z, d)
    con = d - (x^2 + y^2 + z^2)
    con < zero(con) && return zero(con)
    con *= con
    return con * con * indexed_lerp(idx, x, y, z)
end

const SKEW::Float64 = (√3 - 1) / 2
const UNSKEW::Float64 = (3 - √3) / 6

"""
    sample_simplex(noise::Perlin, x, y)

Sample the given noise at the given 2D coordinate using the simplex noise
algorithm instead of perlin noise. See https://en.wikipedia.org/wiki/Simplex_noise

See also: [`sample_noise`](@ref), [`Perlin`](@ref)
"""
function sample_simplex(noise::Perlin, x, y)
    hf = (x + y) * SKEW
    hx = floor(Int, x + hf)
    hz = floor(Int, y + hf)

    mhxz = (hx + hz) * UNSKEW
    x0 = x - (hx - mhxz)
    y0 = y - (hz - mhxz)

    offx = Int(x0 > y0)
    offz = 1 - offx

    # TODO: implicit conversion from Int to Float64 is slow here
    x1 = x0 - offx + UNSKEW
    y1 = y0 - offz + UNSKEW
    x2 = x0 - 1 + 2 * UNSKEW
    y2 = y0 - 1 + 2 * UNSKEW

    p = noise.permutations
    mask = typemax(UInt8)
    @inbounds begin
        gi0 = p[(mask & hz)]
        gi1 = p[(mask & (hz + offz))]
        gi2 = p[(mask & (hz + 1))]

        gi0 = p[(mask & (gi0 + hx))]
        gi1 = p[(mask & (gi1 + hx + offx))]
        gi2 = p[(mask & (gi2 + hx + 1))]
    end
    t =
        simplex_gradient(gi0 % 12, x0, y0, 0.0, 0.5) +
        simplex_gradient(gi1 % 12, x1, y1, 0.0, 0.5) +
        simplex_gradient(gi2 % 12, x2, y2, 0.0, 0.5)

    return 70t
end
#endregion