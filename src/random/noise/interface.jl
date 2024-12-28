include("../rng.jl")

abstract type Noise end

# to allow broadcasting over noise objects
# for example with the dot syntax sample_noise.(noise, X, Y, Z) where X, Y and Z are arrays
Base.broadcastable(noise::Noise) = Ref(noise)

function Base.:(==)(n1::Noise, n2::Noise)
    return all(getproperty(n1, x) == getproperty(n2, x) for x in propertynames(n1))
end

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
julia> sample_noise(noise, 0, 0, 0)
rng = JavaRandom(42);
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

julia> noise
set_rng!(noise, JavaRandom(1))
```
"""
Noise(::Type{T}, ::UndefInitializer, args::Vararg{Any, N}) where {T <: Noise, N} =
    T(undef, args...)

"""
    Noise🎲(::Type{T}, rng::AbstractJavaRNG, args...) where {N, T<:Noise}

Create a noise of type `T` and initialize it with the given random number generator `rng`.
`args` are used to initialize the noise. They depend on the noise type. They are the same as
the arguments of the `set_rng!` function.

Strictly equivalent to `noise = Noise(T, undef); set_rng!🎲(noise, rng, args...)`.

See also: [`Noise`](@ref), [`set_rng!🎲`](@ref)
"""
function Noise🎲(::Type{T}, rng::AbstractJavaRNG, args::Vararg{Any, N}) where {T <: Noise, N}
    noise = Noise(T, undef)
    set_rng!🎲(noise, rng, args...)
    return noise
end
