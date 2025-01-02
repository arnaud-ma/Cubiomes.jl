using MD5: md5

"""
    bytes2uint64(itr)

Converts an iterator of bytes to an iterator of UInt64.

# Example
```julia
>>> bytes2uint64([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]) |> collect
2-element Vector{UInt64}:
0x0102030405060708
0x090a0b0c0d0e0f10
"""
function bytes2uint64(itr)
    hex = bytes2hex(itr)
    return (parse(UInt64, x; base=16) for x in Iterators.partition(hex, 16))
end

md5_to_uint64 = bytes2uint64 ∘ md5

function java_hashcode(str::String)
    hash_code = zero(Int32)
    for char in str
        hash_code = hash_code * Int32(31) + Int32(char)
    end
    return hash_code
end

java_hashcode(x::Char) = Int32(x)

u64_seed(x::UInt64) = x
u64_seed(x::Unsigned) = u64_seed(UInt64(x))
u64_seed(x::Integer) = u64_seed(unsigned(x))
u64_seed(x::Real) = u64_seed(Integer(x))
u64_seed(x::Union{String, Char}) = java_hashcode(x)

#region SHA
# ---------------------------------------------------------------------------- #
#                                      SHA                                     #
# ---------------------------------------------------------------------------- #

SHA256_ROUND_CONSTANTS::NTuple{64, UInt32} = (
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

# first 32 bits of the fractional parts of the square roots of the first 8 primes 2..19)
const SHA256_INITIAL_VALUES::NTuple{8, UInt32} = (
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
)

split_u64(x::UInt64) = UInt32(x & typemax(UInt32)), UInt32(x >> 32)
concat_u32(x::UInt32, y::UInt32) = UInt64(x) << 32 | y

sha256_from_seed(seed::UInt64) = sha256_from_seed!(Array{UInt32}(undef, 64), seed)
function sha256_from_seed!(w, seed::UInt64)
    w[1], w[2] = bswap.(split_u64(seed))
    w[3] = 1 << 31
    w[4:15] .= 0
    w[16] = 0x40

    for i in 17:64
        x = w[i - 15]
        s0 = bitrotate(x, -7) ⊻ bitrotate(x, -18) ⊻ (x >> 3)
        x = w[i - 2]
        s1 = bitrotate(x, -17) ⊻ bitrotate(x, -19) ⊻ (x >> 10)
        w[i] = w[i - 7] + s0 + w[i - 16] + s1
    end

    x₁, x₂, x₃, x₄, x₅, x₆, x₇, x₈ = SHA256_INITIAL_VALUES
    for i in 1:64
        Σ₁ = bitrotate(x₅, -6) ⊻ bitrotate(x₅, -11) ⊻ bitrotate(x₅, -25)
        ch = (x₅ & x₆) ⊻ (~x₅ & x₇)
        temp1 = x₈ + Σ₁ + ch + SHA256_ROUND_CONSTANTS[i] + w[i]

        Σ₀ = bitrotate(x₁, -2) ⊻ bitrotate(x₁, -13) ⊻ bitrotate(x₁, -22)
        maj = (x₁ & x₂) ⊻ (x₁ & x₃) ⊻ (x₂ & x₃)
        temp2 = Σ₀ + maj

        x₁, x₂, x₃, x₄, x₅, x₆, x₇, x₈ = temp1 + temp2, x₁, x₂, x₃, x₄ + temp1, x₅, x₆, x₇
    end

    x₁ += SHA256_INITIAL_VALUES[1]
    x₂ += SHA256_INITIAL_VALUES[2]

    return concat_u32(bswap(x₂), bswap(x₁))
end
#endregion

#region Arithmetic
# ---------------------------------------------------------------------------- #
#                                  Arithmetic                                  #
# ---------------------------------------------------------------------------- #

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
#endregion

#region collections
# ---------------------------------------------------------------------------- #
#                                  Collections                                 #
# ---------------------------------------------------------------------------- #

"""
    length_of_trimmed(predicate, x) where N

Returns the length of the collection `x` after removing the elements from the beginning and the end
that satisfy the `predicate`.

⚠ The collection *must* have the property so that `x[i]` for `i` in firstindex(x):lastindex(x)
is valid.
"""
function length_of_trimmed(predicate, x)
    len = length(x)
    first, last = firstindex(x), lastindex(x)
    i = last
    while predicate(x[i])
        i -= 1
        len -= 1
        if i == first
            return 0
        end
    end
    i = first
    while predicate(x[i])
        i += 1
        len -= 1
    end
    return len
end

function length_filter(predicate, x)
    count = zero(Int)
    for i in x
        if predicate(i)
            count += 1
        end
    end
    return count
end
#endregion

#region types
# ---------------------------------------------------------------------------- #
#                                     Types                                    #
# ---------------------------------------------------------------------------- #

"""
    @only_float32 expr

Transforms all real literals in the expr to Float32.

# Example
```julia
@only_float32 function f()
    x = 1 + 2im # expand to `1.0f0 + 2.0f0im`
    x += 1 # expand to `x += 1.0f0`
    return x
end
```
"""
macro only_float32(expr)
    transform(x) = x
    transform(x::T) where {T <: Real} = Meta.parse(string(x, "f0"))
    transform(x::Float32) = x
    transform(x::Bool) = x
    function transform(x::Expr)
        x.head == :curly && return x
        return Expr(x.head, map(transform, x.args)...)
    end
    return transform(expr)
end
