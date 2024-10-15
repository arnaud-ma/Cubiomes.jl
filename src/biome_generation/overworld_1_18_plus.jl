using MD5: md5

#==========================================================================================#
# Noise Parameters
#==========================================================================================#
# ? Types instead of enums?
# abstract type NoiseParameter end

@enum NoiseParameter begin
    NP_SHIFT
    NP_TEMPERATURE
    NP_HUMIDITY
    NP_CONTINENTALNESS
    NP_EROSION
    NP_WEIRDNESS
end

const NB_NOISE_PARAMETERS = length(instances(NoiseParameter))

amplitudes(noise_param::Val{NP_SHIFT}) = (1, 1, 1, 0)
octave_min(noise_param::Val{NP_SHIFT}; large::Bool) = -3
id(noise_param::Val{NP_SHIFT}; large::Bool) = "minecraft:offset"

amplitudes(noise_param::Val{NP_TEMPERATURE}) = (1.5, 0.0, 1.0, 0.0, 0.0, 0.0)
octave_min(noise_param::Val{NP_TEMPERATURE}; large::Bool) = large ? -12 : -10
function id(noise_param::Val{NP_TEMPERATURE}; large::Bool)
    return large ? "minecraft:temperature_large" : "minecraft:temperature"
end

amplitudes(noise_param::Val{NP_HUMIDITY}) = (1, 1, 0, 0, 0, 0)
octave_min(noise_param::Val{NP_HUMIDITY}; large::Bool) = large ? -10 : -8
function id(noise_param::Val{NP_HUMIDITY}; large::Bool)
    return large ? "minecraft:vegetation_large" : "minecraft:vegetation"
end

amplitudes(noise_param::Val{NP_CONTINENTALNESS}) = (1, 1, 2, 2, 2, 1, 1, 1, 1)
octave_min(noise_param::Val{NP_CONTINENTALNESS}; large::Bool) = large ? -11 : -9
function id(noise_param::Val{NP_CONTINENTALNESS}; large::Bool)
    return large ? "minecraft:continentalness_large" : "minecraft:continentalness"
end

amplitudes(noise_param::Val{NP_EROSION}) = (1, 1, 0, 1, 1)
octave_min(noise_param::Val{NP_EROSION}; large::Bool) = large ? -11 : -9
function id(noise_param::Val{NP_EROSION}; large::Bool)
    return large ? "minecraft:erosion_large" : "minecraft:erosion"
end

amplitudes(noise_param::Val{NP_WEIRDNESS}) = (1, 2, 1, 0, 0, 0)
octave_min(noise_param::Val{NP_WEIRDNESS}; large::Bool) = -7
id(noise_param::Val{NP_WEIRDNESS}; large::Bool) = "minecraft:ridge"

for noise_param in instances(NoiseParameter)
    xlo, xhi = md5_to_uint64(id(Val(noise_param); large=false))
    xlo_large, xh_large = md5_to_uint64(id(Val(noise_param); large=true))

    @eval magic_xlo(noise_param::Val{$noise_param}; large::Bool) = large ? $xlo_large : $xlo
    @eval magic_xhi(noise_param::Val{$noise_param}; large::Bool) = large ? $xh_large : $xhi
end

#==========================================================================================#
# Splines
#==========================================================================================#

@enum SplineType begin
    SP_CONTINENTALNESS
    SP_EROSION
    SP_RIDGES
    SP_WEIRDNESS
end

mutable struct Spline
    len::Int
    typ::SplineType
    loc::Vector{Float32}
    der::Vector{Float32}
    val::Vector{Spline}
end

struct FixSpline
    len::Int
    val::Float32
end

function Spline(len::Int, typ::SplineType)
    return Spline(
        len,
        typ,
        Vector{Float32}(undef, 12),
        Vector{Float32}(undef, 12),
        Vector{Spline}(undef, 12),
    )
end

mutable struct SplineStack
    stack::NTuple{42,Spline}
    fix_stack::NTuple{151,FixSpline}
    len::Int
    fix_len::Int
end

function Spline(ss::SplineStack, val::Float32)
    sp = ss.fix_stack[ss.fix_len]
    ss.fix_len += 1
    sp.len = 1
    return sp.val = val
end

function get_spline(sp::Spline, values::Vector)
    if !(0 < sp.len < 12)
        throw(ArgumentError("Invalid spline length: $(sp.len)"))
    end
    if sp.len == 1
        return sp.typ
    end

    f::Float32 = values[Int(sp.typ) + 1]

    i = zero(Int)
    for outer i in 1:(sp.len)
        if sp.loc[i] >= f
            break
        end
    end
    findfirst
    # TODO: replace recursion with iteration because Julia doesn't optimize tail recursion
    if i == 1 || i == (sp.len - 1)
        if i != 1
            i -= 1
        end
        v = get_spline(sp.val[i], values)
        return v + sp.der[i] * (f - sp.loc[i])
    end

    sp1 = sp.val[i - 1]
    sp2 = sp.val[i]
    g = sp.loc[i - 1]
    h = sp.loc[i]
    k = (f - g) / (h - g)
    l = sp.der[i - 1]
    m = sp.der[i]
    n = get_spline(sp1, values)
    o = get_spline(sp2, values)
    p = l * (h - g) - (o - n)
    q = -m * (h - g) + (o - n)
    r = lerp(k, n, o) + k * (1.0f0 - k) * lerp(k, p, q)
    return r
end

function get_offset_value(weirdness, continentalness)
    f1 = (continentalness - 1.0f0) * 0.5f0
    f0 = 1.0f0 + f1
    f2 = (weirdness + 1.17f0) * 0.46082947f0
    off = muladd(f0, f2, f1)
    if weirdness < -0.7f0
        return max(off, -0.2222f0)
    else
        return max(off, 0.0f0)
    end
end

#==========================================================================================#
# Biome Noise Structure
#==========================================================================================#

@eval TupleClimate = Tuple{
    $(
        [
            :(DoublePerlinNoise{length(amplitudes(Val($i)))}) for
            i in instances(NoiseParameter)
        ]...
    ),
}

# TODO: named tuple for climate ?
struct BiomeNoise{N} <: Noise
    climate::TupleClimate
    octaves::NTuple{2,OctaveNoise{N}}
    spline::Spline
    spline_stack::SplineStack
    noise_param_type::NoiseParameter
    version::MCVersion
end

function init_climate_seed!(
    octaves::NTuple{2,OctaveNoise{N}}, xlo::UInt64, xhi::UInt64, large::Bool, noise_param
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

function add_spline_val!(rsp::Spline, loc, val::Spline, der)
    rsp.loc[rsp.len] = loc
    rsp.val[rsp.len] = val
    rsp.der[rsp.len] = der
    rsp.len += 1
    return nothing
end

function create_spline_38219(ss::SplineStack, f, bl)
    sp = ss.stack[ss.len]
    ss.len += 1
    sp.typ = SP_RIDGES

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

        add_spline_val!(sp, -1.0f0, Spline(ss, i), q)
        add_spline_val!(sp, -0.75f0, Spline(ss, p), 0)
        add_spline_val!(sp, -0.65f0, Spline(ss, u), 0)
        add_spline_val!(sp, l - 0.01f0, Spline(ss, r), 0)
        add_spline_val!(sp, l, Spline(ss, r), s)
        add_spline_val!(sp, 1.0f0, Spline(ss, k), s)
    else
        u = (k - i) * 0.5f0
        if bl
            add_spline_val!(sp, -1.0f0, Spline(ss, max(i, 0.2)), 0)
            add_spline_val!(sp, 0.0f0, Spline(ss, lerp(0.5f0, i, k)), u)
        else
            add_spline_val!(sp, -1.0f0, Spline(ss, i), u)
        end
        add_spline_val!(sp, 1.0f0, Spline(ss, k), u)
    end
    return sp
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
