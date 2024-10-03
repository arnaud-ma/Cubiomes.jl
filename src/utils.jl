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
