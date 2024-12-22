include("../rng.jl")

abstract type Noise end

# to allow broadcasting over noise objects
# for example with the dot syntax sample_noise.(noise, X, Y, Z) where X, Y and Z are arrays
Base.broadcastable(noise::Noise) = Ref(noise)

"""
    sample_noise(noise::Perlin, x, y, z, yamp=0, ymin=0) -> Float64
    sample_noise(noise::Octaves, x, y, z) -> Float64
    sample_noise(noise::Octaves, x, y::Nothing, z, yamp, ymin) -> Float64
    sample_noise(noise::Octaves, x, y, z, yamp, ymin) -> Float64
    sample_noise(noise::DoublePerlin, x, y, z) -> Float64

Sample the given noise at the given coordinates.

See also: [`sample_simplex`](@ref), [`Perlin`](@ref), [`Octaves`](@ref), [`DoublePerlin`](@ref)

# Examples
```julia-repl
julia> rng = JavaRandom(42);
julia> noise = Noise🎲(PerlinNoise, rng);
julia> sample_noise(noise, 0, 0, 0)
0.07034195718122443
```
"""
function sample_noise end
"""
    set_rng!🎲(noise::Perlin, rng)
    set_rng!🎲(noise::Octaves, rng::JavaRandom, octave_min)
    set_rng!🎲(noise::Octaves, rng::JavaXoroshiro128PlusPlus, amplitudes::Tuple, octave_min)
    set_rng!🎲(noise::DoublePerlin, rng, octave_min)
    set_rng!🎲(noise::DoublePerlin, rng, amplitudes::Tuple, octave_min)

Initialize the noise in place with the given random number generator (of type AbstractJavaRNG).
"""
function set_rng!🎲 end

"""
    Noise(noise_type::Type{T}, ::UndefInitializer) where {T<:Noise}

Create a noise of type `T` with an undefined state, i.e. it is not initialized yet. Use
[`set_rng!`](@ref) to initialize it.

See also: [`Noise`](@ref), [`set_rng!🎲`](@ref)


# Examples
```julia-repl
julia> noise = Noise(PerlinNoise, undef)
PerlinNoise(UInt8[...], NaN, NaN, NaN, NaN, 0x00, NaN, NaN, NaN)
julia> set_rng!(noise, JavaRandom(1))
julia> noise
PerlinNoise(UInt8[...], 186.25630208841423, 174.90520877052043, 79.0321805651609, 0.9052087705204315, 0xae, 0.9926477865806907, 1.0, 1.0)
```
"""
function Noise(::Type{T}, ::UndefInitializer, args...) where {T<:Noise}
    return T(undef, args...)
end

"""
    Noise🎲(::Type{T}, rng::AbstractJavaRNG, args...) where {N, T<:Noise}

Create a noise of type `T` and initialize it with the given random number generator `rng`.
`args` are used to initialize the noise. They depend on the noise type. They are the same as
the arguments of the `set_rng!` function.

Strictly equivalent to `noise = Noise(T, undef); set_rng!🎲(noise, rng, args...)`.

See also: [`Noise`](@ref), [`set_rng!🎲`](@ref)
"""
function Noise🎲(::Type{T}, rng::AbstractJavaRNG, args...) where {T<:Noise}
    noise = Noise(T, undef)
    set_rng!🎲(noise, rng, args...)
    return noise
end

