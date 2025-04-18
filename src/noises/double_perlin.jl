import ..Utils

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

function undef_double_perlin(len_amp, ::Val{N}) where {N}
    return DoublePerlin{N}(undef, AMPLITUDE_INI[len_amp])
end

function DoublePerlin{N}(
        ::UndefInitializer,
        amplitudes,
        already_trimmed::Val{true},
    ) where {N}
    # Xoroshiro128PlusPlus implementation
    return undef_double_perlin(length(amplitudes), Val(N))
end

function DoublePerlin{N}(
        ::UndefInitializer,
        amplitudes,
        already_trimmed::Val{false},
    ) where {N}
    # Xoroshiro128PlusPlus implementation
    return undef_double_perlin(Utils.length_of_trimmed(iszero, amplitudes), Val(N))
end

function DoublePerlin{N}(x::UndefInitializer, amplitudes) where {N}
    return DoublePerlin{N}(x, amplitudes, Val(false))
end

function DoublePerlin(x::UndefInitializer, amplitudes)
    # Xoroshiro128PlusPlus implementation
    N = Utils.length_filter(!iszero, amplitudes)
    return DoublePerlin{N}(x, amplitudes)
end

is_undef(x::DoublePerlin{N}) where {N} = is_undef(x.octave_A) || is_undef(x.octave_B)

function set_rng!🎲(noise::DoublePerlin, rng, args::Vararg{Any, N}) where {N}
    set_rng!🎲(noise.octave_A, rng, args...)
    return set_rng!🎲(noise.octave_B, rng, args...)
end

function unsafe_set_rng!🎲(noise::DoublePerlin, rng, args::Vararg{Any, N}) where {N}
    unsafe_set_rng!🎲(noise.octave_A, rng, args...)
    return unsafe_set_rng!🎲(noise.octave_B, rng, args...)
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

const MOVE_FACTOR = 337 / 331

function sample_noise(noise::DoublePerlin, x::Real, z::Real, y = missing)
    f = MOVE_FACTOR
    v =
        sample_noise(noise.octave_A, x, z, y) +
        sample_noise(noise.octave_B, x * f, z * f, y * f)
    return v * noise.amplitude
end

# ---------------------------------------------------------------------------- #
#                                     Show                                     #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, dp::DoublePerlin{N}) where {N}
    is_undef(dp) && return print(io, "DoublePerlin{$N}(uninitialized)")

    print(io, "DoublePerlin{$N}(")
    print(io, "amplitude=", round(dp.amplitude; digits = 2))
    return print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", dp::DoublePerlin{N}) where {N}
    if is_undef(dp)
        println(io, "Double Perlin Noise{$N} (uninitialized)")
        return
    end

    println(io, "Double Perlin Noise{$N}:")
    println(io, "├ Global amplitude: $(round(dp.amplitude; digits = 4))")
    println(io, "├ Move factor: $(round(MOVE_FACTOR; digits = 4))")

    # Display first octave group
    println(io, "├ Octave Group A:")
    octave_a_lines = split(repr(mime, dp.octave_A), '\n')
    for (i, line) in enumerate(octave_a_lines)
        if i == 1
            continue  # Skip the first line which is the title
        else
            println(io, "│ $(line)")
        end
    end

    # Display second octave group
    println(io, "└ Octave Group B:")
    octave_b_lines = split(repr(mime, dp.octave_B), '\n')

    for (i, line) in enumerate(octave_b_lines)
        if i == 1
            continue  # Skip the first line which is the title
        elseif i == length(octave_b_lines)
            print(io, "  $(line)") # no new line at the end
        else
            println(io, "  $(line)")
        end
    end
    return
end
