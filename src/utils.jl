"""
Some utility functions and types that are used in various places in the codebase. It should
not be used directly by the user and could be nice if this module does not exist at all.
"""
module Utils

public lerp, lerp2, lerp3, lerp4, clamped_lerp
public length_of_trimmed, length_filter
public @only_float32


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

function trim(predicate, x)
    first, last = firstindex(x), lastindex(x)
    while predicate(x[first])
        first += 1
        if first > last
            return x
        end
    end
    while predicate(x[last])
        last -= 1
        if last < first
            return x
        end
    end
    return x[first:last]
end

function trim_end(predicate, x)
    first, last = firstindex(x), lastindex(x)
    while predicate(x[last])
        last -= 1
        if last < first
            return x
        end
    end
    return x[begin:last]
end

"""
    findfirst_default(predicate::Function, A, default)

Return the first index i of A where predicate(A[i]) is true. If
no i satisfy this, default is returned instead.
"""
function findfirst_default(predicate::Function, A, default)
    for (i, a) in pairs(A)
        if predicate(a)
            return i
        end
    end
    return default
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
    return transform(esc(expr))
end
#endregion
#region Iteration
# ---------------------------------------------------------------------------- #
#                                  Iteration                                   #
# ---------------------------------------------------------------------------- #

end # module
