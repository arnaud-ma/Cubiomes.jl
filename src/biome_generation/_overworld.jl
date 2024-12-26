include("../utils.jl")
include("../constants.jl")

include("../random/rng.jl")
include("../random/noise.jl")

include("../mc_bugs.jl")
include("../biome_generation/infra.jl")

#==========================================================================================#
# Noise Parameters
#==========================================================================================#
using StaticArrays: SVector
using InteractiveUtils: subtypes
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

@only_float32 function get_offset_value(weirdness, continentalness)
    f1 = (continentalness - 1) * 0.5
    f0 = 1 + f1
    f2 = (weirdness + 1.17) * 0.46082947
    off = muladd(f0, f2, f1)
    weirdness < -0.7 && return max(off, -0.2222)
    return max(off, zero(off))
end

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
Base.trunc(::Type{SplineType}, x) = SplineType(trunc(Int, x))

struct Spline{N}
    spline_type::SplineType
    locations::NTuple{N, Float32}
    derivatives::NTuple{N, Float32}
    child_splines::NTuple{N, Spline}
end

Spline{0}(spline_type::SplineType) = Spline(spline_type, (), (), ())
Spline{0}(spline_type::SplineType, ::Tuple{}, ::Tuple{}, ::Tuple{}) = Spline{0}(spline_type)
Spline{0}(spline_value::Tuple) = Spline{0}(trunc(SplineType, spline_value))
# ^
# |
# if the parameter is not a SplineType, it can be a real number. Is is truncated to an Int
# and converted to its related spline_type. trunc instead of floor in order
# to mimic the Java behavior
Spline{0}(values...) = map(Spline{0}, values)

# we really need to constraint coeff to Float2 here otherwise we need to have a
# tuple full of Float32 and not of Float64
@only_float32 function spline_38219(coeff::Float32, bl::Val{BL}) where {BL}
    spline_type = SP_RIDGES
    offset_neg1 = get_offset_value(-1, coeff)
    offset_pos1 = get_offset_value(1, coeff)
    half_factor = 0.5 * (1 - coeff)
    λ = half_factor / (0.46082947 * (1 - half_factor)) - 1.17
    if -0.65 <= λ <= 1
        return spline_38219(spline_type, coeff, offset_pos1, offset_neg1, λ)
    end
    slope = (offset_pos1 - offset_neg1) / 0.46082947
    return spline_38219(spline_type, slope, offset_pos1, offset_neg1, bl)
end

@only_float32 function spline_38219(spline_type, coeff, offset_pos1, offset_neg1, λ::Real)
    offset_neg065 = get_offset_value(-0.65, coeff)
    offset_neg075 = get_offset_value(-0.75, coeff)
    scaled_diff = (offset_neg075 - offset_neg1) * 4
    offset_adjusted = get_offset_value(λ, coeff)
    slope = (offset_pos1 - offset_adjusted) / (1.0f0 - λ)

    return Spline(
        spline_type,
        (-1, -0.75, -0.65, λ - 0.01, λ, 1),
        (scaled_diff, 0, 0, 0, slope, slope),
        Spline{0}(
            offset_neg1,
            offset_neg075,
            offset_neg065,
            offset_adjusted,
            offset_adjusted,
            offset_pos1,
        ),
    )
end

@only_float32 function spline_38219(
    spline_type, slope, offset_pos1, offset_neg1, ::Val{true},
)
    return Spline(
        spline_type,
        (-1, 0, 1),
        (0, slope, slope),
        Spline{0}(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1), offset_pos1),
    )
end

@only_float32 function spline_38219(
    spline_type, slope, offset_pos1, offset_neg1, ::Val{false},
)
    return Spline(
        spline_type,
        (-1, 1),
        (slope, slope),
        Spline{0}(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1)),
    )
end

@only_float32 function flat_offset_spline(x₁, x₂, x₃, x₄, x₅, x₆)
    spline_type = SP_RIDGES
    x₇ = max(0.5 * (x₂ - x₁), x₆)
    x₈ = 5 * (x₃ - x₂)
    return Spline(
        spline_type,
        (-1, -0.4, 0, 0.4, 1),
        (x₇, min(x₇, x₈), x₈, 2 * (x₄ - x₃), 0.7 * (x₅ - x₄)),
        Spline{0}(x₁, x₂, x₃, x₄, x₅),
    )
end

@only_float32 function additional_values_land_spline(x₁, x₂, x₃, x₅, spline_6, ::Val{true})
    # add additional splines if bl is true
    spline_7 = flat_offset_spline(x₁, x₅, x₅, x₂, x₃, 0.5)
    spline_8 = Spline(
        SP_RIDGES,
        (-1.0, -0.4, 0),
        (0, 0, 0),
        (Spline{0}(x₁), spline_6, Spline{0}(x₃ + 0.07)),
    )

    locations = (0.4, 0.45, 0.55, 0.58)
    child_splines = (spline_7, spline_8, spline_8, spline_7)
    # 11 child splines if bl is true
    return locations, child_splines
end

additional_values_land_spline(x₁, x₂, x₃, x₅, spline_6, ::Val{false}) = (), ()

zeros_like(::NTuple{N, T}) where {N, T} = ntuple(i -> zero(T), Val{N}())

@only_float32 function land_spline(x₁, x₂, x₃, x₄, x₅, x₆, bl::Val{BL}) where {BL}
    # create initial splines with different linear interpolation values
    lerp_4_15 = lerp(x₄, 0.6, 1.5)
    lerp_4_1 = lerp(x₄, 0.6, 1.0)
    spline_1 = spline_38219(lerp_4_15, bl)
    spline_2 = spline_38219(lerp_4_1, bl)
    spline_3 = spline_38219(x₄, bl)

    # create flat offset splines
    half_i = 0.5 * x₄
    spline_4 = flat_offset_spline(x₁ - 0.15, half_i, half_i, half_i, x₄ * 0.6, 0.5)
    spline_5 = flat_offset_spline(x₁, x₅ * x₄, x₂ * x₄, half_i, x₄ * 0.6, 0.5)
    spline_6 = flat_offset_spline(x₁, x₅, x₅, x₂, x₃, 0.5)

    # Initialize locations and associated splines
    locations = (-0.85f0, -0.7f0, -0.4f0, -0.35f0, -0.1f0, 0.2f0)
    child_splines = (spline_1, spline_2, spline_3, spline_4, spline_5, spline_6)

    mid_loc, mid_splines = additional_values_land_spline(x₁, x₂, x₃, x₅, spline_6, bl)
    end_loc = 0.7
    end_spline = flat_offset_spline(-0.02, x₆, x₆, x₂, x₃, 0)

    locations = (locations..., mid_loc..., end_loc)
    child_splines = (child_splines..., mid_splines..., end_spline)
    derivatives = zeros_like(locations)

    # Create and return the final spline
    return Spline(SP_EROSION, locations, derivatives, child_splines)
end

function findfirst_default(predicate::Function, A, default)
    for (i, a) in pairs(A)
        if predicate(a)
            return i
        end
    end
    return default
end

# TODO: this is very type unstable and it is using recursion
# so not very julian. We should refactor everything to use
get_spline(spline::Spline{0}, vals) = Float32(Int(spline.spline_type))
function get_spline(spline::Spline{N}, vals::NTuple{N2, T}) where {N, N2, T}
    if !((1 <= Int(spline.spline_type) <= 4) && (1 <= N <= 11))
        throw(
            ArgumentError(
            lazy"getSpline(): bad parameters (spline_type: $(spline.spline_type), N: $N)",
        ),
        )
    end

    f = vals[Int(spline.spline_type)]
    i = findfirst_default(>=(f), spline.locations, N)
    if i == 1.0f0 || i == N
        loc, der, sp = spline.locations[i], spline.derivatives[i], spline.child_splines[i]
        v = get_spline(sp, vals)
        return muladd(der, f - loc, v)
    end

    spline_1 = spline.child_splines[i - 1]
    spline_2 = spline.child_splines[i]

    g = spline.locations[i - 1]
    h = spline.locations[i]

    k = (f - g) / (h - g)

    l = spline.derivatives[i - 1]
    m = spline.derivatives[i]

    n = get_spline(spline_1, vals)
    o = get_spline(spline_2, vals)

    p = l * (h - g) - (o - n)
    q = -m * (h - g) + (o - n)

    r = lerp(k, n, o) + k * (1.0 - k) * lerp(k, p, q)
    return r
end
