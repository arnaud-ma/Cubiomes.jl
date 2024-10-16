function mc_step_seed(seed::UInt64, salt::UInt64)::UInt64
    return muladd(seed, muladd(seed, 6364136223846793005, 1442695040888963407), salt)
    # seed * (seed * 6364136223846793005 + 1442695040888963407) + salt
end
mc_step_seed(seed::UInt64, salt::Integer) = mc_step_seed(seed, UInt64(unsigned(salt)))

function mc_first_int(seed::Signed, mod::Integer)
    ret = seed % mod
    if ret < 0
        ret += mod
    end
    return ret
end
mc_first_int(seed::Unsigned, mod) = mc_first_int(signed(seed), mod)

mc_first_is_zero(seed::Int64, mod::Integer) = iszero((seed >> 24) % mod)
mc_first_is_zero(seed::UInt64, mod::Integer) = mc_first_is_zero(signed(seed), mod)

function get_chunk_seed(seed::UInt64, x::UInt64, z::UInt64)::UInt64
    chunk_seed = seed + x
    chunk_seed = mc_step_seed(chunk_seed, z)
    chunk_seed = mc_step_seed(chunk_seed, x)
    chunk_seed = mc_step_seed(chunk_seed, z)
    return chunk_seed
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

function get_start_seed(world_start::UInt64, ls::UInt64)::UInt64
    start_seed = world_start
    start_seed = get_start_salt(start_seed, ls)
    start_seed = mc_step_seed(start_seed, 0)
    return start_seed
end
