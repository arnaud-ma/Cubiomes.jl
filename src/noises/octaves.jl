using StaticArrays: SizedArray
using ..JavaRNG: JavaRandom, JavaXoroshiro128PlusPlus, next🎲, randjump🎲
import ..Utils

TypeInnerOctaves{N} = SizedArray{Tuple{N}, Perlin, 1, 1, Vector{Perlin}}

"""
    Octaves{N} <: Noise

An ordered collection of `N` Perlin objects representing the octaves of a noise.

See also: [`Noise`](@ref), [`sample_noise`], [`Perlin`](@ref), [`DoublePerlin`](@ref)
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

function check_octave_min(N::Int, octave_min)
    if octave_min > 1 - N
        throw(ArgumentError(lazy"we must have octave_min ≤ 1 - N. Got $octave_min > $(1- N)"))
    end
end
check_octave_min(octaves, octave_min) = check_octave_min(length(octaves), octave_min)

function set_rng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where {N}
    check_octave_min(N, octave_min)
    end_ = octave_min + N - 1
    persistence = 1 / (2.0^N - 1)
    lacunarity = 2.0^end_
    octaves = noise.octaves

    if !iszero(end_)
        randjump🎲(rng, Int32, -end_ * 262)
    end

    @inbounds for i in 1:N
        set_rng_octave!🎲(octaves[i], rng, persistence, lacunarity)
        persistence *= 2
        lacunarity /= 2
    end
    return nothing
end

function set_rng_octave!🎲(
    octave::Perlin,
    rng,
    persistence::T,
    lacunarity,
    amp=one(T),
) where {T}
    set_rng!🎲(octave, rng)
    octave.amplitude = persistence * amp
    octave.lacunarity = lacunarity
    return nothing
end

const MD5_OCTAVE_NOISE = Tuple(@. Tuple(Utils.md5_to_uint64("octave_" * string(-12:0))))
const LACUNARITY_INI = Tuple(@. 1 / 2^(0:12)) # -omin = 3:12
const PERSISTENCE_INI = Tuple(2^n / (2^(n + 1) - 1) for n in 0:8) # len = 4:9

function set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes,
    octave_min,
) where {N}
    if N != Utils.length_filter(!iszero, amplitudes)
        throw(ArgumentError(lazy"the number of octaves must be equal to length_filter(!iszero, amplitudes). \
                                 Got $N != $Utils.length_filter(!iszero, amplitudes)."))
    end
    return unsafe_set_rng!🎲(octaves_type, rng, amplitudes, octave_min)
end

# In the ideal world, N is equal to the number of non-zero amplitudes
# but in the unsafe version, it can be less than the number of non-zero amplitudes
# it means that we skip some octaves, maybe for performance reasons
# if N is greater, undefined behavior can occur
function unsafe_set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes,
    octave_min,
) where {N}
    # Initialize lacunarity and persistence based on octave_min and amplitudes length
    lacunarity = LACUNARITY_INI[-octave_min + 1]
    persistence = PERSISTENCE_INI[length(amplitudes)]
    xlo, xhi = next🎲(rng, UInt64), next🎲(rng, UInt64)

    # Initialize a temporary RNG state and the iterator over octaves
    rng_temp = typeof(rng)(xlo, xhi)
    octaves = octaves_type.octaves
    octave_counter = 1

    # Iterate over amplitudes and set RNG for each octave
    for (i, amp) in zip(Iterators.countfrom(1), amplitudes)
        # Skip if amplitude is zero
        if !iszero(amp)
            # Update RNG state with MD5 noise values
            lo, hi = MD5_OCTAVE_NOISE[12 + octave_min + i]
            rng_temp.lo = xlo ⊻ lo
            rng_temp.hi = xhi ⊻ hi

            # Set RNG for the current octave
            # nb of octaves are always >= 1 so we can safely use @inbounds
            @inbounds octave = octaves[octave_counter]
            set_rng_octave!🎲(octave, rng_temp, persistence, lacunarity, amp)

            # Move to the next octave
            if octave_counter == N
                break
            end
            octave_counter += 1
        end
        lacunarity *= 2
        persistence /= 2
    end
    return nothing
end

# TODO: OctaveNoiseBeta

get_ay(y, perlin, lf) = y * lf
get_ay(y::Missing, perlin, lf) = -perlin.y

function sample_octave_noise(octave::Perlin, x, z, y=missing, yamp=missing, ymin=missing)
    lf = octave.lacunarity
    ax = x * lf
    ay = get_ay(y, octave, lf)
    az = z * lf
    return sample_noise(octave, ax, az, ay, yamp * lf, ymin * lf) * octave.amplitude
end

function sample_noise(
    octaves::Octaves{N},
    x::Real,
    z::Real,
    y=missing,
    yamp=missing,
    ymin=missing,
) where {N}
    v = zero(Float64)
    for octave in octaves.octaves
        v += sample_octave_noise(octave, x, z, y, yamp, ymin)
    end
    return v
end

# TODO: sample_octave_beta17_biome
# TODO: sample_octave_beta17_terrain
