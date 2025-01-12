# include("../biome_generation/interface.jl")
# include("../noises/Noises.jl")
# include("../rng.jl")
# include("../utils.jl")

using StaticArrays: SVector
using InteractiveUtils: subtypes

using ..Utils: Utils, @only_float32, md5_to_uint64
using ..JavaRNG: JavaXoroshiro128PlusPlus, next🎲
using ..Noises

#region Noise Parameters
# ---------------------------------------------------------------------------- #
#                               Noise Parameters                               #
# ---------------------------------------------------------------------------- #

const _DATA_NOISE_PARAM = Dict(
    :shift => (amp=(1, 1, 1, 0), oct=-3, id="minecraft:offset", large=nothing),
    :temperature => (
        amp=(1.5, 0.0, 1.0, 0.0, 0.0, 0.0),
        oct=-10,
        id="minecraft:temperature",
        large=-12,
    ),
    :humidity =>
        (amp=(1, 1, 0, 0, 0, 0), oct=-8, id="minecraft:vegetation", large=-10),
    :CONTINENTALNESS_continentalness => (
        amp=(1, 1, 2, 2, 2, 1, 1, 1, 1),
        oct=-9,
        id="minecraft:continentalness",
        large=-11,
    ),
    :NP_EROSION => (amp=(1, 1, 0, 1, 1), oct=-9, id="minecraft:erosion", large=-11),
    :NP_WEIRDNESS =>
        (amp=(1, 2, 1, 0, 0, 0), oct=-7, id="minecraft:ridge", large=nothing),
)

function create_noise_param(amp, oct, id_str, oct_large)
    filtered_amp = filter(!iszero, amp)
    nb_octaves = length(filtered_amp)
    nb_trimmed = Utils.length_of_trimmed(iszero, amp)

    if isnothing(oct_large)
        oct_large = oct
        id_str_large = id_str
    else
        oct_large = oct_large
        id_str_large = "$(id_str)_large"
    end

    create_octaves(nb::Val{N}) where {N} = ntuple(i -> Octaves{nb}(undef), Val(N))
    xlo, xhi = md5_to_uint64(id_str)
    xlo_large, xh_large = md5_to_uint64(id_str_large)

    return (
        amplitudes=float.(amp),
        octave_min=float(oct),
        octave_min_large=float(oct_large),
        id=id_str,
        id_large=id_str_large,
        filtered_amplitudes=float.(filtered_amp),
        nb_octaves=float(nb_octaves),
        nb_trimmed=float(nb_trimmed),
        create_octaves=create_octaves,
        magic_xlo=xlo,
        magic_xhi=xhi,
        magic_xlo_large=xlo_large,
        magic_xhi_large=xh_large,
    )
end

const RAW_NOISE_PARAMETERS = (
    (shift=((1, 1, 1, 0), -3, "minecraft:offset", nothing),
    temperature=((1.5, 0, 1, 0, 0, 0), -10, "minecraft:temperature", -12),
    humidity=((1, 1, 0, 0, 0, 0), -8, "minecraft:vegetation", -10),
    continentalness=(
        (1, 1, 2, 2, 2, 1, 1, 1, 1),
        -9,
        "minecraft:continentalness",
        -11,
    ),
    erosion=((1, 1, 0, 1, 1), -9, "minecraft:erosion", -11),
    weirdness=((1, 2, 1, 0, 0, 0), -7, "minecraft:ridge", nothing),
)
)
const NOISE_PARAMETERS = map(x -> create_noise_param(x...), RAW_NOISE_PARAMETERS)

@eval TupleClimate = Tuple{$((:(DoublePerlin{$i.nb_octaves}) for i in NOISE_PARAMETERS)...)}

struct BiomeNoise <: Dimension
    climate::TupleClimate
end

function BiomeNoise(::UndefInitializer)
    BiomeNoise(Tuple(Noise(
        DoublePerlin{np.nb_octaves},
        undef,
        np.nb_trimmed,
    ) for np in NOISE_PARAMETERS))
end

for func in (:magic_xlo, :magic_xhi, :octave_min)
    @eval $func(x, ::Val{true}) = x.$(func)_large
    @eval $func(x, ::Val{false}) = x.$func
end

function set_seed!(
    dp::DoublePerlin, xlo, xhi, noise_param, large=Val(true),
)
    xlo ⊻= magic_xhi(noise_param, large)
    xhi ⊻= magic_xhi(noise_param, large)
    rng = JavaXoroshiro128PlusPlus(xlo, xhi)
    set_rng!🎲(dp, rng, noise_param.filtered_amplitudes, octave_min(noise_param, large))
    return nothing
end

function set_seed!(noise::BiomeNoise, seed::UInt64, large=Val(true))
    rng = JavaXoroshiro128PlusPlus(seed)
    xlo = next🎲(rng, UInt64)
    xhi = next🎲(rng, UInt64)

    for (clim, noise_param) in zip(noise.climate, NOISE_PARAMETERS)
        set_seed!(clim, xlo, xhi, noise_param, large)
    end
    return noise
end
#endregion
#region Splines

# ---------------------------------------------------------------------------- #
#                                    Splines                                   #
# ---------------------------------------------------------------------------- #

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

struct Spline{N, T}
    spline_type::SplineType
    locations::NTuple{N, Float32}
    derivatives::NTuple{N, Float32}
    child_splines::T
end

Spline{0}(spline_type::SplineType) = Spline(spline_type, (), (), ())
Spline{0}(spline_type::SplineType, ::Tuple{}, ::Tuple{}, ::Tuple{}) = Spline{0}(spline_type)
Spline{0}(spline_value::Real) = Spline{0}(trunc(SplineType, spline_value))
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
        Spline{0}(
            max(offset_neg1, 0.2),
            Utils.lerp(0.5, offset_neg1, offset_pos1),
            offset_pos1,
        ),
    )
end

@only_float32 function spline_38219(
    spline_type, slope, offset_pos1, offset_neg1, ::Val{false},
)
    return Spline(
        spline_type,
        (-1, 1),
        (slope, slope),
        Spline{0}(max(offset_neg1, 0.2), Utils.lerp(0.5, offset_neg1, offset_pos1)),
    )
end

@only_float32 function flat_offset_spline(x1, x2, x3, x4, x5, x6)
    spline_type = SP_RIDGES
    x₇ = max(0.5 * (x2 - x1), x6)
    x₈ = 5 * (x3 - x2)
    return Spline(
        spline_type,
        (-1, -0.4, 0, 0.4, 1),
        (x₇, min(x₇, x₈), x₈, 2 * (x4 - x3), 0.7 * (x5 - x4)),
        Spline{0}(x1, x2, x3, x4, x5),
    )
end

@only_float32 function additional_values_land_spline(x1, x2, x3, x5, spline_6, ::Val{true})
    # add additional splines if bl is true
    spline_7 = flat_offset_spline(x1, x5, x5, x2, x3, 0.5)
    spline_8 = Spline(
        SP_RIDGES,
        (-1.0, -0.4, 0),
        (0, 0, 0),
        (Spline{0}(x1), spline_6, Spline{0}(x3 + 0.07)),
    )

    locations = (0.4, 0.45, 0.55, 0.58)
    child_splines = (spline_7, spline_8, spline_8, spline_7)
    # 11 child splines if bl is true
    return locations, child_splines
end

additional_values_land_spline(x1, x2, x3, x5, spline_6, ::Val{false}) = (), ()

#! This produce a false positive with Aqua.jl. See https://github.com/JuliaTesting/Aqua.jl/issues/86
# upstream julia issue: https://github.com/JuliaLang/julia/issues/28086
zeros_like(::NTuple{N, T}) where {N, T} = ntuple(i -> zero(T), Val{N}())
zeros_like(x::Tuple{}) = x

@only_float32 function land_spline(x1, x2, x3, x4, x5, x6, bl::Val{BL}) where {BL}
    # create initial splines with different linear interpolation values
    lerp_4_15 = Utils.lerp(x4, 0.6, 1.5)
    lerp_4_1 = Utils.lerp(x4, 0.6, 1.0)
    spline_1 = spline_38219(lerp_4_15, bl)
    spline_2 = spline_38219(lerp_4_1, bl)
    spline_3 = spline_38219(x4, bl)

    # create flat offset splines
    half_i = 0.5 * x4
    spline_4 = flat_offset_spline(x1 - 0.15, half_i, half_i, half_i, x4 * 0.6, 0.5)
    spline_5 = flat_offset_spline(x1, x5 * x4, x2 * x4, half_i, x4 * 0.6, 0.5)
    spline_6 = flat_offset_spline(x1, x5, x5, x2, x3, 0.5)

    # Initialize locations and associated splines
    locations = (-0.85f0, -0.7f0, -0.4f0, -0.35f0, -0.1f0, 0.2f0)
    child_splines = (spline_1, spline_2, spline_3, spline_4, spline_5, spline_6)

    mid_loc, mid_splines = additional_values_land_spline(x1, x2, x3, x5, spline_6, bl)
    end_loc = 0.7
    end_spline = flat_offset_spline(-0.02, x6, x6, x2, x3, 0)

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

function get_spline(spline::Spline{0}, vals::NTuple{N2}) where {N2}
    Float32(Int(spline.spline_type))
end

# TODO: transform the recursive to an iterate one, since Julia is very bad with recursion :(
function _get_spline(spline::Spline{N}, vals::NTuple{N2}) where {N, N2}
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

    r = Utils.lerp(k, n, o) + k * (1.0 - k) * Utils.lerp(k, p, q)
    return r
end
