#==========================================================================================#
# Noise Parameters
#==========================================================================================#
# ? Types instead of enums?
abstract type NoiseParameter end

struct NP_SHIFT <: NoiseParameter end
struct NP_TEMPERATURE <: NoiseParameter end
struct NP_HUMIDITY <: NoiseParameter end
struct NP_CONTINENTALNESS <: NoiseParameter end
struct NP_EROSION <: NoiseParameter end
struct NP_WEIRDNESS <: NoiseParameter end

const NB_NOISE_PARAMETERS = length(subtypes(NoiseParameter))

amplitudes(noise_param::Type{NP_SHIFT}) = (1, 1, 1, 0)
octave_min(noise_param::Type{NP_SHIFT}; large::Bool) = -3
id(noise_param::Type{NP_SHIFT}; large::Bool) = "minecraft:offset"

amplitudes(noise_param::Type{NP_TEMPERATURE}) = (1.5, 0.0, 1.0, 0.0, 0.0, 0.0)
octave_min(noise_param::Type{NP_TEMPERATURE}; large::Bool) = large ? -12 : -10
function id(noise_param::Type{NP_TEMPERATURE}; large::Bool)
    return large ? "minecraft:temperature_large" : "minecraft:temperature"
end

amplitudes(noise_param::Type{NP_HUMIDITY}) = (1, 1, 0, 0, 0, 0)
octave_min(noise_param::Type{NP_HUMIDITY}; large::Bool) = large ? -10 : -8
function id(noise_param::Type{NP_HUMIDITY}; large::Bool)
    return large ? "minecraft:vegetation_large" : "minecraft:vegetation"
end

amplitudes(noise_param::Type{NP_CONTINENTALNESS}) = (1, 1, 2, 2, 2, 1, 1, 1, 1)
octave_min(noise_param::Type{NP_CONTINENTALNESS}; large::Bool) = large ? -11 : -9
function id(noise_param::Type{NP_CONTINENTALNESS}; large::Bool)
    return large ? "minecraft:continentalness_large" : "minecraft:continentalness"
end

amplitudes(noise_param::Type{NP_EROSION}) = (1, 1, 0, 1, 1)
octave_min(noise_param::Type{NP_EROSION}; large::Bool) = large ? -11 : -9
function id(noise_param::Type{NP_EROSION}; large::Bool)
    return large ? "minecraft:erosion_large" : "minecraft:erosion"
end

amplitudes(noise_param::Type{NP_WEIRDNESS}) = (1, 2, 1, 0, 0, 0)
octave_min(noise_param::Type{NP_WEIRDNESS}; large::Bool) = -7
id(noise_param::Type{NP_WEIRDNESS}; large::Bool) = "minecraft:ridge"

for noise_param in subtypes(NoiseParameter)
    xlo, xhi = md5_to_uint64(id(noise_param; large=false))
    xlo_large, xh_large = md5_to_uint64(id(noise_param; large=true))

    @eval begin
        magic_xlo(noise_param::Type{$noise_param}; large::Bool) = large ? $xlo_large : $xlo
        magic_xhi(noise_param::Type{$noise_param}; large::Bool) = large ? $xh_large : $xhi
    end
end

#==========================================================================================#
# Splines
#==========================================================================================#

#! We do not use abstract type SplineType instead of enums
# because we store different types of splines in the same array (Spline.val)
# and storing different types in the same array abuses the type system
# and makes it harder for the compiler to optimize the code.
@enum SplineType begin
    SP_CONTINENTALNESS
    SP_EROSION
    SP_RIDGES
    SP_WEIRDNESS
end

abstract type AbstractSpline end

mutable struct Spline <: AbstractSpline
    len::Int
    spline_type::SplineType
    locations::Vector{Float32}
    derivatives::Vector{Float32}
    child_splines::Vector{Spline}
end

struct FixSpline <: AbstractSpline
    value::Float32
end

# function Spline(len::Int, typ::SplineType)
#     return Spline(
#         len,
#         typ,
#         Vector{Float32}(undef, 12),
#         Vector{Float32}(undef, 12),
#         Vector{Spline}(undef, 12),
#     )
# end

function Spline(
    spline_type::SplineType,
    locations::Vector{Float32}=Float32[],
    derivatives::Vector{Float32}=Float32[],
    child_splines::Vector{Spline}=Spline[],
)
    return Spline(
        length(locations),
        spline_type,
        locations,
        derivatives,
        child_splines,
    )
end

mutable struct SplineStack
    stack::NTuple{42, Spline}
    fix_stack::NTuple{151, FixSpline}
    len::Int
    fix_len::Int
end

function Spline(spline_stack::SplineStack, val::Float32)
    sp = spline_stack.fix_stack[spline_stack.fix_len]
    spline_stack.fix_len += 1
    sp.len = 1
    return sp.val = val
end

function Base.push!(spline::Spline, location, derivative, child_spline)
    push!(spline.locations, location)
    push!(spline.derivatives, derivative)
    push!(spline.child_splines, child_spline)
    spline.len += 1
end

get_spline(sp::FixSpline) = sp.value

function findfirst_default(predicate::Function, A::T, default::T) where {T}
    for (i, a) in pairs(A)
        if predicate(a)
            return i
        end
    end
    return default
end

function get_spline(spline::Spline, values::Vector{Float32})
    if !(0 < spline.len < 12)
        throw(ArgumentError("Invalid spline length: $(spline.len)"))
    end

    #! we need f to be a Float32
    # it must already be the case because values is a Vector{Float32}
    f = values[Int(spline.spline_type) + 1]
    i = findfirst_default(>=(f), spline.locations, spline.len)

    # TODO: replace recursion with iteration because Julia doesn't optimize tail recursion
    if i == 1 || i == spline.len
        v = get_spline(spline.child_splines[i], values)
        return v + spline.derivatives[i] * (f - spline.locations[i])
    end

    child_spline_1 = spline.child_splines[i - 1]
    child_spline_2 = spline.child_splines[i]

    location_1 = spline.locations[i - 1]
    location_2 = spline.locations[i]

    derivative_1 = spline.derivatives[i - 1]
    derivative_2 = spline.derivatives[i]

    value_1 = get_spline(child_spline_1, values)
    value_2 = get_spline(child_spline_2, values)

    interpolation_factor = (f - location_1) / (location_2 - location_1)
    p = muladd(derivative_1, location_2 - location_1, value_1 - value_2)
    q = muladd(-derivative_2, location_2 - location_1, value_2 - value_1)
    # p = derivative_1 * (location_2 - location_1) - (value_2 - value_1)
    # q = -derivative_2 * (location_2 - location_1) + (value_2 - value_1)

    linear_interpolation = lerp(interpolation_factor, value_1, value_2)
    quadratic_interpolation =
        interpolation_factor * (1.0f0 - interpolation_factor) *
        lerp(interpolation_factor, p, q)
    return linear_interpolation + quadratic_interpolation
end

function get_offset_value(weirdness, continentalness)
    f1 = (continentalness - 1.0f0) * 0.5f0
    f0 = 1.0f0 + f1
    f2 = (weirdness + 1.17f0) * 0.46082947f0
    off = muladd(f0, f2, f1)
    if weirdness < -0.7f0
        return max(off, -0.2222f0)
    else
        return max(off, zero(off))
    end
end

#==========================================================================================#
# Biome Noise Structure
#==========================================================================================#

@eval TupleClimate = Tuple{
    $(
    [
    :(DoublePerlinNoise{length(amplitudes($i))}) for
    i in subtypes(NoiseParameter)
]...
),
}

# TODO: named tuple for climate ?
struct BiomeNoise{N} <: Noise
    climate::TupleClimate
    octaves::NTuple{2, OctaveNoise{N}}
    spline::Spline
    spline_stack::SplineStack
    noise_param_type::NoiseParameter
    version::MCVersion
end

function init_climate_seed!(
    octaves::NTuple{2, OctaveNoise{N}}, xlo::UInt64, xhi::UInt64, large::Bool, noise_param,
) where {N}
    xlo ⊻= magic_xlo(noise_param; large=large)
    xhi ⊻= magic_xhi(noise_param; large=large)
    return DoublePerlinNoise!🎲(
        JavaXoroshiro128PlusPlus(xlo, xhi),
        octaves[1],
        octaves[2],
        amplitudes(noise_param),
        octave_min(noise_param; large=large),
    )
end

function setseed!(bn::BiomeNoise, seed::Integer, large::Bool)
    climate = _biome_noise_climate(seed; large=large)
    for i in 1:NB_NOISE_PARAMETERS
        bn.climate[i] = climate[i]
    end
    return nothing
end

function BiomeNoise(mc_version::MCVersion)
    # TODO
end

@generated function _biome_noise_climate(seed::Integer; large::Bool=false)
    # little trick to avoid runtime dispatch: generate the tuple of expressions at compile time
    # and then execute them at runtime, with the correct noise_param
    climate_exprs = Expr[
        :(init_climate_seed(xlo, xhi, large, Val($t))) for t in instances(NoiseParameter)
    ]

    return quote
        rng = JavaXoroshiro128PlusPlus(seed)
        xlo = next🎲(rng, UInt64)
        xhi = next🎲(rng, UInt64)

        return ($(climate_exprs...),)
    end
end

function _create_spline_38219(f, bl)
    # spline = spline_stack.stack[sp
    # spline_stack.len += 1
    # spline.spline_type = SP_RIDGES
    spline_type = SP_RIDGES

    locations = Float32[]
    derivatives = Float32[]
    child_splines = Spline[]

    i = get_offset_value(-1.0f0, f)
    k = get_offset_value(1.0f0, f)
    u = 0.5f0 * (1.0f0 - f)
    l = u / (0.46082947f0 * (1 - u)) - 1.17f0

    if (-0.65 <= l <= 1)
        u = get_offset_value(-0.65f0, f)
        p = get_offset_value(-0.75f0, f)
        q = (p - i) * 4.0f0
        r = get_offset_value(l, f)
        s = (k - r) / (1.0f0 - l)

        push!(locations, -1.0f0, -0.75f0, -0.65f0, l - 0.01f0, l, 1.0f0)
        push!(derivatives, q, 0, 0, 0, s)

        # add_spline_val!(spline, -1.0f0, Spline(spline_stack, i), q)
        # add_spline_val!(spline, -0.75f0, Spline(spline_stack, p), 0)
        # add_spline_val!(spline, -0.65f0, Spline(spline_stack, u), 0)
        # add_spline_val!(spline, l - 0.01f0, Spline(spline_stack, r), 0)
        # add_spline_val!(spline, l, Spline(spline_stack, r), s)
        # add_spline_val!(spline, 1.0f0, Spline(spline_stack, k), s)
    else
        u = (k - i) * 0.5f0
        if bl
            add_spline_val!(spline, -1.0f0, Spline(spline_stack, max(i, 0.2)), 0)
            add_spline_val!(spline, 0.0f0, Spline(spline_stack, lerp(0.5f0, i, k)), u)
        else
            add_spline_val!(spline, -1.0f0, Spline(spline_stack, i), u)
        end
        add_spline_val!(spline, 1.0f0, Spline(spline_stack, k), u)
    end
    return spline
end

function create_offset_spline(ss::SplineStack, f, g, h, i, j, k)
    sp = ss.stack[ss.len]
    ss.len += 1
    sp.typ = SP_RIDGES

    l = 0.5f0 * (g - f)
    l < k && (l = k)
    m = 5.0f0 * (h - g)

    add_spline_val!(sp, -1.0f0, Spline(ss, f), l)
    add_spline_val!(sp, -0.4f0, Spline(ss, g), l < m ? l : m)
    add_spline_val!(sp, 0.0f0, Spline(ss, h), m)
    add_spline_val!(sp, 0.4f0, Spline(ss, i), 2.0f0 * (i - h))
    add_spline_val!(sp, 1.0f0, Spline(ss, j), 0.7f0 * (j - i))
    return sp
end

function create_land_spline(spline_stack::SplineStack, f, g, h, i, j, k, bl)
    sp1 = create_spline_38219(spline_stack, lerp(i, 0.6f0, 1.5f0), bl)
    sp2 = create_spline_38219(spline_stack, lerp(i, 0.6f0, 1.0f0), bl)
    sp3 = create_spline_38219(spline_stack, i, bl)
    ih = 0.5f0 * i
    sp4 = create_offset_spline(spline_stack, f - 0.15f0, ih, ih, ih, i * 0.6f0, 0.5f0)
    sp5 = create_offset_spline(spline_stack, f, j * i, g * i, ih, i * 0.6f0, 0.5f0)
    sp6 = create_offset_spline(spline_stack, f, j, j, g, h, 0.5f0)
    sp7 = create_offset_spline(spline_stack, f, j, j, g, h, 0.5f0)

    sp8 = spline_stack.stack[spline_stack.len]
    spline_stack.len += 1
    sp8.typ = SP_RIDGES
    add_spline_val!(sp8, -1.0f0, Spline(spline_stack, f), 0.0f0)
    add_spline_val!(sp8, -0.4f0, sp6, 0.0f0)
    add_spline_val!(sp8, 0.0f0, Spline(spline_stack, h + 0.07f0), 0.0f0)

    sp9 = create_offset_spline(spline_stack, -0.02f0, k, k, g, h, 0.0f0)

    sp = spline_stack.stack[spline_stack.len]
    spline_stack.len += 1
    sp.typ = SP_EROSION
    add_spline_val!(sp, -0.85f0, sp1, 0.0f0)
    add_spline_val!(sp, -0.7f0, sp2, 0.0f0)
    add_spline_val!(sp, -0.4f0, sp3, 0.0f)
    add_spline_val!(sp, -0.35f0, sp4, 0.0f)
    add_spline_val!(sp, -0.1f0, sp5, 0.0f)
    add_spline_val!(sp, 0.2f0, sp6, 0.0f)

    if bl
        add_spline_val!(sp, 0.4f0, sp7, 0.0f0)
        add_spline_val!(sp, 0.45f0, sp8, 0.0f0)
        add_spline_val!(sp, 0.55f0, sp8, 0.0f0)
        add_spline_val!(sp, 0.58f0, sp7, 0.0f0)
    end

    add_spline_val!(sp, 0.7f0, sp9, 0.0f0)
    return sp
end
