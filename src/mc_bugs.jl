"""
    overflow_int32(x::Int64)::Bool

Returns true if the value `x` overflows when converted to a signed 32-bit integer.
"""
overflow_int32(x::Int64)::Bool = signed(UInt32(x & typemax(UInt32))) < 0

"""
    has_bug_mc_159283(version::MCVersion, x::Int64, z::Int64)

See https://bugs.mojang.com/browse/MC-159283 for more information.
"""
function has_bug_mc_159283(version::MCVersion, x::Int64, z::Int64)
    return (version >= MC_1_14) && overflow_int32((2x + 1)^2 + (2z + 1)^2)
end
