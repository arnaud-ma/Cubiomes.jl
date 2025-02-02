module MCVersions

export @mcv_str, @mcvt_str, MCVersion, MC_VERSIONS

#!format: off
public vNEWEST, vUNDEF
#!format: on

using InteractiveUtils: subtypes
using Base: nextminor, Fix1, Fix2

abstract type MCVersion end

struct v1beta1_7 <: MCVersion end
struct v1beta1_8 <: MCVersion end

struct v1_0_0 <: MCVersion end
struct v1_1_0 <: MCVersion end
struct v1_2_5 <: MCVersion end
struct v1_3_2 <: MCVersion end
struct v1_4_2 <: MCVersion end
struct v1_5_2 <: MCVersion end
struct v1_6_4 <: MCVersion end
struct v1_7_10 <: MCVersion end
struct v1_8_9 <: MCVersion end
struct v1_9_4 <: MCVersion end
struct v1_10_2 <: MCVersion end
struct v1_11_2 <: MCVersion end
struct v1_12_2 <: MCVersion end
struct v1_13_2 <: MCVersion end
struct v1_14_4 <: MCVersion end
struct v1_15_2 <: MCVersion end
struct v1_16_1 <: MCVersion end
struct v1_16_5 <: MCVersion end
struct v1_17_1 <: MCVersion end
struct v1_18_2 <: MCVersion end
struct v1_19_2 <: MCVersion end
# struct v1_19_3 <: MCVersion end
struct v1_19_4 <: MCVersion end
struct v1_20 <: MCVersion end
struct v1_21 <: MCVersion end

remove_first(x::AbstractString) = chop(x; head=1, tail=0)

function _to_jl_version(x::Type{<:MCVersion})
    return string(nameof(x)) |>                     # Module1.Module2.v1_8_9
           Fix2(split, ".") |> last |>      # v1_8_9
           remove_first |>                  # 1_8_9
           Fix2(replace, "_" => ".") |>     # 1.8.9
           VersionNumber                    # v"1.8.9"
end

const VERSIONS_DICT = Dict(_to_jl_version(x) => x for x in subtypes(MCVersion))
const VERSIONS = keys(VERSIONS_DICT) |> collect |> sort |> Tuple
const MC_VERSIONS = Tuple([VERSIONS_DICT[x] for x in VERSIONS])
const VERSIONS_DICT_JL = Dict(zip(values(VERSIONS_DICT), keys(VERSIONS_DICT)))

to_jl_version(x::Type{<:MCVersion}) = VERSIONS_DICT_JL[x]

const vNEWEST = MC_VERSIONS[end]
struct vUNDEF <: MCVersion end

for (i, version_jl) in enumerate(VERSIONS)
    version = VERSIONS_DICT[version_jl]
    @eval id(::Type{$version}) = $(UInt8(i))
end

for func in (:(==), :isless)
    @eval Base.$func(x::Type{<:MCVersion}, y::Type{<:MCVersion}) =
        $func(id(x), id(y))
end

Base.print(io::IO, v::Type{<:MCVersion}) = print(io, to_jl_version(v))
Base.show(io::IO, v::Type{<:MCVersion}) = print(io, "mcv\"", v, "\"")

function get_closest_minor_version(version, compare_versions)
    version in compare_versions && return version
    return minimum(
        filter(x -> (version <= x <= nextminor(version)), compare_versions);
        init=v"∞",
    )
end

function to_mc_version(x)
    version = get_closest_minor_version(x, VERSIONS)
    if version == v"∞"
        throw(ArgumentError("Minecraft version $x not available"))
    end
    return VERSIONS_DICT[version]
end

function str_to_mcversion(str)
    str == "undef" && return vUNDEF
    str == "newest" && return vNEWEST
    if startswith(str, "beta")
        str = "1" * str
    end
    return to_mc_version(VersionNumber(str))
end

"""
    @mcv_str

A string macro to get a Minecraft version. For example `mcv"1.8.9"`
represents the 1.8.9 version or `mcv"beta1.7"` for the beta 1.7.

!!!warning
    It does not *exactly* represents a Minecraft version, but more a close one, where the
    biome generation is the same. For example, `mcv"1.8.6"` is exactly equal to `mcv"1.8.9`
    since the generation does not change between those two versions.
"""
macro mcv_str(str)
    return str_to_mcversion(str)
end

function _mcvt(str)
    str = strip(str)
    regex_sign = r"(<=)|(>=)|(<)|(>)"

    matches_sign = map(x -> x.match, eachmatch(regex_sign, str))
    if length(matches_sign) == 0
        return :(Type{$(str_to_mcversion(str))})
    end

    func = x -> throw(ArgumentError("Too much comparison"))

    if length(matches_sign) == 1
        sign = first(matches_sign)
        version_str = chop(str; head=length(sign), tail=0)
        sign = Symbol(sign)
        version = VersionNumber(strip(version_str))
        func = @eval $sign($version)
    elseif length(matches_sign) == 2
        sign1, sign2 = matches_sign
        part1, remain = split(str, sign1; limit=2)
        _, part2 = split(remain, sign2; limit=2)

        v1, v2 = VersionNumber(strip(part1)), VersionNumber(strip(part2))
        func1 = @eval Base.Fix1($(Symbol(sign1)), $v1)
        func2 = @eval Base.Fix2($(Symbol(sign2)), $v2)
        func = x -> func1(x) && func2(x)
    end
    filtered_versions = filter(func, VERSIONS)
    return :(Union{$(map(x -> Type{to_mc_version(x)}, filtered_versions))...})
end

"""
    @mcvt_str

A string macro to get the type representation of one or more (with an Union{}) Minecraft versions.
Useful for functions who need to dispatch over specifics versions.

The syntax is:
    - `mcvt"1.8.9"` -> expands to Type{mcv"1.8.9"}
    - `mcvt">=1.8.9"` -> expands to Union{...} on every version >=1.8.9.
      The supported operations are `<, <=, >, >=`.
    - `mcvt"1.0.0<=x<=1.8.9` -> expands to Union{...} on every version such that 1.0.0<=version<=1.8.9.
      The place holder `x` can be anything, can even be empty. The supported operations are **only** `<, <=`.

# Example
```
julia> end_type(::mcvt"<1.0.0") = nothing
end_type (generic function with 3 methods)

julia> end_type(::mcvt"1.0.0<=_<1.9.0") = :old
end_type (generic function with 3 methods)

julia> end_type(::mcvt">=1.9.0") = :new
end_type (generic function with 3 methods)

julia> end_type(mcv"1.13")
:new
"""
macro mcvt_str(str)
    return _mcvt(str)
end
end # module