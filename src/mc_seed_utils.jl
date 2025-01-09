
"""
Minecraft Seed Utilities, like the LCG algorithm used in the seed generation.
"""
module SeedUtils

using ..Utils: u64_seed

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
    evalpoly(u64_seed(seed), (u64_seed(salt), MAGIC_LCG_INCREMENTOR, MAGIC_LCG_MULTIPLIER))
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

end # module
