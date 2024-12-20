using OffsetArrays: OffsetVector
using StaticArrays: MVector, SizedVector, @MVector, SizedArray

#TODO: replace the "sample" name to "sample_noise"
"""
    sample_noise(noise::PerlinNoise, x, y, z, yamp=0, ymin=0) -> Float64
    sample_noise(octaves::OctaveNoise, x, y, z) -> Float64
    sample_noise(octaves::OctaveNoise, x, y::Nothing, z, yamp, ymin) -> Float64
    sample_noise(octaves::OctaveNoise, x, y, z, yamp, ymin) -> Float64
    sample_noise(noise::DoublePerlinNoise, x, y, z) -> Float64

Sample the given noise / octaves at the given coordinates.

See also: [`sample_simplex`](@ref), [`PerlinNoise`](@ref), [`OctaveNoise`](@ref), [`DoublePerlinNoise`](@ref)

# Examples
```julia-repl
julia> rng = JavaRandom(1);
julia> noise = PerlinNoise🎲(rng);
julia> sample_noise(noise, 0, 0, 0)
0.10709059654197663
```
"""
function sample_noise end

#==========================================================================================#
# Specific rng for Perlin                                                                  #
#==========================================================================================#

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

#==========================================================================================#
#  Perlin Noise                                                                            #
#==========================================================================================#

# TODO: reduce garbage collection
PermsType = OffsetVector{UInt8,MVector{257,UInt8}}

Perms(::UndefInitializer) = OffsetVector(MVector{257,UInt8}(undef), 0:256)
@inline function init_perlin_noise_perm!(perms)
    for i in 0x0:0xFF
        perms[i] = i
    end
end

"""
    PerlinNoise
The type for the perlin noise. Use [`PerlinNoise🎲`](@ref) to create one given a random generator.
 See https://en.wikipedia.org/Perlin_Noise
to know how it works.

See also: [`sample_noise`](@ref), [`sample_simplex`](@ref), [`OctaveNoise`](@ref)
"""
mutable struct PerlinNoise
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

function PerlinNoise(::UndefInitializer)
    return PerlinNoise(
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

"""
    set_rng!🎲(rng::AbstractRNG_MC, perlin::PerlinNoise)

Set the random generator for the perlin noise. It will take random values from the rng so it
modify its state.
"""
function set_rng!🎲(rng::AbstractJavaRNG, perlin::PerlinNoise)
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
    PerlinNoise🎲(rng::AbstractRNG_MC)::PerlinNoise

Crate a PerlinNoise type, given a random generator `rng`. It takes
random values from the rng so it modify its state.
"""
function PerlinNoise🎲(rng::AbstractJavaRNG)
    perlin = PerlinNoise(undef)
    set_rng!🎲(rng, perlin)
    return perlin
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
    lower_4bits = idx & 0xF
    lower_4bits == 0 && return x + y
    lower_4bits == 1 && return -x + y
    lower_4bits == 2 && return x - y
    lower_4bits == 3 && return -x - y
    lower_4bits == 4 && return x + z
    lower_4bits == 5 && return -x + z
    lower_4bits == 6 && return x - z
    lower_4bits == 7 && return -x - z
    lower_4bits == 8 && return y + z
    lower_4bits == 9 && return -y + z
    lower_4bits == 10 && return y - z
    lower_4bits == 11 && return -y - z
    lower_4bits == 12 && return x + y
    lower_4bits == 13 && return -y + z
    lower_4bits == 14 && return -x + y
    lower_4bits == 15 && return -y - z

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

function sample_noise(noise::PerlinNoise, x, y, z, yamp=0, ymin=0)
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

function sample_perlin_beta17_terrain(noise::PerlinNoise, v, d1, d2, d3, yLacAmp)
    error("not implemented")
    return nothing
end

#==========================================================================================#
# Simplex Noise (https://en.wikipedia.org/wiki/Simplex_noise)
#==========================================================================================#

"""
    simplex_gradient(idx::Integer, x, y, z, d)

Compute the gradient of the simplex noise at the given coordinates.

See also: [`sample_simplex`](@ref)
"""
function simplex_gradient(idx::Integer, x, y, z, d)
    con = d - (x^2 + y^2 + z^2)
    con < zero(con) && return zero(typeof(con))
    con *= con
    return con * con * indexed_lerp(idx, x, y, z)
end

const SKEW::Float64 = (√3 - 1) / 2
const UNSKEW::Float64 = (3 - √3) / 6

"""
    sample_simplex(noise::PerlinNoise, x, y)

Sample the given noise at the given 2D coordinate using the simplex noise
algorithm instead of perlin noise. See https://en.wikipedia.org/wiki/Simplex_noise

See also: [`sample_noise`](@ref), [`PerlinNoise`](@ref)
"""
function sample_simplex(noise::PerlinNoise, x, y)
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
    @inbounds begin
        gi0 = p[(0xff & hz)]
        gi1 = p[(0xff & (hz + offz))]
        gi2 = p[(0xff & (hz + 1))]

        gi0 = p[(0xff & (gi0 + hx))]
        gi1 = p[(0xff & (gi1 + hx + offx))]
        gi2 = p[(0xff & (gi2 + hx + 1))]
    end
    t =
        simplex_gradient(gi0 % 12, x0, y0, 0.0, 0.5) +
        simplex_gradient(gi1 % 12, x1, y1, 0.0, 0.5) +
        simplex_gradient(gi2 % 12, x2, y2, 0.0, 0.5)

    return 70t
end

#==========================================================================================#
#                                 Octaves                                                  #
#==========================================================================================#

"""
    OctaveNoise{N}

A vector of `N` PerlinNoise objects representing the octaves of a noise. Use
[`OctaveNoise🎲`](@ref) or [`OctaveNoise!🎲`](@ref) to construct one.

See also: [`sample_noise`], [`PerlinNoise`](@ref), [`DoublePerlinNoise`](@ref)
"""
OctaveNoise{N} = SizedArray{Tuple{N},PerlinNoise,1,1,Vector{PerlinNoise}}

function OctaveNoise{N}(::UndefInitializer) where {N}
    return OctaveNoise{N}([PerlinNoise(undef) for _ in 1:N])
    # return OctaveNoise(Tuple(PerlinNoise(undef) for _ in 1:N))
    # @MVector [PerlinNoise(undef) for _ in 1:N]
end

"""
    OctaveNoise!🎲(rng::JavaRandom, octaves::OctaveNoise{N}, octave_min) -> Nothing where {N}
    OctaveNoise!🎲(rng::JavaXoroshiro128PlusPlus, octaves::OctaveNoise{N}, amplitudes::NTuple{N,Float64}, octave_min::Int) -> Nothing where {N}

Initialize the octaves using the `rng` generator. The condition `octave_min <= 1 - N`
**must** be respected.

# Parameters:
- `rng`: the random number generator to use.
- `octaves`: the N octaves to initialize
- `amplitudes`: for a `JavaXoroshiro128PlusPlus` generator, amplitudes values must also be specified.
- `octave_min`: the number of the first octave to generate. Must be <= 1 - N (so negative).

See also: [`PerlinNoise`](@ref), [`OctaveNoise`](@ref), [`sample_noise`](@ref)
"""
function OctaveNoise!🎲 end

"""
    OctaveNoise🎲(rng::JavaRandom, nb::Val{N}, octave_min) where {N}
    OctaveNoise🎲(rng::JavaXoroshiro128PlusPlus, amplitudes::NTuple{N,Float64}, octave_min) where {N}

Same as [`OctaveNoise!🎲`](@ref) but generate the octaves at the same time instead of modify
uninitialized ones inplace.

See also: [`OctaveNoise!🎲`](@ref)
"""
function OctaveNoise🎲 end

function OctaveNoise!🎲(rng::JavaRandom, octaves::OctaveNoise{N}, octave_min) where {N}
    end_ = octave_min + N - 1
    if N < 1 || end_ > 0
        throw(
            ArgumentError(
                lazy"we must have at least one octave and octave_min must be <= 1 - N"
            ),
        )
    end
    persistence = 1 / (2.0^N - 1)
    lacunarity = 2.0^end_

    if iszero(end_)
        oct = octaves[1]
        set_rng!🎲(rng, oct)
        oct.amplitude = persistence
        oct.lacunarity = lacunarity
        persistence *= 2
        lacunarity /= 2
        start = 2
    else
        randjump🎲(rng, Int32, -end_ * 262)
        start = 1
    end

    @inbounds for i in start:N
        oct = octaves[i]
        set_rng!🎲(rng, oct)
        oct.amplitude = persistence
        oct.lacunarity = lacunarity
        persistence *= 2
        lacunarity *= 0.5
    end
    return nothing
end

const MD5_OCTAVE_NOISE = Tuple(Tuple(md5_to_uint64("octave_$i")) for i in -12:0)
const LACUNARITY_INI = Tuple(@. 1 / 2^(1:12)) # -omin = 3:12
const PERSISTENCE_INI = Tuple(2^n / (2^(n + 1) - 1) for n in 0:8) # len = 4:9

function OctaveNoise!🎲(
    rng::JavaXoroshiro128PlusPlus,
    octaves::OctaveNoise{N},
    amplitudes::NTuple{N},
    octave_min,
    # TODO: the nmax parameter (see xOctaveInit in the original code)
) where {N}
    if N < 1 || (octave_min + N - 1) > 0
        throw(
            ArgumentError(
                lazy"we must have at least one octave and octave_min must be <= 1 - N"
            ),
        )
    end

    lacunarity = LACUNARITY_INI[-octave_min]
    persistence = PERSISTENCE_INI[N]
    xlo, xhi = next🎲(rng, UInt64), next🎲(rng, UInt64)

    for i in 1:N
        iszero(amplitudes[i]) && continue
        lo = xlo ⊻ MD5_OCTAVE_NOISE[12 + octave_min + i][1]
        hi = xhi ⊻ MD5_OCTAVE_NOISE[12 + octave_min + i][2]
        xoshiro = JavaXoroshiro128PlusPlus(lo, hi)
        perlin = PerlinNoise🎲(xoshiro)
        perlin.amplitude = amplitudes[i] * persistence
        perlin.lacunarity = lacunarity
        octaves[i] = perlin
        lacunarity *= 2
        persistence /= 2
    end
    return nothing
end

function OctaveNoise🎲(rng::JavaRandom, nb::Val{N}, octave_min) where {N}
    octaves = OctaveNoise{N}(undef)
    OctaveNoise!🎲(rng, octaves, octave_min)
    return octaves
end

function OctaveNoise🎲(
    rng::JavaXoroshiro128PlusPlus, amplitudes::NTuple{N,Float64}, octave_min
) where {N}
    octaves = OctaveNoise{N}(undef)
    OctaveNoise!🎲(rng, octaves, amplitudes, octave_min)
    return octaves
end

# TODO: OctaveNoiseBeta

# OctaveNoiseBeta = OctaveNoise

# function OctaveNoise_beta!🎲(
#     rng::JavaRandom,
#     octaves::OctaveNoise{N},
#     lacunarity,
#     lacunarity_multiplier,
#     persistence,
#     persistence_multiplier,
# ) where {N}
#     for i in 1:N
#         perlin = PerlinNoise🎲(rng)
#         perlin.amplitude = persistence
#         perlin.lacunarity = lacunarity
#         octaves[i] = perlin
#         persistence *= persistence_multiplier
#         lacunarity *= lacunarity_multiplier
#     end
#     return nothing
# end

# function OctaveNoiseBeta!🎲{N}(
#     rng::JavaRandom, lacunarity, lacunarity_multiplier, persistence, persistence_multiplier
# ) where {N}
#     octaves = OctaveNoise{N}(undef)
#     OctaveNoise_beta!🎲(
#         rng, octaves, lacunarity, lacunarity_multiplier, persistence, persistence_multiplier
#     )
#     return octaves
# end

# TODO: something to avoid repeated code
function sample_noise(
    octaves::OctaveNoise{N}, x, y::Nothing, z, yamp, ymin
)::Float64 where {N}
    v = zero(Float64)
    for perlin in octaves
        lf = perlin.lacunarity
        ax = x * lf
        ay = -perlin.y
        az = z * lf
        pv = sample_noise(perlin, ax, ay, az, yamp * lf, ymin * lf)
        v += pv * perlin.amplitude
    end
    return v
end

function sample_noise(octaves::OctaveNoise{N}, x, y, z, yamp, ymin)::Float64 where {N}
    v = zero(Float64)
    for perlin in octaves
        lf = perlin.lacunarity
        ax = x * lf
        ay = y * lf
        az = z * lf
        pv = sample_noise(perlin, ax, ay, az, yamp * lf, ymin * lf)
        v += pv * perlin.amplitude
    end
    return v
end

function sample_noise(octaves::OctaveNoise{N}, x, y, z)::Float64 where {N}
    v = zero(Float64)
    iszero(N) && return v
    for i in 1:N
        perlin = octaves[i]
        lf = perlin.lacunarity
        ax = x * lf
        ay = y * lf
        az = z * lf
        pv = sample_noise(perlin, ax, ay, az)
        v += pv * perlin.amplitude
    end
    return v
end

function sample_octave_beta17_biome()
    throw("not implemented")
    # TODO: implement
end

function sample_octave_beta17_terrain()
    throw("not implemented")
    # TODO: implement
end

#==========================================================================================#
#                               Double Perlin Noise                                        #
#==========================================================================================#

const AMPLITUDE_INI = Tuple(5 / 3 .* [N / (N + 1) for N in 1:9])

"""
    DoublePerlinNoise{N}

A noise that store two octaves. Use [`DoublePerlinNoise`](@ref) to create one, and initialize it
with [`set_rng!`](@ref). Or do both at the same time with [`DoublePerlinNoise🎲`](@ref).

# Fields
- `amplitude::Float64`: the amplitude that is common to each octave
- `octave_A::OctaveNoise{N}`: the first octave, of size N
- `octave_B::OctaveNoise{N}`: the second octave, of size N too.
"""
struct DoublePerlinNoise{N}
    amplitude::Float64
    octave_A::OctaveNoise{N}
    octave_B::OctaveNoise{N}
end

"""
    DoublePerlinNoise{N}(amplitude::Real, x::UndefInitializer) where {N}
    DoublePerlinNoise{N}(amplitudes, x::UndefInitializer) where {N}
    DoublePerlinNoise{N}(x::UndefInitializer) where {N}

Construct a DoublePerlinNoise object. Concerning the amplitude value, it can be passed directly or:
- If the random generator is a JavaRandom, it will be calculated automatically.
- If the random generator is a JavaXoroshiro128PlusPlus, it will be calculated automatically
  using the amplitudes values passed as the first argument instead of the amplitude.
"""
function DoublePerlinNoise end

"""
    set_rng!🎲(dp::DoublePerlinNoise, rng::AbstractJavaRNG, [amplitudes], octave_min)

Initialize the double perlin noise in place using the given random generator. Amplitudes values
are needed if the random generator is a JavaXoroshiro128PlusPlus.
"""
function set_rng!🎲 end

"""
    DoublePerlinNoise🎲(rng:JavaRandom, nb::Val{N}, octave_min)
    DoublePerlinNoise🎲(rng:JavaXoroshiro128PlusPlus, amplitudes::NTuple{N}, octave_min)


Construct a DoublePerlinNoise object and directly initialize the octaves using the given random
generator. Equivalent to:
```julia
>>> dp = DoublePerlinNoise{N}(undef)
>>> set_rng!(dp, rng, amplitudes, octave_min)
```
See also: [`DoublePerlinNoise`](@ref)
"""
function DoublePerlinNoise🎲 end

function set_rng!🎲(dp::DoublePerlinNoise, rng::AbstractJavaRNG, octave_min)
    OctaveNoise!🎲(rng, dp.octave_A, octave_min)
    OctaveNoise!🎲(rng, dp.octave_B, octave_min)
end
function set_rng!🎲(dp::DoublePerlinNoise, rng, amplitudes, octave_min)
    OctaveNoise!🎲(rng, dp.octave_A, amplitudes, octave_min)
    OctaveNoise!🎲(rng, dp.octave_B, amplitudes, octave_min)
end

function DoublePerlinNoise{N}(amplitude::Real, ::UndefInitializer) where {N}
    return DoublePerlinNoise(amplitude, OctaveNoise{N}(undef), OctaveNoise{N}(undef))
end

function DoublePerlinNoise{N}(amplitudes, x::UndefInitializer) where {N}
    # Xoroshiro128PlusPlus implementation
    len = length_of_trimmed(amplitudes, iszero)
    amplitude = AMPLITUDE_INI[len]
    return DoublePerlinNoise{N}(amplitude, x)
end

function DoublePerlinNoise{N}(x::UndefInitializer) where {N}
    # JavaRandom implementation
    amplitude = (10 / 6) * N / (N + 1)
    return DoublePerlinNoise{N}(amplitude, x)
end

function DoublePerlinNoise🎲(rng::JavaRandom, nb::Val{N}, octave_min) where {N}
    dp = DoublePerlinNoise{N}(undef)
    set_rng!🎲(dp, rng, octave_min)
    return dp
end

function DoublePerlinNoise🎲(
    rng::JavaXoroshiro128PlusPlus, amplitudes::NTuple{N}, octave_min
) where {N}
    dp = DoublePerlinNoise{N}(amplitudes, undef)
    set_rng!🎲(dp, rng, amplitudes, octave_min)
    return dp
end

function sample_noise(noise::DoublePerlinNoise, x, y, z, move_factor=337 / 331)
    f = move_factor
    v =
        sample_noise(noise.octave_A, x, y, z) +
        sample_noise(noise.octave_B, x * f, y * f, z * f)
    return v * noise.amplitude
end
