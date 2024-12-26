include("../utils.jl")

#=============================================================================#
# Interface for Java RNGs                                                     #
#=============================================================================#

abstract type AbstractJavaRNG end

"""
    next🎲(rng::AbstractJavaRNG, ::Type{T}) where T
    next🎲(rng::AbstractJavaRNG, ::Type{T}, stop) where T
    next🎲(rng::AbstractJavaRNG, ::Type{T}, start, stop) where T

Generate a random number of type `T` from the given random number generator. If `start` and `stop`
are provided, the random number will be in the range `[start, stop]`. `start` is default to `0`.
"""
next🎲(rng::T, type) where {T <: AbstractJavaRNG} = throw(MethodError(next🎲, (T, type)))

"""
    randjump🎲(rng::AbstractJavaRNG, ::Type{T}, n::Integer) where T

Jump the state of the random number generator `n` steps forward, without generating
any random numbers.
"""
function randjump🎲(rng::T, type, n::Integer) where {T <: AbstractJavaRNG}
    throw(MethodError(randjump🎲, (T, type, n)))
end

"""
    set_seed!(rng::AbstractJavaRNG, seed) -> AbstractJavaRNG

Initialize the rng with the given seed. Return the rng itself for convenience.
"""
set_seed!(rng::AbstractJavaRNG, seed, args...) = set_seed!(rng, u64_seed(seed), args...)

next🎲(rng::AbstractJavaRNG, ::Type{T}, stop::Real)::T where {T} = next🎲(rng, T) * stop

function next🎲(rng::AbstractJavaRNG, ::Type{T}, start::Real, stop::Real)::T where {T}
    return next🎲(rng, T, stop - start) + start
end

function next🎲(rng::AbstractJavaRNG, ::Type{T}, range::AbstractRange) where {T}
    return next🎲(rng, T, first(range), last(range))
end

#=============================================================================#
# Implementation of Java Random                                               #
#=============================================================================#

const MAGIC_JAVA_INT32::UInt64 = 0x5DEECE66D
const MAGIC_JAVA_ADDEND::UInt64 = 0xB

_new_seed(seed::UInt64) = (seed ⊻ MAGIC_JAVA_INT32) & ((1 << 48) - 1)
_new_seed(seed) = _new_seed(u64_seed(seed))

"""
    JavaRandom(seed::Integer)

A pseudorandom number generator that mimics the behavior of Java's
[`java.util.Random`](https://docs.oracle.com/javase/7/docs/api/java/util/Random.html) class.

# Examples

```jldoctest
julia> rng = JavaRandom(1234);
JavaRandom(0x00000005deece2bf)

julia> next_int32_range!(rng, 10)
3
```
"""
mutable struct JavaRandom <: AbstractJavaRNG
    seed::UInt64
    # https://docs.oracle.com/javase/7/docs/api/java/util/Random.html#setSeed(long)
    JavaRandom(seed) = new(_new_seed(seed))
end

function Base.copy!(dst::JavaRandom, src::JavaRandom)
    dst.seed = src.seed
    return dst
end
Base.copy(rng::JavaRandom) = copy!(JavaRandom(0), rng)
Base.:(==)(a::JavaRandom, b::JavaRandom) = a.seed == b.seed

function set_seed!(rng::JavaRandom, seed::UInt64)
    rng.seed = _new_seed(seed)
    return rng
end

# Java's next method
function next🎲(rng::JavaRandom, bits::Int32)::Int32
    rng.seed = (rng.seed * MAGIC_JAVA_INT32 + MAGIC_JAVA_ADDEND) & ((1 << 48) - 1)
    result = rng.seed >> (48 - bits)
    return signed(UInt32(result))
end
next🎲(rng::JavaRandom, bits::Integer) = next🎲(rng, Int32(bits))

# Java's nextInt method
function next🎲(rng::JavaRandom, ::Type{Int32}, stop::Integer)::Int32
    m = Int32(stop)
    stop = m + one(Int32)  # to include n in the range (difference of perspective between Java and Julia)

    if iszero(stop & m) # i.e., n is a power of 2
        return (stop * Int64(next🎲(rng, 31))) >> 31
    end

    val = zero(Int32)
    while true
        bits = next🎲(rng, 31)
        val = bits % stop
        (bits - val + m < 0) || break
    end
    return val
end

# Java's nextLong method
next🎲(rng::JavaRandom, ::Type{Int64}) = (Int64(next🎲(rng, 32)) << 32) + next🎲(rng, 32)
# Java's nextFloat method
next🎲(rng::JavaRandom, ::Type{Float32}) = next🎲(rng, 24) / Float32(1 << 24)
# Java's nextDouble method
function next🎲(rng::JavaRandom, ::Type{Float64})
    x = Int64(next🎲(rng, 26))
    x = (x << 27) + next🎲(rng, 27)
    return x / (1 << 53)
end

function randjump🎲(rng::JavaRandom, ::Type{Int32}, n::Integer)
    # Initialize multiplier and addend for the transformation
    multiplier = one(UInt64)
    addend = zero(UInt64)
    initial_multiplier = MAGIC_JAVA_INT32
    initial_addend = MAGIC_JAVA_ADDEND

    # Loop to apply the transformation `n` times
    while !iszero(n)
        # If the least significant bit of steps_remaining is 1, update multiplier and addend
        if Bool(n & 1)
            multiplier *= initial_multiplier
            addend = muladd(initial_multiplier, addend, initial_addend)
        end

        # Update the constants for the next iteration
        initial_addend = (initial_multiplier + 1) * initial_addend
        initial_multiplier *= initial_multiplier

        # Right shift steps_remaining by 1 to process the next bit
        n >>= 1
    end

    # Update the RNG seed with the computed multiplier and addend
    rng.seed = (rng.seed * multiplier + addend) & ((1 << 48) - 1)

    return nothing
end

#=============================================================================#
#  Implementation of Xoshiro 128 MC                                           #
#=============================================================================#

"""
    JavaXoroshiro128PlusPlus(lo::UInt64, hi::UInt64)
    JavaXoroshiro128PlusPlus(seed::Integer)

A pseudo-random number generator that mimics the behavior of Java's implementation of
[`Xoroshiro128PlusPlus`](http://prng.di.unimi.it/xoshiro128plusplus.c) PRNG.
"""
mutable struct JavaXoroshiro128PlusPlus <: AbstractJavaRNG
    lo::UInt64
    hi::UInt64
end

function _get_lo_hi(seed::UInt64)
    XL = 0x9e3779b97f4a7c15
    XH = 0x6a09e667f3bcc909
    A = 0xbf58476d1ce4e5b9
    B = 0x94d049bb133111eb
    l = seed ⊻ XH
    h = l + XL
    l = (l ⊻ (l >> 30)) * A
    h = (h ⊻ (h >> 30)) * A
    l = (l ⊻ (l >> 27)) * B
    h = (h ⊻ (h >> 27)) * B
    l = l ⊻ (l >> 31)
    h = h ⊻ (h >> 31)
    return l, h
end

function set_seed!(rng::JavaXoroshiro128PlusPlus, seed::UInt64)
    rng.lo, rng.hi = _get_lo_hi(seed)
    return rng
end

function JavaXoroshiro128PlusPlus(seed)
    lo, hi = _get_lo_hi(u64_seed(seed))
    return JavaXoroshiro128PlusPlus(lo, hi)
end

Base.copy(rng::JavaXoroshiro128PlusPlus) = JavaXoroshiro128PlusPlus(rng.lo, rng.hi)
function Base.copy!(dst::JavaXoroshiro128PlusPlus, src::JavaXoroshiro128PlusPlus)
    dst.lo = src.lo
    dst.hi = src.hi
    return dst
end
function Base.:(==)(a::JavaXoroshiro128PlusPlus, b::JavaXoroshiro128PlusPlus)
    (a.lo == b.lo) && (a.hi == b.hi)
end

# nextLong method
function next🎲(rng::JavaXoroshiro128PlusPlus, ::Type{UInt64})
    l, h = rng.lo, rng.hi
    n = bitrotate(l + h, 17) + l
    h ⊻= l
    rng.lo = bitrotate(l, 49) ⊻ h ⊻ (h << 21)
    rng.hi = bitrotate(h, 28)
    return n
end
next🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int64}) = signed(next🎲(rng, UInt64))

# nextDouble method
function next🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Float64})
    return (next🎲(rng, UInt64) >> (64 - 53)) * 1.1102230246251565e-16
end

# nextFloat method
function next🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Float32})
    return Float32(next🎲(rng, UInt64) >> (64 - 24)) * 5.9604645f-8
end

# nextInt method
function next🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}, stop::Integer)::Int32
    stop = Int32(stop) + one(Int32)
    m = stop - one(Int32)
    iszero(m & stop) && return next🎲(rng, Int64) >> 32 & m

    val = zero(Int32)
    while true
        bits::Int32 = next🎲(rng, UInt64) >> 33
        val = bits % stop
        (bits + m - val) < 0 || break
    end
    return val
end

function randjump🎲(
    rng::JavaXoroshiro128PlusPlus,
    ::Type{<:Union{UInt64, Int64}},
    n::Integer,
)
    i = zero(n)
    while i < n
        next🎲(rng, UInt64)
        i += one(i)
    end
    return nothing
end
