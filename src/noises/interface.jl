"""
    Noise

The abstract type for a Noise sampler.

# Methods
- [`sample_noise`](@ref)
- [`setrng!🎲`](@ref)
- `Noise(::Type{Noise}, ::UndefInitializer, ...)`
- [`Noise🎲`](@ref)

See also:  [`Perlin`](@ref), [`Octaves`](@ref), [`DoublePerlin`](@ref)
"""
abstract type Noise end

# to allow broadcasting over noise objects
# for example with the dot syntax sample_noise.(noise, X, Z, Y) where X, Z and Y are arrays
Base.broadcastable(noise::Noise) = Ref(noise)

function Base.:(==)(n1::Noise, n2::Noise)
    return all(getproperty(n1, x) == getproperty(n2, x) for x in propertynames(n1))
end

"""
    sample_noise(noise::Perlin, x, z, y=missing, yamp=0, ymin=0)
    sample_noise(noise::Octaves, x, z, y=missing, yamp=missing, ymin=missing)
    sample_noise(noise::DoublePerlin, x, z, y=missing, [move_factor,])

Sample the given noise at the specified coordinates.

See also: [`sample_simplex`](@ref), [`Noise`](@ref), [`Noise🎲`](@ref)
"""
function sample_noise end

function sample_noise(noise::Noise, coord::CartesianIndex, args::Vararg{Any, N}) where {N}
    return sample_noise(noise, coord.I..., args...)
end

"""
    setrng!🎲(noise::Perlin, rng)
    setrng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where N
    setrng!🎲(noise::Octaves{N}, rng::JavaXoroshiro128PlusPlus, amplitudes, octave_min) where N
    setrng!🎲(noise::DoublePerlin{N}, rng, octave_min) where N
    setrng!🎲(noise::DoublePerlin{N}, rng, amplitudes, octave_min) where N
`
Initialize the noise in place with the given random number generator (of type AbstractJavaRNG).

!!! warning
    `N` represents the number of octaves, each associated with a non-zero amplitude.
    Therefore, `N` **MUST** be equal to the number of non-zero values in amplitudes.
    This number can be obtained with `Cubiomes.length_filter(!iszero, amplitudes)`.
    For performance reasons, it is possible to lower `N` and completely ignore the last
    amplitudes using [`unsafe_setrng!🎲`](@ref).

!!! tip
    Since the last amplitudes are ignored if they are set to zero, replace the tuple of
    amplitudes with the trimmed version without the last zeros can save a very small amount
    of memory / time. However, only do this if the trimmed amplitudes are already known.
    Computing them only for this function call will not save any time.

See also: [`unsafe_setrng!🎲`](@ref), [`Noise`](@ref), [`Noise🎲`](@ref)
"""
function setrng!🎲 end

"""
    unsafe_setrng!🎲(noise, rng::JavaXoroshiro128PlusPlus, amplitudes, octave_min)

Same as [`setrng!🎲`](@ref) but allows to skip some octaves for performance reasons, i.e.
`N` can be less than the number of non-zero values in `amplitudes`, and the last octaves are
completely ignored. If instead `N` is greater, the behavior is undefined.

See also: [`setrng!🎲`](@ref), [`Noise`](@ref), [`Noise🎲`](@ref)
"""
function unsafe_setrng!🎲 end

"""
    Noise(::Type{T}, ::UndefInitializer) where {T<:Noise}
    Noise(::Type{DoublePerlin}; ::UndefInitializer, amplitudes)

Create a noise of type `T` with an undefined state, i.e., it is not initialized yet. Use
[`setrng!🎲`](@ref) or [`unsafe_setrng!🎲`](@ref) to initialize it.

See also: [`Noise🎲`](@ref), [`setrng!🎲`](@ref), [`unsafe_setrng!🎲`](@ref)
"""
Noise(::Type{T}, ::UndefInitializer, args::Vararg{Any, N}) where {T <: Noise, N} =
    T(undef, args...)

"""
    Noise🎲(::Type{T}, rng::AbstractJavaRNG, args...) where {N, T<:Noise}

Create a noise of type `T` and initialize it with the given random number generator `rng`.
Other arguments are used to initialize the noise. They depend on the noise type and they are
the same as the arguments of the [`setrng!🎲`](@ref) function.

Strictly equivalent to
```julia
julia> noise = Noise(T, undef) # or Noise(T, undef, args[1]) for DoublePerlin
T(...)

julia> setrng!🎲(noise, rng, args...)`.
```
See also: [`Noise`](@ref), [`setrng!🎲`](@ref)
"""
function Noise🎲(::Type{T}, rng::AbstractJavaRNG, args::Vararg{Any, N}) where {T <: Noise, N}
    noise = Noise(T, undef)
    setrng!🎲(noise, rng, args...)
    return noise
end