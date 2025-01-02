include("octaves.jl")

const MAX_AMPLITUDE = 9

# almost equal to (5/3 * x / (x + 1)) for x in 1:MAX_AMPLITUDE
# but with use rational numbers to avoid floating point errors
const AMPLITUDE_INI = float.(Tuple(5 // 3 * x // (x + 1) for x in 1:MAX_AMPLITUDE))


"""
    DoublePerlin{N} <: Noise

A double Perlin noise implementation. It's a sum of two independent and identically distributed
(iid) Octaves{N} noise.
"""
struct DoublePerlin{N} <: Noise
    amplitude::Float64
    octave_A::Octaves{N}
    octave_B::Octaves{N}
end

function DoublePerlin{N}(::UndefInitializer, amplitude::Real) where {N}
    return DoublePerlin{N}(amplitude, Octaves{N}(undef), Octaves{N}(undef))
end

function DoublePerlin{N}(x::UndefInitializer) where {N}
    # JavaRandom implementation
    amplitude = (10 / 6) * N / (N + 1)
    return DoublePerlin{N}(x, amplitude)
end

function DoublePerlin{N}(x::UndefInitializer, amplitudes) where {N}
    # Xoroshiro128PlusPlus implementation
    len = length_of_trimmed(iszero, amplitudes)
    return DoublePerlin{N}(x, AMPLITUDE_INI[len])
end

function DoublePerlin(x::UndefInitializer, amplitudes)
    # Xoroshiro128PlusPlus implementation
    N = length_filter(!iszero, amplitudes)
    return DoublePerlin{N}(x, amplitudes)
end

is_undef(x::DoublePerlin{N}) where {N} = is_undef(x.octave_A) || is_undef(x.octave_B)

function set_rng!🎲(noise::DoublePerlin, rng, args::Vararg{Any, N}) where {N}
    set_rng!🎲(noise.octave_A, rng, args...)
    set_rng!🎲(noise.octave_B, rng, args...)
end

function unsafe_set_rng!🎲(noise::DoublePerlin, rng, args::Vararg{Any, N}) where {N}
    unsafe_set_rng!🎲(noise.octave_A, rng, args...)
    unsafe_set_rng!🎲(noise.octave_B, rng, args...)
end

# we need to overload the default constructor here because we need to pass the amplitudes
# to the undefined initializer
function Noise🎲(
    ::Type{DoublePerlin{N}},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes,
    octave_min,
) where {N}
    dp = Noise(DoublePerlin{N}, undef, amplitudes) # here it's why we need to overload
    set_rng!🎲(dp, rng, amplitudes, octave_min)
    return dp
end

function sample_noise(noise::DoublePerlin, x, y, z, move_factor=337 / 331)
    f = move_factor
    v =
        sample_noise(noise.octave_A, x, y, z) +
        sample_noise(noise.octave_B, x * f, y * f, z * f)
    return v * noise.amplitude
end
