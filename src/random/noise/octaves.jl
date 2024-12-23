include("perlin.jl")

using StaticArrays: SizedArray
#region Octaves
# ---------------------------------------------------------------------------- #
#                                    Octaves                                   #
# ---------------------------------------------------------------------------- #

TypeInnerOctaves{N} = SizedArray{Tuple{N},Perlin,1,1,Vector{Perlin}}

"""
    Octaves{N}

An ordered collection of `N` Perlin objects representing the octaves of a noise.

See also: [`Noise`](@ref), [`sample_noise`], [`PerlinNoise`](@ref), [`DoublePerlinNoise`](@ref)
"""
struct Octaves{N} <: Noise
    octaves::TypeInnerOctaves{N}

    # default constructor
    Octaves{N}(x) where {N} = new(TypeInnerOctaves{N}(x))
end

function Octaves{N}(::UndefInitializer) where {N}
    Octaves{N}([Perlin(undef) for _ in 1:N])
end
is_undef(x::Octaves{N}) where {N} = any(is_undef, x.octaves)


function set_rng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where {N}
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
        lacunarity *= 0.5
    end
    return nothing
end

const MD5_OCTAVE_NOISE = Tuple(Tuple(md5_to_uint64("octave_$i")) for i in -12:0)
const LACUNARITY_INI = Tuple(@. 1 / 2^(1:12)) # -omin = 3:12
const PERSISTENCE_INI = Tuple(2^n / (2^(n + 1) - 1) for n in 0:8) # len = 4:9

function set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
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

function sample_octave_beta17_biome()
    throw("not implemented")
    # TODO: implement
end

function sample_octave_beta17_terrain()
    throw("not implemented")
    # TODO: implement
end

#endregion