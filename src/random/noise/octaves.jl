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
        persistence, lacunarity = set_rng_octave!🎲(octaves[i], rng, persistence, lacunarity)
    end
    return nothing
end

_update_persistence_lacu(persistence, lacunarity) = persistence * 2, lacunarity / 2

function set_rng_octave!🎲(octave::Perlin, rng::JavaRandom, persistence::T, lacunarity, amp=one(T)) where {T}
    set_rng!🎲(octave, rng)
    octave.amplitude = persistence * amp
    octave.lacunarity = lacunarity
    return _update_persistence_lacu(persistence, lacunarity)
end

const MD5_OCTAVE_NOISE = Tuple(@. Tuple(md5_to_uint64("octave_" * string(-12:0))))
const LACUNARITY_INI = Tuple(@. 1 / 2^(0:12)) # -omin = 3:12
const PERSISTENCE_INI = Tuple(2^n / (2^(n + 1) - 1) for n in 0:8) # len = 4:9

function set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes,
    octave_min,
    nmax=Val(N),
) where {N}
    if N != length_filter(!iszero, amplitudes)
        throw(ArgumentError(lazy"the number of octaves must be equal to length_filter(!iszero, amplitudes). \
                                 Got $N != $length_filter(!iszero, amplitudes)."))
    end
    return unsafe_set_rng!🎲(octaves_type, rng, amplitudes, octave_min, nmax)
end

function unsafe_set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes,
    octave_min,
    nmax=Val(N),
) where {N}
    check_octave_min(N, octave_min)
    if !(0 <= -octave_min < length(LACUNARITY_INI))
        throw(ArgumentError(lazy"We must have 0 <= -octave_min < $(length(LACUNARITY_INI)). \
                                 Got octave_min=$octave_min"))
    end
    if !(N < length(PERSISTENCE_INI))
        throw(ArgumentError(lazy"We must have N < $(length(PERSISTENCE_INI)). \
                                 Got N=$N octaves"))
    end
    return _really_unsafe_set_rng!🎲(octaves_type, rng, amplitudes, octave_min, nmax)
end

function _really_unsafe_set_rng!🎲(
    octaves_type::Octaves{N},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes::NTuple{N_amp},
    octave_min,
    nmax::Val{N_max}=Val(N),
) where {N, N_amp, N_max}
    @inbounds lacunarity = LACUNARITY_INI[-octave_min + 1]
    @inbounds persistence = PERSISTENCE_INI[N_amp]
    xlo, xhi = next🎲(rng, UInt64), next🎲(rng, UInt64)
    octaves = octaves_type.octaves

    rng_temp = copy(rng)
    octave_counter = 1
    for (i, amp) in enumerate(amplitudes)
        # skip if amplitude is zero
        if iszero(amp)
            lacunarity, persistence = _update_persistence_lacu(persistence, lacunarity)
            continue
        end

        lo, hi = MD5_OCTAVE_NOISE[12 + octave_min + i]
        rng_temp.lo = xlo ⊻ lo
        rng_temp.hi = xhi ⊻ hi

        octave = octaves[octave_counter]
        lacunarity, persistence = set_rng_octave!🎲(octave, rng_temp, persistence, lacunarity, amp)

        octave_counter += 1
        if octave_counter > N_max
            break
        end
        lacunarity, persistence = _update_persistence_lacu(persistence, lacunarity)
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
        @show pv
        v += pv * perlin.amplitude
        @show perlin.amplitude
        @show v
    end
    return v
end

seed = 0x47e38685b75f2a1d
nb = 3
amp = (2.2948331015787096, 3.7393021733500995, 0.0, 2.2193150739468606)
octave_min = -3

rng = JavaXoroshiro128PlusPlus(seed)
noise = Octaves{nb}(undef)
set_rng!🎲(noise, rng, amp, octave_min)
println(noise.octaves[end])

# @code_warntype Noise🎲(Octaves{nb}, rng, amp, octave_min)
x = 33860.49100816767
y = 52.69376987529392
z = -70117.25276887477
sample_noise(noise, x, y, z)

# TODO: sample_octave_beta17_biome
# TODO: sample_octave_beta17_terrain
#endregion

function f(x)
    y = 3
    iter = ((y, i) for i in x if !iszero(i))
    for (y, i) in iter
        println(y)
        y *= 2
    end
end
