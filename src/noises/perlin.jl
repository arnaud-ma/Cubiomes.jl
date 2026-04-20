using OffsetArrays: OffsetVector
using StaticArrays: MVector

using ..Utils: lerp
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

function _next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}, n::UInt32)
    mask = 0x00000000ffffffff # = UInt64(typemax(UInt32))
    r = ((next🎲(rng, UInt64) & mask) * n)
    (r % UInt32) >= n && return (r >> 32) % Int32

    # it is very rare to be in this case
    # about 1 / 230 000 for each perlin noise initialization for example
    # TODO: add unit tests for this case, as it's not tested at the moment
    while (r % UInt32) < ((~n + one(n)) % n)
        r = (next🎲(rng, UInt64) & mask) * n
    end
    return (r >> 32) % Int32
end

function next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}, stop::Integer)
    return _next_perlin🎲(rng, Int32, UInt32(stop + one(stop)))
end

function next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}, stop::Signed)
    return next_perlin🎲(rng, Int32, unsigned(stop))
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

PermsType = OffsetVector{UInt8, MVector{257, UInt8}}
Perms(::UndefInitializer) = OffsetVector(MVector{257, UInt8}(undef), 0:256)

@inline function init_perlin_noise_perm!(perms::PermsType)
    # we restrain the type to PermsType to be able to use the @inbounds macro
    # in a safe way
    @inbounds for i in 0x00:0xFF
        perms[i] = i
    end
    return nothing
end

"""
    Perlin <: Noise


3D Perlin noise generator with Minecraft-compatible seeding and sampling.

# Fields
- `permutations`: Array of 256 pseudo-random indices (+ repeat of [0]) for gradient lookup
- `x`, `y`, `z`: Random offsets applied to all coordinates (for octave variation)
- `const_y`, `const_index_y`, `const_smooth_y`: Cached y-coordinate values for 2D mode (y=missing)
- `amplitude`: Current octave's amplitude (multiplicative scale, starts at 1.0)
- `lacunarity`: Frequency multiplier for octaves (starts at 1.0)

# Notes
- When y=0 or missing, the noise operates in 2D mode, using precomputed y values for performance.
- The permutation table is shuffled during initialization via [`setrng!🎲`](@ref)

See also: [`Noise`](@ref), [`sample_noise`](@ref), [`sample_simplex`](@ref)
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

function Perlin(perms::Array, args::Vararg{Any, N}) where {N}
    return Perlin(OffsetVector(MVector{257, UInt8}(perms), 0:256), args...)
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

function Utils.isundef(p::Perlin)
    return any(
        isnan, (p.x, p.y, p.z, p.const_y, p.const_smooth_y, p.amplitude, p.lacunarity),
    )
end

function setrng!🎲(perlin::Perlin, rng::AbstractJavaRNG)
    x = next🎲(rng, Float64, 0:256)
    y = next🎲(rng, Float64, 0:256)
    z = next🎲(rng, Float64, 0:256)

    permutations = perlin.permutations
    init_perlin_noise_perm!(permutations)
    shuffle!🎲(rng, permutations)
    perlin.const_y, perlin.const_index_y, perlin.const_smooth_y = init_coord_values(y)
    perlin.amplitude = one(Float64)
    perlin.lacunarity = one(Float64)
    perlin.x, perlin.y, perlin.z = x, y, z
    return nothing
end

"""
    shuffle!🎲(rng::AbstractRNG_MC, perms::PermsType)

Shuffle the permutations array using the given random number generator.
"""
function shuffle!🎲(rng::AbstractJavaRNG, perms::PermsType)
    @inbounds for i in 0:255
        j = next_perlin🎲(rng, Int32, Int32(i), Int32(255))
        perms[i], perms[j] = perms[j], perms[i]
    end
    perms[256] = perms[0]
    return nothing
end

"""
    smoothstep_perlin_unsafe(x)

Compute ``6x^5 - 15x^4 + 10x^3``, the smoothstep function used in Perlin noise. See
https://en.wikipedia.org/wiki/Smoothstep#Variations for more details.

This function is unsafe because it is assuming that ``0 \\leq x \\leq 1`` (it does not clamp the input).
"""
smoothstep_perlin_unsafe(x) = x^3 * muladd(x, muladd(6, x, -15), 10)

"""
    init_coord_values(coordinate::Real) -> (frac_part, grid_index, smoothstep_value)

Extract coordinate components needed for Perlin noise interpolation.

Given a real coordinate value, decomposes it into:
1. Fractional part (always ∈ [0, 1)): position within grid cell
2. Grid index (∈ [0, 255]): which cell in the permutation table
3. Smoothstep value: interpolation weight using Hermite smoothing curve

The smoothstep function f(t) = 6t⁵ - 15t⁴ + 10t³ ensures gradual interpolation
rather than linear, creating the characteristic smooth Perlin noise appearance.
"""
function init_coord_values(coordinate)
    # We can't use `modf` because use `trunc` instead of `floor`
    # but it's the same idea
    index = floor(coordinate)
    frac_coord = coordinate - index
    return frac_coord, Base.unsafe_trunc(UInt8, index), smoothstep_perlin_unsafe(frac_coord)
end

"""
    indexed_lerp(gradient_index::Integer, dx, dy, dz) -> Float64

Compute dot product between a relative displacement vector and a gradient vector.

The lower 4 bits of `gradient_index` select one of 16 predefined 3D gradient directions.
These form a pseudo-random gradient based on the hash value.

The 16 directions cover the 12 edges of a cube plus 4 secondary directions:
- 0x0-0x3: Different combinations of ±x ± y (z-edge aligned gradients)
- 0x4-0x7: Different combinations of ±x ± z (y-edge aligned gradients)
- 0x8-0xB: Different combinations of ±y ± z (x-edge aligned gradients)
- 0xC-0xF: Additional repetitions, because index is 4 bits -> 16 values needed to be used

See: https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/perlin-noise-part-2/improved-perlin-noise.html
"""
function indexed_lerp(gradient_index::Integer, x, y, z)
    # TODO: a gpu-friendly implementation would be to create a SMatrix from StaticArrays
    # of size 3x16 of all the gradients, and simply doing
    # GRADIENTS[:, lower_4bits + 1] ⋅ (x, y, z)
    # dot(GRADIENTS[:, lower_4bits + 1], (x, y, z))
    # by checking the assembly code with @code_native, the compiler knows that it is
    # just λ_1 * x + λ_2 * y + λ_3 * z, where λ_i are the components of the gradient
    # and can fuse the multiplications and additions in a single instruction, while the if-else

    lower_4bits = UInt8(gradient_index & 0x0F)
    lower_4bits == 0x00 && return x + y  # (1, 1, 0)
    lower_4bits == 0x01 && return -x + y # (-1, 1, 0)
    lower_4bits == 0x02 && return x - y  # (1, -1, 0)
    lower_4bits == 0x03 && return -x - y # (-1, -1, 0)
    lower_4bits == 0x04 && return x + z  # (1, 0, 1)
    lower_4bits == 0x05 && return -x + z # (-1, 0, 1)
    lower_4bits == 0x06 && return x - z  # (1, 0, -1)
    lower_4bits == 0x07 && return -x - z # (-1, 0, -1)
    lower_4bits == 0x08 && return y + z  # (0, 1, 1)
    lower_4bits == 0x09 && return -y + z # (0, -1, 1)
    lower_4bits == 0x0A && return y - z  # (0, 1, -1)
    lower_4bits == 0x0B && return -y - z # (0, -1, -1)
    lower_4bits == 0x0C && return x + y  # (1, 1, 0) - same as 0x00
    lower_4bits == 0x0D && return -y + z # (0, -1, 1) - same as 0x09
    lower_4bits == 0x0E && return -x + y # (-1, 1, 0) - same as 0x01
    return -y - z # (0, -1, -1) - same as 0x0B
end


"""
    interpolate_perlin(permutation_table, frac_x, frac_y, frac_z, int_x, int_y, int_z, smooth_x, smooth_y, smooth_z) -> Float64

Perform 3D Perlin noise interpolation using trilinear interpolation with smoothstep blending.

The algorithm:
1. Hash the 8 corners of the unit cube using the permutation table
2. Compute gradient vectors at each corner (derived from the hash)
3. Compute dot products between relative vectors and gradients
4. Interpolate using smoothstep (Hermite) curves along all three axes

# Arguments
- `permutation_table`: Permutation array (256 values + one repeat of value[0])
- `frac_x`, `frac_y`, `frac_z`: Fractional parts of coordinates ∈ [0,1]
- `int_x`, `int_y`, `int_z`: Integer grid cell coordinates ∈ [0,255]
- `smooth_x`, `smooth_y`, `smooth_z`: Smoothstep interpolation factors ∈ [0,1]

# Returns
Interpolated noise value (typically ∈ [-1, 1])

# Performance
This is a hot function (called ~52x per biome sample). Uses @inbounds for ~10% speedup.
"""
Base.@propagate_inbounds function interpolate_perlin(
        permutation_table::PermsType,
        frac_x, frac_y, frac_z,
        int_x, int_y, int_z,
        smooth_x, smooth_y, smooth_z,
    )
    @inbounds begin
        # Hash the grid cell coordinates using permutation table
        # This is a 3D hash function based on nested array lookups
        perm_x_base = permutation_table[int_x]
        perm_x_next = permutation_table[int_x + 1]

        perm_xy_base = permutation_table[perm_x_base + int_y]
        perm_xy_next = permutation_table[perm_x_next + int_y]
        perm_xy_base_below = permutation_table[perm_x_base + int_y + 1]
        perm_xy_next_below = permutation_table[perm_x_next + int_y + 1]

        # Gradients at the 8 corners of the cube
        grad_000 = permutation_table[perm_xy_base + int_z]
        grad_001 = permutation_table[perm_xy_next + int_z]
        grad_010 = permutation_table[perm_xy_base_below + int_z]
        grad_011 = permutation_table[perm_xy_next_below + int_z]
        grad_100 = permutation_table[perm_xy_base + int_z + 1]
        grad_101 = permutation_table[perm_xy_next + int_z + 1]
        grad_110 = permutation_table[perm_xy_base_below + int_z + 1]
        grad_111 = permutation_table[perm_xy_next_below + int_z + 1]

        # Compute influence of each corner (dot product with relative vector)
        inf_000 = indexed_lerp(grad_000, frac_x, frac_y, frac_z)
        inf_001 = indexed_lerp(grad_001, frac_x - 1, frac_y, frac_z)
        inf_010 = indexed_lerp(grad_010, frac_x, frac_y - 1, frac_z)
        inf_011 = indexed_lerp(grad_011, frac_x - 1, frac_y - 1, frac_z)
        inf_100 = indexed_lerp(grad_100, frac_x, frac_y, frac_z - 1)
        inf_101 = indexed_lerp(grad_101, frac_x - 1, frac_y, frac_z - 1)
        inf_110 = indexed_lerp(grad_110, frac_x, frac_y - 1, frac_z - 1)
        inf_111 = indexed_lerp(grad_111, frac_x - 1, frac_y - 1, frac_z - 1)
    end

    # Interpolate along X axis
    interp_00x = lerp(smooth_x, inf_000, inf_001)
    interp_10x = lerp(smooth_x, inf_010, inf_011)
    interp_01x = lerp(smooth_x, inf_100, inf_101)
    interp_11x = lerp(smooth_x, inf_110, inf_111)

    # Interpolate along Y axis
    interp_0xx = lerp(smooth_y, interp_00x, interp_10x)
    interp_1xx = lerp(smooth_y, interp_01x, interp_11x)

    # Interpolate along Z axis (final result)
    return lerp(smooth_z, interp_0xx, interp_1xx)
end


"""
    get_y_coord_values(noise, y)

Like [`init_coord_values`](@ref), but for the y coordinate. The difference is that if
`y` is `missing` (i.e. we are in 2d) it returns the constant y values of the noise.
"""
get_y_coord_values(noise, ::Missing) = noise.const_y, noise.const_index_y, noise.const_smooth_y
get_y_coord_values(noise, y) = init_coord_values(y + noise.y)

function adjust_y(y, yamp, ymin)
    yclamp = min(ymin, y)
    y -= floor(yclamp / yamp) * yamp
    return y
end
adjust_y(y, ::Missing, ::Missing) = y

# unsafe implementation
function _sample_noise(noise::Perlin, x::Real, z::Real, y, yamp, ymin)
    x, index_x, smooth_x = init_coord_values(x + noise.x)
    y, index_y, smooth_y = get_y_coord_values(noise, y)
    z, index_z, smooth_z = init_coord_values(z + noise.z)
    y = adjust_y(y, yamp, ymin)

    return interpolate_perlin(
        noise.permutations,
        x, y, z,
        index_x, index_y, index_z,
        smooth_x, smooth_y, smooth_z,
    )
end

# nothing to add if y is missing (2d implementation)
function sample_noise(noise::Perlin, x::Real, z::Real, y::Missing, yamp, ymin)
    return _sample_noise(noise, x, z, y, yamp, ymin)
end

# if y == 0, then y is set to missing
function sample_noise(noise::Perlin, x::Real, z::Real, y::Real, yamp, ymin)
    iszero(y) && return _sample_noise(noise, x, z, missing, yamp, ymin)
    return _sample_noise(noise, x, z, y, yamp, ymin)
end

# default without y
function sample_noise(noise::Perlin, x::Real, z::Real, yamp, ymin)
    return sample_noise(noise, x, z, missing, yamp, ymin)
end

# default without yamp ymin
function sample_noise(noise::Perlin, x::Real, z::Real, y = missing)
    return sample_noise(noise, x, z, y, missing, missing)
end
# TODO: sample_perlin_beta17_terrain(noise::Perlin, v, d1, d2, d3, yLacAmp)

#endregion
#region simplex
# ---------------------------------------------------------------------------- #
#          Simplex Noise (https://en.wikipedia.org/wiki/Simplex_noise)         #
# ---------------------------------------------------------------------------- #
"""
    simplex_gradient(idx, x, y, z, d)

Compute the gradient of the simplex noise at the given coordinates.

# Arguments
- `idx`: Index used for interpolation.
- `x`, `y`, `z`: Coordinates in the simplex grid.
- `d`: Constant used to determine the influence of the point in the grid.

See also: [`sample_simplex`](@ref)
"""
function simplex_gradient(idx, x, y, z, d)
    attenuation = d - (x^2 + y^2 + z^2)
    attenuation < zero(attenuation) && return zero(attenuation)
    attenuation *= attenuation
    return attenuation * attenuation * indexed_lerp(idx, x, y, z)
end

const SKEW::Float64 = (√3 - 1) / 2
const UNSKEW::Float64 = (3 - √3) / 6
# unskew = (1 - 1/√3)/2 on the wiki page. Its the same thing if we simplify it. But
# not the same for computer because of floating point precision.

# only used with a perlin created with JavaRandom
"""
    sample_simplex(noise::Perlin, x, y)

Sample the given noise at the given coordinate using the simplex noise
algorithm instead of the perlin one. See https://en.wikipedia.org/wiki/Simplex_noise

See also: [`sample_noise`](@ref), [`Perlin`](@ref)
"""
function sample_simplex(noise::Perlin, x, y, z = 0.0, scaling = 70, d = 0.5)
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
        simplex_gradient(gi0 % 12, x0, y0, z, d) +
        simplex_gradient(gi1 % 12, x1, y1, z, d) +
        simplex_gradient(gi2 % 12, x2, y2, z, d)

    return scaling * t
end
#endregion

# ---------------------------------------------------------------------------- #
#                                     Show                                     #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, p::Perlin)
    isundef(p) && return print(io, "Perlin(uninitialized)")

    print(io, "Perlin(")
    print(io, "x=", round(p.x; digits = 2), ", ")
    print(io, "y=", round(p.y; digits = 2), ", ")
    print(io, "z=", round(p.z; digits = 2), ", ")
    print(io, "const_y=", round(p.const_y; digits = 2), ", ")
    print(io, "const_index_y=", p.const_index_y, ", ")
    print(io, "const_smooth_y=", round(p.const_smooth_y; digits = 2), ", ")
    print(io, "amplitude=", round(p.amplitude; digits = 2), ", ")
    print(io, "lacunarity=", round(p.lacunarity; digits = 2), ", ")
    print(io, "permutations=")
    print(io, p.permutations)
    print(io, ")")
    return nothing
end

function Base.show(io::IO, mime::MIME"text/plain", p::Perlin)
    if isundef(p)
        println(io, "Perlin Noise (uninitialized)")
        return
    end
    #! format: off
    println(io, "Perlin Noise:")
    println(io, "├ Coordinates: (x=$(round(p.x, digits = 2)), y=$(round(p.y, digits = 2)), z=$(round(p.z, digits = 2)))")
    println(io, "├ Amplitude: $(p.amplitude)")
    println(io, "├ Lacunarity: $(p.lacunarity)")
    println(io, "├ Constant Y: y=$(round(p.const_y, digits = 4)), index=$(p.const_index_y), smooth=$(round(p.const_smooth_y, digits = 4))")

    # Show just the first few and last few permutation values
    perms = p.permutations
    perm_str = "[$(perms[0]), $(perms[1]), $(perms[2]), $(perms[3]), ..., $(perms[254]), $(perms[255]), $(perms[256])]"
    print(io, "└ Permutation table: $perm_str")
    return nothing
end
