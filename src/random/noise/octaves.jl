include("perlin.jl")

using StaticArrays: SizedArray
#region Octaves
# ---------------------------------------------------------------------------- #
#                                    Octaves                                   #
# ---------------------------------------------------------------------------- #

TypeInnerOctaves{N} = SizedArray{Tuple{N}, Perlin, 1, 1, Vector{Perlin}}

"""
    Octaves{N}

An ordered collection of `N` Perlin objects representing the octaves of a noise.

See also: [`Noise`](@ref), [`sample_noise`], [`PerlinNoise`](@ref), [`DoublePerlinNoise`](@ref)
"""
struct Octaves{N} <: Noise
    octaves::TypeInnerOctaves{N}

    # default constructor
    function Octaves{N}(x) where {N}
        N < 1 && throw(ArgumentError(lazy"We need at least one octave. Got $N"))
        new(TypeInnerOctaves{N}(x))
    end
end
Base.length(::Octaves{N}) where {N} = N

function Base.:(==)(o1::Octaves, o2::Octaves)
    length(o1) != length(o2) && return false
    return all(p1 == p2 for (p1, p2) in zip(o1.octaves, o2.octaves))
end

Octaves{N}(::UndefInitializer) where {N} = Octaves{N}([Perlin(undef) for _ in 1:N])
is_undef(x::Octaves{N}) where {N} = any(is_undef, x.octaves)

function check_octave_min(N, octave_min)
    if octave_min > 1 - N
        throw(ArgumentError(lazy"we must have octave_min ≤ 1 - N. Got $octave_min > $(1- N)"))
    end
end

function set_rng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where {N}
    check_octave_min(N, octave_min)
    end_ = octave_min + N - 1
    persistence = 1 / (2.0^N - 1)
    lacunarity = 2.0^end_
    octaves = noise.octaves

    if iszero(end_)
        octave = octaves[1]
        set_rng!🎲(octave, rng)
        octave.amplitude = persistence
        octave.lacunarity = lacunarity
        persistence *= 2
        lacunarity /= 2
        start = 2
    else
        randjump🎲(rng, Int32, -end_ * 262)
        start = 1
    end

    @inbounds for i in start:N
        octave = octaves[i]
        set_rng!🎲(octave, rng)
        octave.amplitude = persistence
        octave.lacunarity = lacunarity
        persistence *= 2
        lacunarity /= 2
    end
    return nothing
end

const MD5_OCTAVE_NOISE = Tuple(Tuple(md5_to_uint64("octave_$i")) for i in -12:0)
const LACUNARITY_INI = Tuple(@. 1 / 2^(0:12)) # -omin = 3:12
const PERSISTENCE_INI = (0, (2^n / (2^(n + 1) - 1) for n in 0:8)...) # len = 4:9

function set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes::NTuple{N},
    octave_min,
    # TODO: the nmax parameter (see xOctaveInit in the original code)
) where {N}
    check_octave_min(N, octave_min)
    lacunarity = LACUNARITY_INI[-octave_min + 1]
    persistence = PERSISTENCE_INI[N]
    xlo, xhi = next🎲(rng, UInt64), next🎲(rng, UInt64)
    octaves = octaves_type.octaves
    for i in 1:N
        amp = amplitudes[i]
        iszero(amp) && continue
        lo, hi = MD5_OCTAVE_NOISE[12 + octave_min + i]
        lo ⊻= xlo
        hi ⊻= xhi
        xoshiro = JavaXoroshiro128PlusPlus(lo, hi)
        perlin = Noise🎲(Perlin, xoshiro)
        perlin.amplitude = amp * persistence
        perlin.lacunarity = lacunarity
        octaves[i] = perlin
        lacunarity *= 2
        persistence /= 2
    end
    return nothing
end

# TODO: OctaveNoiseBeta

get_ay(y::Nothing, perlin, lf) = -perlin.y
get_ay(y, perlin, lf) = y * lf

function sample_noise(octaves::Octaves{N}, x, y, z, yamp=missing, ymin=missing) where {N}
    v = zero(Float64)
    for perlin in octaves.octaves
        lf = perlin.lacunarity
        ax = x * lf
        ay = get_ay(y, perlin, lf)
        az = z * lf
        pv = sample_noise(perlin, ax, ay, az, yamp * lf, ymin * lf)
        v += pv * perlin.amplitude
    end
    return v
end

# TODO: sample_octave_beta17_biome
# TODO: sample_octave_beta17_terrain
#endregion
