using StaticArrays: SizedArray
using ..JavaRNG: JavaRandom, JavaXoroshiro128PlusPlus, next🎲, randjump🎲
using ..SeedUtils: SeedUtils
using ..Utils: Utils

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
        return new(TypeInnerOctaves{N}(x))
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
    return if octave_min > 1 - N
        throw(ArgumentError(lazy"we must have octave_min ≤ 1 - N. Got $octave_min > $(1- N)"))
    end
end
check_octave_min(octaves, octave_min) = check_octave_min(length(octaves), octave_min)

function setrng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where {N}
    check_octave_min(N, octave_min)
    end_ = octave_min + N - 1
    persistence = 1 / (2.0^N - 1)
    lacunarity = 2.0^end_
    octaves = noise.octaves

    if !iszero(end_)
        randjump🎲(rng, Int32, -end_ * 262)
    end

    @inbounds for i in 1:N
        setrng_octave!🎲(octaves[i], rng, persistence, lacunarity)
        persistence *= 2
        lacunarity /= 2
    end
    return nothing
end

function setrng_octave!🎲(
        octave::Perlin,
        rng,
        persistence::T,
        lacunarity,
        amp = one(T),
    ) where {T}
    setrng!🎲(octave, rng)
    octave.amplitude = persistence * amp
    octave.lacunarity = lacunarity
    return nothing
end

const MD5_OCTAVE_NOISE = Tuple(@. Tuple(SeedUtils.md5_to_uint64("octave_" * string(-12:0))))
const LACUNARITY_INI = Tuple(@. 1 / 2^(0:12)) # -omin = 3:12
const PERSISTENCE_INI = Tuple(2^n / (2^(n + 1) - 1) for n in 0:8) # len = 4:9

function setrng!🎲(
        octaves_type::Octaves,
        rng::JavaXoroshiro128PlusPlus,
        amplitudes::NTuple{NA},
        octave_min,
        real_length = NA,
    ) where {NA}
    if N != Utils.length_filter(!iszero, amplitudes)
        throw(ArgumentError(lazy"the number of octaves must be equal to length_filter(!iszero, amplitudes). \
                                 Got $N != $Utils.length_filter(!iszero, amplitudes)."))
    end
    return unsafe_setrng!🎲(octaves_type, rng, amplitudes, octave_min, real_length)
end

# In the ideal world, N is equal to the number of non-zero amplitudes
# but in the unsafe version, it can be less than the number of non-zero amplitudes
# it means that we skip some octaves, maybe for performance reasons
# if N is greater, undefined behavior can occur
function unsafe_setrng!🎲(
        octaves_type::Octaves{N},
        rng::JavaXoroshiro128PlusPlus,
        amplitudes::NTuple{N2},
        octave_min,
        real_length = N2,
    ) where {N, N2}
    # Initialize lacunarity and persistence based on octave_min and amplitudes length
    lacunarity = LACUNARITY_INI[-octave_min + 1]
    persistence = PERSISTENCE_INI[real_length]
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
            setrng_octave!🎲(octave, rng_temp, persistence, lacunarity, amp)

            # Move to the next octave
            octave_counter == N && break
            octave_counter += 1
        end
        lacunarity *= 2
        persistence /= 2
    end
    return nothing
end

# TODO: OctaveNoiseBeta

# We need to do the difference between y = missing and y = nothing
# y = missing is used in sample_noise of each octave
# missing propagats to every operation, for example, y * lf = missing is y = missing

# if y = nothing, it is used in sample_octave_noise to get ay.
# it is not intended to be set by the user, it is automatically set when calling
# sample_noise(octaves, x, z, yamp, ymin) without specifying y but with yamp and ymin
# it's here and only here that y=nothing is used

get_ay(y, perlin, lf) = y * lf
get_ay(y::Nothing, perlin, lf) = -perlin.y

function sample_octave_noise(octave::Perlin, x, z, y, yamp, ymin)
    lf = octave.lacunarity
    ax = x * lf
    ay = get_ay(y, octave, lf)
    az = z * lf
    return sample_noise(octave, ax, az, ay, yamp * lf, ymin * lf) *
        octave.amplitude
end

function sample_noise(octaves::Octaves, x::Real, z::Real, y, yamp, ymin)
    v = zero(Float64)
    for octave in octaves.octaves
        v += sample_octave_noise(octave, x, z, y, yamp, ymin)
    end
    return v
end

function sample_noise(octaves::Octaves, x::Real, z::Real, y = missing)
    return sample_noise(octaves, x, z, y, missing, missing)
end

function sample_noise(octaves::Octaves, x::Real, z::Real, yamp::Real, ymin::Real)
    return sample_noise(octaves, x, z, nothing, yamp, ymin)
end

# TODO: sample_octave_beta17_biome
# TODO: sample_octave_beta17_terrain


# ---------------------------------------------------------------------------- #
#                                     Show                                     #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, o::Octaves{N}) where {N}
    is_undef(o) && return print(io, "Octaves{$N}(uninitialized)")

    print(io, "Octaves{$N}(")
    for (i, octave) in enumerate(o.octaves)
        i > 1 && print(io, ", ")
        amp = round(octave.amplitude; digits = 2)
        lac = round(octave.lacunarity; digits = 2)
        print(io, "a=$(amp),l=$(lac)")
    end
    return print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", o::Octaves{N}) where {N}
    if is_undef(o)
        println(io, "Perlin Noise Octaves{$N} (uninitialized)")
        return
    end

    println(io, "Perlin Noise Octaves{$N}:")

    # Calculate the total amplitude (normalization factor)
    total_amplitude = sum(octave.amplitude for octave in o.octaves)
    println(io, "├ Total amplitude: $(round(total_amplitude; digits = 4))")

    # Show individual octaves
    oct_str = []
    for (i, octave) in enumerate(o.octaves)
        if i < length(o.octaves)
            prefix = "├"
        else
            prefix = "└"
        end
        amp = round(octave.amplitude; digits = 4)
        lac = round(octave.lacunarity; digits = 4)
        weight = round(100 * octave.amplitude / total_amplitude; digits = 1)
        push!(oct_str, "$prefix Octave $i: amplitude=$(amp) ($(weight)%), lacunarity=$(lac)")
    end
    return print(io, join(oct_str, "\n"))
end
