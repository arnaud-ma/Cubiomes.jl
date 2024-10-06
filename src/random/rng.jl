using StaticArrays: SizedVector

abstract type AbstractRNG_MC end

"""
    next🎲(rng::AbstractRNG_MC, ::Type{T}) where T

Generate a random number of type `T` from the given random number generator.
"""
next🎲

"""
    randjump🎲(rng::AbstractRNG_MC, ::Type{T}, n::Integer) where T

Jump the state of the random number generator `n` steps forward, without generating
any random numbers.
"""
randjump🎲

#=============================================================================#
#                    Implementation of Java Random                            #
#=============================================================================#

const MAGIC_JAVA_INT32::UInt64 = 0x5DEECE66D
const MAGIC_JAVA_ADDEND::UInt64 = 0xB

_new_seed(seed::UInt64) = (seed ⊻ MAGIC_JAVA_INT32) & ((1 << 48) - 1)

"""
    JavaRNG(seed::Integer)

A pseudorandom number generator that mimics the behavior of Java's
[`java.util.Random`](https://docs.oracle.com/javase/7/docs/api/java/util/Random.html) class.

# Examples
```jldoctest
julia> rng = JavaRNG(1234);
JavaRNG(0x00000005deece2bf)
julia> next_int32_range!(rng, 10)
3
```
"""
mutable struct JavaRNG <: AbstractRNG_MC
    seed::UInt64
    # https://docs.oracle.com/javase/7/docs/api/java/util/Random.html#setSeed(long)
    JavaRNG(seed) = new(_new_seed(UInt64(unsigned(seed))))
    JavaRNG(seed::UInt64) = new(seed)
end

Base.copy(rng::JavaRNG) = JavaRNG(rng.seed)
function Base.copy!(dst::JavaRNG, src::JavaRNG)
    dst.seed = src.seed
    return dst
end
Base.hash(a::JavaRNG, h::UInt) = hash(a.seed, h)
Base.:(==)(a::JavaRNG, b::JavaRNG) = a.seed == b.seed

function set_seed!(rng::JavaRNG, seed::Integer)
    rng.seed = _new_seed(Int64(seed))
    return nothing
end

# Java's next method
function next🎲(rng::JavaRNG, bits::Int32)::Int32
    rng.seed = (rng.seed * MAGIC_JAVA_INT32 + MAGIC_JAVA_ADDEND) & ((1 << 48) - 1)
    result = rng.seed >> (48 - bits)
    return signed(UInt32(result))
end
next🎲(rng::JavaRNG, bits::Integer) = next🎲(rng, Int32(bits))

# Java's nextInt method
function next🎲(rng::JavaRNG, ::Type{Int32}; start::Integer=0, stop::Integer)::Int32
    iszero(start) || return next🎲(rng, Int32; stop=stop - start) + start
    stop::Int32 = stop + 1 # to include n in the range (difference of perspective between Java and Julia)
    m = stop - one(Int32)
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
next🎲(rng::JavaRNG, ::Type{Int64}) = (Int64(next🎲(rng, 32)) << 32) + next🎲(rng, 32)
# Java's nextFloat method
next🎲(rng::JavaRNG, ::Type{Float32}) = next🎲(rng, 24) / Float32(1 << 24)
# Java's nextDouble method
function next🎲(rng::JavaRNG, ::Type{Float64})
    x = reinterpret(UInt64, Int64(next🎲(rng, 26)))
    x <<= 27
    x += next🎲(rng, 27)
    return reinterpret(Int64, x) / reinterpret(Int64, one(UInt64) << 53)
end

function randjump🎲(rng::JavaRNG, ::Type{Int32}, n::Integer)
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
#                    Implementation of Xoshiro 128 MC                         #
#=============================================================================#

abstract type XoshiroMC <: AbstractRNG_MC end

mutable struct XoshiroMCOld <: XoshiroMC
    lo::UInt64
    hi::UInt64
end

mutable struct XoshiroMCNew <: XoshiroMC
    lo::UInt64
    hi::UInt64
end

function XoshiroMC(::Type{T}, seed::UInt64) where {T<:XoshiroMC}
    XL::UInt64 = 0x9e3779b97f4a7c15
    XH::UInt64 = 0x6a09e667f3bcc909
    A::UInt64 = 0xbf58476d1ce4e5b9
    B::UInt64 = 0x94d049bb133111eb
    l = seed ⊻ XH
    h = l + XL
    l = (l ⊻ (l >> 30)) * A
    h = (h ⊻ (h >> 30)) * A
    l = (l ⊻ (l >> 27)) * B
    h = (h ⊻ (h >> 27)) * B
    l = l ⊻ (l >> 31)
    h = h ⊻ (h >> 31)
    return T(l, h)
end
XoshiroMC(x::Type{T}, seed::Integer) where {T<:XoshiroMC} = XoshiroMC(x, UInt64(seed))
XoshiroMCNew(seed::Integer) = XoshiroMC(XoshiroMCNew, seed)
XoshiroMCOld(seed::Integer) = XoshiroMC(XoshiroMCOld, seed)

Base.copy(rng::T) where {T<:XoshiroMC} = T(rng.lo, rng.hi)
function Base.copy!(dst::XoshiroMC, src::XoshiroMC)
    dst.lo = src.lo
    dst.hi = src.hi
    return dst
end
Base.hash(a::XoshiroMC, h::UInt) = hash((a.lo, a.hi), h)

function _old_next_int64🎲(rng::XoshiroMC)
    l, h = rng.lo, rng.hi
    n = bitrotate(l + h, 17) + l
    h ⊻= l
    rng.lo = bitrotate(l, 49) ⊻ h ⊻ (h << 21)
    rng.hi = bitrotate(h, 28)
    return n
end
next🎲(rng::XoshiroMCOld, ::Type{UInt64}) = _old_next_int64🎲(rng)

function next🎲(rng::XoshiroMCNew, ::Type{UInt64})::UInt64
    a = UInt32(_old_next_int64🎲(rng) >> 32)
    b = reinterpret(Int32, UInt32(_old_next_int64🎲(rng) >> 32))
    return (UInt64(a) << 32) + b
end

function _next🎲(rng::XoshiroMCOld, ::Type{Int32}; stop::Integer)::Int32
    stop += 1
    mask = typemax(UInt32)
    r = (next🎲(rng, UInt64) & mask) * stop
    if (r & mask) < stop
        while (r & mask) < ((~stop + 1) % stop)
            r = (next🎲(rng, UInt64) & mask) * stop
        end
    end
    return r >> 32
end

function _next🎲(rng::XoshiroMCNew, ::Type{Int32}; stop::Integer)::Int32
    stop += 1
    m = stop - 1
    if iszero(m & stop)
        x::UInt64 = stop * (_old_next_int64🎲(rng) >> 33)
        return Int64(x) >> 31
    end

    val = zero(Int32)
    while true
        bits::Int32 = _old_next_int64🎲(rng) >> 33
        val = bits % stop
        (bits - val + m) < 0 || break
    end
    return val
end

function next🎲(
    rng::T, ::Type{Int32}; start::Integer=0, stop::Integer
)::Int32 where {T<:XoshiroMC}
    return _next🎲(rng, Int32; stop=stop - start) + start
end

function next🎲(rng::XoshiroMC, ::Type{Float64})
    return (next🎲(rng, UInt64) >> (64 - 53)) * 1.1102230246251565e-16
end
function next🎲(rng::XoshiroMC, ::Type{Float32})
    return (next🎲(rng, UInt64) >> (64 - 24)) * 5.9604645e-8
end

function randjump🎲(rng::XoshiroMC, ::T, n::I) where {T,I<:Integer}
    i = one(I)
    while i < n
        next🎲(rng, T)
        i += one(I)
    end
    return nothing
end

function next🎲(
    rng::AbstractRNG_MC, ::Type{Float64}; start::Real=zero(Float64), stop::Real
)::Float64
    return muladd(stop - start, next🎲(rng, Float64), start)
end

#=============================================================================#
#                    MC Seed Helpers                                          #
#=============================================================================#

function mc_step_seed(seed::UInt64, salt::UInt64)::UInt64
    return muladd(seed, muladd(seed, 6364136223846793005, 1442695040888963407), salt)
    # return seed * (seed * seed * 6364136223846793005 + 1442695040888963407) + salt
end
mc_step_seed(seed::UInt64, salt::Integer) = mc_step_seed(seed, unsigned(Int64(salt)))

function mc_first_int(seed::UInt64, mod::Integer)
    ret::Int32 = reinterpret(Int64, seed) % mod
    if ret < 0
        ret += mod
    end
    return ret
end

function mc_first_is_zero(seed::UInt64, mod::Integer)
    return ((reinterpret(Int64, seed) >> 24) % mod) == 0
end

function get_chunk_seed(seed::UInt64, x::UInt64, z::UInt64)::UInt64
    chunk_seed = seed + x
    chunk_seed = mc_step_seed(chunk_seed, z)
    chunk_seed = mc_step_seed(chunk_seed, x)
    chunk_seed = mc_step_seed(chunk_seed, z)
    return chunk_seed
end
function get_chunk_seed(seed::UInt64, x::Integer, z::Integer)
    return get_chunk_seed(seed, UInt64(x), UInt64(z))
end

function get_layer_salt(salt::UInt64)::UInt64
    layer_salt = mc_step_seed(salt, salt)
    layer_salt = mc_step_seed(layer_salt, salt)
    layer_salt = mc_step_seed(layer_salt, salt)
    return layer_salt
end

function get_start_salt(world_start::UInt64, layer_start::UInt64)::UInt64
    start_salt = world_start
    start_salt = mc_step_seed(start_salt, layer_start)
    start_salt = mc_step_seed(start_salt, layer_start)
    start_salt = mc_step_seed(start_salt, layer_start)
    return start_salt
end

@inline function get_start_seed(world_start::UInt64, ls::UInt64)::UInt64
    start_seed = world_start
    start_seed = get_start_salt(start_seed, ls)
    start_seed = mc_step_seed(start_seed, 0)
    return start_seed
end

#=============================================================================#
#                    Arithmetic                                               #
#=============================================================================#

# Linear interpolation
# lerp(part, from, to) = from + part * (to - from)
lerp(part, from, to) = muladd(part, to - from, from)

function lerp2(dx, dy, v00, v10, v01, v11)
    from = lerp(dx, v00, v10)
    to = lerp(dx, v01, v11)
    return lerp(dy, from, to)
end

function lerp3(dx, dy, dz, v000, v100, v010, v110, v001, v101, v011, v111)
    v00 = lerp2(dx, dy, v000, v100, v010, v110)
    v01 = lerp2(dx, dy, v001, v101, v011, v111)
    return lerp(dz, v00, v01)
end

const Couple = NTuple{2}
@inbounds function lerp4(a::Couple, b::Couple, c::Couple, d::Couple, dy, dx, dz)
    b00 = lerp(dy, a[1], a[2])
    b01 = lerp(dy, b[1], b[2])
    b10 = lerp(dy, c[1], c[2])
    b11 = lerp(dy, d[1], d[2])
    b0 = lerp(dz, b00, b10)
    b1 = lerp(dz, b01, b11)
    return lerp(dx, b0, b1)
end

clamped_lerp(part, from, to) = lerp(clamp(part, 0, 1), from, to)

mulinv(x, m) = throw(ErrorException(lazy"Use `Base.invmod` instead."))

#=============================================================================#
#                    SHA                                                      #
#=============================================================================#

#! format: off
const SHA256_CONSTANTS = (
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
)

const SHA256_INITIAL_VALUES = (
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
)

split_u64(x::UInt64) = UInt32(x >> 32), UInt32(x & typemax(UInt32))

function sha256_from_seed(seed::UInt64)::UInt64
    m = Vector{UInt32}(undef, 64)
    m[2], m[1] = bswap.(split_u64(seed))
    m[3] = 1 << 31
    for i in 4:15
        m[i] = 0
    end
    m[16] = 0x40
    for i in 17:64
        m[i] = m[i - 7] + m[i - 16]
        x = m[i - 15]
        m[i] += bitrotate(x, -7) ⊻ bitrotate(x, -18) ⊻ (x >> 3)
        x = m[i - 2]
        m[i] += bitrotate(x, -17) ⊻ bitrotate(x, -19) ⊻ (x >> 10)
    end

    a = SHA256_INITIAL_VALUES[1]
    b = SHA256_INITIAL_VALUES[2]
    c = SHA256_INITIAL_VALUES[3]
    d = SHA256_INITIAL_VALUES[4]
    e = SHA256_INITIAL_VALUES[5]
    f = SHA256_INITIAL_VALUES[6]
    g = SHA256_INITIAL_VALUES[7]
    h = SHA256_INITIAL_VALUES[8]

    for i in 1:64
        x = h + SHA256_CONSTANTS[i] + m[i]
        x += bitrotate(e, -6) ⊻ bitrotate(e, -11) ⊻ bitrotate(e, -25)
        x += (e & f) ⊻ (~e & g)

        y = bitrotate(a, -2) ⊻ bitrotate(a, -13) ⊻ bitrotate(a, -22)
        y += (a & b) ⊻ (a & c) ⊻ (b & c)

        h = g
        g = f
        f = e
        e = d + x
        d = c
        c = b
        b = a
        a = x + y
    end

    a += SHA256_INITIAL_VALUES[1]
    b += SHA256_INITIAL_VALUES[2]
    c += SHA256_INITIAL_VALUES[3]
    d += SHA256_INITIAL_VALUES[4]
    e += SHA256_INITIAL_VALUES[5]
    f += SHA256_INITIAL_VALUES[6]
    g += SHA256_INITIAL_VALUES[7]
    h += SHA256_INITIAL_VALUES[8]

    return bswap(a) | (UInt64(bswap(b)) << 32)
end
