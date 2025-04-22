"""
    Scale{N}
    Scale(N::Integer)
    📏"1:N"

The scale of a map. It represents the ratio between the size of the map an the real world.
For example, a 1:4 scale map means that each block in the map represents a 4x4 area
in the real world. So the coordinates (5, 5) are equal to the real world coordinates
(20, 20).

`N` **MUST** ne to the form ``4^n, n \\geq 0``. So the more common scales are 1:1, 1:4, 1:16,
1:64, 1:256. The support for big scales is not guaranteed and depends on the function that
uses it. Read the documentation of the function that uses it to know the supported values.

It is possible to use the alternative syntax `📏"1:N"`. The emoji name is `:straight_ruler:`.

# Examples
```julia
julia> Scale(4)
Scale{4}()

julia> Scale(5)
ERROR: ArgumentError: The scale must be to the form 4^n. Got 1:5. The closest valid scales are 1:4 and 1:16.

julia> 📏"1:4" === Scale(4) === Scale{4}()
true

```
"""
struct Scale{N}
    function Scale{N}() where {N}
        if N < 1
            throw(ArgumentError("The scale must be to the form 2^(2n) with n >= 0. Got $N."))
        end
        i = log(4, N)
        if !(isinteger(i))
            ii = floor(Int, i)
            closest_before = 4^ii
            closest_after = 4^(ii + 1)
            throw(ArgumentError("The scale must be to the form 4^n. Got 1:$N. The closest valid scales are 1:$closest_before and 1:$closest_after."))
        end
        return new()
    end
end
Scale(N::Integer) = Scale{N}()

macro 📏_str(str)
    splitted = split(str, ':')
    if length(splitted) != 2
        throw(ArgumentError("Bad scale format."))
    end
    num, denom = parse.(Int, splitted)
    scale = num // denom
    if numerator(scale) != 1
        throw(ArgumentError("The scale must be simplified to the form 1:N. Got $str -> $num:$denom."))
    end
    return Scale(denominator(scale))
end
const var"@T📏_str" = typeof ∘ var"@📏_str"