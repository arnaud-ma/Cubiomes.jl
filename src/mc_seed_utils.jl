"""
Minecraft Seed Utilities.
"""
module SeedUtils
using MD5: md5

public md5_to_uint64, u64_seed, sha256_from_seed, sha256_from_seed!


# ---------------------------------------------------------------------------- #
#                          region Conversion to UInt64                         #
# ---------------------------------------------------------------------------- #

"""
    bytes2uint64(itr)

Converts an iterator of bytes to an iterator of UInt64.

# Example
```julia
julia> bytes2uint64([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]) |> collect
2-element Vector{UInt64}:
0x0102030405060708
0x090a0b0c0d0e0f10
```
"""
function bytes2uint64(itr)
    hex = bytes2hex(itr)
    return (parse(UInt64, x; base = 16) for x in Iterators.partition(hex, 16))
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

"""
    u64_seed(x)

Converts `x` to `UInt64` for use as a seed, exactly as the Minecraft Java Edition does. It
can be any integer or a string.

# Example
```julia
julia> u64_seed(1234)
0x00000000000004d2

julia> u64_seed("hello world")
0x000000006aefe2c4
```
"""
function u64_seed end

u64_seed(x::UInt64) = x
u64_seed(x::Unsigned) = u64_seed(UInt64(x))
u64_seed(x::Integer) = u64_seed(unsigned(x))
u64_seed(x::Real) = u64_seed(Integer(x))
u64_seed(x::Union{String, Char}) = u64_seed(java_hashcode(x))

# ---------------------------------------------------------------------------- #
#                                  region SHA                                  #
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

sha256_from_seed(seed::UInt64) = sha256_from_seed!(MVector{64, UInt32}(undef), seed)
@inline function sha256_from_seed!(w, seed::UInt64)
    w[1], w[2] = bswap.(split_u64(seed))
    w[3] = 0x80000000 # 2^31
    w[4:15] .= zero(UInt32)
    w[16] = 0x00000040 # 2^6

    for i in 17:64
        x = w[i - 15]
        s0 = bitrotate(x, -7) ⊻ bitrotate(x, -18) ⊻ (x >> 3)
        x = w[i - 2]
        s1 = bitrotate(x, -17) ⊻ bitrotate(x, -19) ⊻ (x >> 10)
        w[i] = w[i - 7] + s0 + w[i - 16] + s1
    end

    x1, x2, x3, x4, x5, x6, x7, x8 = SHA256_INITIAL_VALUES
    for i in 1:64
        Σ1 = bitrotate(x5, -6) ⊻ bitrotate(x5, -11) ⊻ bitrotate(x5, -25)
        ch = (x5 & x6) ⊻ (~x5 & x7)
        temp1 = x8 + Σ1 + ch + SHA256_ROUND_CONSTANTS[i] + w[i]

        Σ0 = bitrotate(x1, -2) ⊻ bitrotate(x1, -13) ⊻ bitrotate(x1, -22)
        maj = (x1 & x2) ⊻ (x1 & x3) ⊻ (x2 & x3)
        temp2 = Σ0 + maj

        x1, x2, x3, x4, x5, x6, x7, x8 = temp1 + temp2, x1, x2, x3, x4 + temp1, x5, x6, x7
    end

    x1 += SHA256_INITIAL_VALUES[1]
    x2 += SHA256_INITIAL_VALUES[2]

    return concat_u32(bswap(x2), bswap(x1))
end
#endregion

# ---------------------------------------------------------------------------- #
#                               region chunk seed                              #
# ---------------------------------------------------------------------------- #

"""
    MAGIC_LCG_MULTIPLIER::UInt64

The multiplier used in the LCG algorithm. This is a constant used in the
Minecraft seed generation algorithm.

See Also: [`MAGIC_LCG_INCREMENTOR`](@ref), [`mc_step_seed`](@ref), [LCG wiki](https://en.wikipedia.org/wiki/Linear_congruential_generator)
"""
const MAGIC_LCG_MULTIPLIER = 6364136223846793005

"""
    MAGIC_LCG_INCREMENTOR::UInt64

The incrementor used in the LCG algorithm. This is a constant used in the
Minecraft seed generation algorithm.

See Also: [`MAGIC_LCG_MULTIPLIER`](@ref), [`mc_step_seed`](@ref), [LCG wiki](https://en.wikipedia.org/wiki/Linear_congruential_generator)
"""
const MAGIC_LCG_INCREMENTOR = 1442695040888963407

"""
    mc_step_seed(seed::UInt64, salt::UInt64)

Used to generate the next seed in the Minecraft seed generation algorithm, given
the current seed and a salt.
"""
function mc_step_seed(seed, salt)
    # salt + c1 seed + c2 seed^2
    return @evalpoly(u64_seed(seed), u64_seed(salt), MAGIC_LCG_INCREMENTOR, MAGIC_LCG_MULTIPLIER)
end

function mc_first_int(seed::Signed, mod::Integer)
    error(lazy"Use mod($seed, $mod) instead of mc_first_int($seed, $mod)")
end
mc_first_int(seed::Unsigned, mod) = mc_first_int(signed(seed), mod)

mc_first_is_zero(seed::Int64, mod::Integer) = iszero((seed >> 24) % mod)
mc_first_is_zero(seed::UInt64, mod::Integer) = mc_first_is_zero(signed(seed), mod)

function get_chunk_seed(seed::UInt64, x::UInt64, z::UInt64)
    chunk_seed = seed + x
    chunk_seed = mc_step_seed(chunk_seed, z)
    chunk_seed = mc_step_seed(chunk_seed, x)
    chunk_seed = mc_step_seed(chunk_seed, z)
    return chunk_seed
end

function get_layer_salt(salt::UInt64)
    layer_salt = mc_step_seed(salt, salt)
    layer_salt = mc_step_seed(layer_salt, salt)
    layer_salt = mc_step_seed(layer_salt, salt)
    return layer_salt
end

function get_start_salt(world_start::UInt64, layer_start::UInt64)
    start_salt = world_start
    start_salt = mc_step_seed(start_salt, layer_start)
    start_salt = mc_step_seed(start_salt, layer_start)
    start_salt = mc_step_seed(start_salt, layer_start)
    return start_salt
end

function get_start_seed(world_start::UInt64, ls::UInt64)
    start_seed = world_start
    start_seed = get_start_salt(start_seed, ls)
    start_seed = mc_step_seed(start_seed, 0)
    return start_seed
end
#endregion
end # module
