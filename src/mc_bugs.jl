"""
Utility functions for working with known Minecraft bugs.
"""
module MCBugs

using ..MCVersions

"""
    overflow_int32(x::Int64)

Returns true if the value `x` overflows when converted to a signed 32-bit integer.
"""
overflow_int32(x::Int64) = signed(UInt32(x & typemax(UInt32))) < zero(Int32)

"""
    has_bug_mc159283(version::MCVersion, x::Int64, z::Int64)

See [MC-159283](https://bugs.mojang.com/browse/MC-159283) for more information.
"""
has_bug_mc159283(_version, _x::Int64, _z::Int64) = false
function has_bug_mc159283(::mcvt">=1.14", x::Int64, z::Int64)
    return overflow_int32((2x + 1)^2 + (2z + 1)^2)
end
end # module
