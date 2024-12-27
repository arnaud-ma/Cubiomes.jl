include("octaves.jl")

# ---------------------------------------------------------------------------- #
#                              Double Perlin Noise                             #
# ---------------------------------------------------------------------------- #

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
struct DoublePerlin{N} <: Noise
    amplitude::Float64
    octave_A::Octaves{N}
    octave_B::Octaves{N}
end

function DoublePerlin{N}(::UndefInitializer, amplitude::Real) where {N}
    return DoublePerlin{N}(amplitude, Octaves{N}(undef), Octaves{N}(undef))
end

function DoublePerlin{N}(x::UndefInitializer, len::Integer) where {N}
    # Xoroshiro128PlusPlus implementation
    # Optimization: len must always be equal to length_of_trimmed(amplitudes, iszero)
    # but we can pass it directly
    amplitude = AMPLITUDE_INI[len]
    return DoublePerlin{N}(x, amplitude)
end

function DoublePerlin{N}(x::UndefInitializer, amplitudes) where {N}
    return DoublePerlin{N}(x, length_of_trimmed(amplitudes, iszero))
end

function DoublePerlin{N}(x::UndefInitializer) where {N}
    # JavaRandom implementation
    amplitude = (10 / 6) * N / (N + 1)
    return DoublePerlin{N}(amplitude, x)
end

is_undef(x::DoublePerlin{N}) where {N} = is_undef(x.octave_A) || is_undef(x.octave_B)

function set_rng!🎲(dp::DoublePerlin, rng::AbstractJavaRNG, octave_min)
    set_rng!🎲(dp.octave_A, rng, octave_min)
    set_rng!🎲(dp.octave_B, rng, octave_min)
end
function set_rng!🎲(dp::DoublePerlin, rng, amplitudes, octave_min)
    set_rng!🎲(dp.octave_A, rng, amplitudes, octave_min)
    set_rng!🎲(dp.octave_B, rng, amplitudes, octave_min)
end

# we need to overload the default constructor here because we need to pass the amplitudes
# to the undefined initializer
function Noise🎲(
    ::Type{DoublePerlin{N}},
    rng::JavaXoroshiro128PlusPlus,
    amplitudes_or_len,
    octave_min,
) where {N}
    dp = DoublePerlin{N}(undef, amplitudes_or_len) # here it's why we need to overload
    set_rng!🎲(dp, rng, amplitudes_or_len, octave_min)
    return dp
end

function sample_noise(noise::DoublePerlin, x, y, z, move_factor=337 / 331)
    f = move_factor
    v =
        sample_noise(noise.octave_A, x, y, z) +
        sample_noise(noise.octave_B, x * f, y * f, z * f)
    return v * noise.amplitude
end
