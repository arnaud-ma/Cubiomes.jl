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

# amplitude can be in fact any real number, but we restrain to a float
# to really make the difference with the method with len::Integer
function DoublePerlin{N}(::UndefInitializer, amplitude::AbstractFloat) where {N}
    return DoublePerlin{N}(amplitude, Octaves{N}(undef), Octaves{N}(undef))
end

function DoublePerlin{N}(x::UndefInitializer) where {N}
    # JavaRandom implementation
    amplitude = (10 / 6) * N / (N + 1)
    return DoublePerlin{N}(x, amplitude)
end

function DoublePerlin{N}(x::UndefInitializer, len::Integer) where {N}
    # Xoroshiro128PlusPlus implementation
    # Optimization: len must always be equal to length_of_trimmed(iszero, amplitudes)
    # but we can pass it directly
    return DoublePerlin{N}(x, AMPLITUDE_INI[len])
end

function DoublePerlin{N}(x::UndefInitializer, amplitudes) where {N}
    # the non-optimized version, if we do not already know length_of_trimmed(iszero, amplitudes)
    return DoublePerlin{N}(x, length_of_trimmed(iszero, amplitudes))
end

is_undef(x::DoublePerlin{N}) where {N} = is_undef(x.octave_A) || is_undef(x.octave_B)

function set_rng!🎲(noise::DoublePerlin, rng, args::Vararg{Any, N}) where {N}
    set_rng!🎲(noise.octave_A, rng, args...)
    set_rng!🎲(noise.octave_B, rng, args...)
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

# seed = 0xb8cfde1c2decb7a3;
# rng = JavaXoroshiro128PlusPlus(seed)
# nb = 7;
# omin = -10;
# amplitudes = (0.0, 3.759029398181129, 0.6857347567864969, 1.0, 0.0, 8.4830289242609399, 0.0);
# noise = Noise🎲(DoublePerlin{nb}, rng, amplitudes, omin)

# open("a.txt", "w") do io
#     print(io, noise)
# end
# x = 33860.49100816767;
# y = 52.69376987529392;
# z = -70117.25276887477;
# sample_noise(noise, x, y, z)
