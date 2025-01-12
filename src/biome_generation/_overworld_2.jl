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

abstract type NoiseParameter end

# only here to help the editor, poor baby :(
amplitudes(::NoiseParameter) = throw(MethodError(amplitudes, (NoiseParameter,)))
function octave_min(::NoiseParameter, large)
    throw(MethodError(octave_min, (NoiseParameter, typeof(large))))
end
id(::NoiseParameter, large) = throw(MethodError(id, (NoiseParameter, typeof(large))))
function filtered_amplitudes(::NoiseParameter)
    throw(MethodError(filtered_amplitudes, (NoiseParameter,)))
end
nb_octaves(::NoiseParameter) = throw(MethodError(nb_octaves, (NoiseParameter,)))
nb_trimmed(::NoiseParameter) = throw(MethodError(nb_trimmed, (NoiseParameter,)))
function create_octaves(::NoiseParameter, Val{N}) where {N}
    throw(MethodError(create_octaves, (NoiseParameter, Val{N})))
end
function magic_xlo(::NoiseParameter, large)
    throw(MethodError(magic_xlo, (NoiseParameter, typeof(large))))
end
function magic_xhi(::NoiseParameter, large)
    throw(MethodError(magic_xhi, (NoiseParameter, typeof(large))))
end

macro create_noise_param(noise_param, amp, oct, id_str, oct_large)
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

    xlo, xhi = Utils.md5_to_uint64(id_str)
    xlo_large, xh_large = Utils.md5_to_uint64(id_str_large)

    return quote
        amplitudes(::Type{noise_param}) = $(float.(amp))
        octave_min(::Type{noise_param}, ::Val{false}) = $(float(oct))
        octave_min(::Type{noise_param}, ::Val{true}) = $(float(oct_large))
        id(::Type{noise_param}::Val{false}) = $id_str
        id(::Type{noise_param}, ::Val{true}) = $id_str_large
        filtered_amplitudes(::Type{noise_param}) = $(float.(filtered_amp))
        nb_octaves(::Type{noise_param}) = $(float(nb_octaves))
        nb_trimmed(::Type{noise_param}) = $(float(nb_trimmed))
        magic_xlo(::Type{noise_param}, ::Val{false}) = $xlo
        magic_xhi(::Type{noise_param}, ::Val{false}) = $xhi
        magic_xlo(::Type{noise_param}, ::Val{true}) = $xlo_large
        magic_xhi(::Type{noise_param}, ::Val{true}) = $xh_large

        function create_octaves(::Type{noise_param}, Val{N}) where {N}
            ntuple(i -> Octaves{nb}(undef), Val(N))
        end
    end
end

struct Shift <: NoiseParameter end
@create_noise_param(Shift, (1, 1, 1, 0), 0, "minecraft:offset", nothing)

struct Temperature <: NoiseParameter end
@create_noise_param(Temperature, (1.5, 0, 1, 0, 0, 0), -10, "minecraft:temperature", -12)

struct Humidity <: NoiseParameter end
@create_noise_param(Humidity, (1, 1, 0, 0, 0, 0), -8, "minecraft:vegetation", -10)

#! format: off
struct Continentalness <: NoiseParameter end
@create_noise_param(Continentalness, (1, 1, 2, 2, 2, 1, 1, 1, 1), -9, "minecraft:continentalness", -11)
#! format: on

struct Erosion <: NoiseParameter end
@create_noise_param(Erosion, (1, 1, 0, 1, 1), -9, "minecraft:erosion", -11)

struct Weirdness <: NoiseParameter end
@create_noise_param(Weirdness, (1, 2, 1, 0, 0, 0), -7, "minecraft:ridge", nothing)

const NOISE_PARAMETERS = Tuple(subtypes(NoiseParameter))

@eval const TypeTupleClimate =
    Tuple{$((:(DoublePerlin{$(nb_octaves(np))}) for np in NOISE_PARAMETERS)...)}
struct BiomeNoise <: Dimension
    climate::TypeTupleClimate
end

function BiomeNoise(::UndefInitializer)
    BiomeNoise(Tuple(Noise(
        DoublePerlin{np.nb_octaves},
        undef,
        np.nb_trimmed,
    ) for np in NOISE_PARAMETERS))
end

# we need some methods to be able to dispatch at compile time wether large is true or false
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

    mid_locs, mid_splines = additional_values_land_spline(x1, x2, x3, x5, spline_6, bl)
    end_loc, end_spline = 0.7, flat_offset_spline(-0.02, x6, x6, x2, x3, 0)

    locations = (locations..., mid_locs..., end_loc)
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
function get_spline(spline::Spline{N}, vals::NTuple{N2}) where {N, N2}
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

# void initBiomeNoise(BiomeNoise *bn, int mc)
# {
#     SplineStack *ss = &bn->ss;
#     memset(ss, 0, sizeof(*ss));
#     Spline *sp = &ss->stack[ss->len++];
#     sp->typ = SP_CONTINENTALNESS;

#     Spline *sp1 = createLandSpline(ss, -0.15F, 0.00F, 0.0F, 0.1F, 0.00F, -0.03F, 0);
#     Spline *sp2 = createLandSpline(ss, -0.10F, 0.03F, 0.1F, 0.1F, 0.01F, -0.03F, 0);
#     Spline *sp3 = createLandSpline(ss, -0.10F, 0.03F, 0.1F, 0.7F, 0.01F, -0.03F, 1);
#     Spline *sp4 = createLandSpline(ss, -0.05F, 0.03F, 0.1F, 1.0F, 0.01F,  0.01F, 1);

#     addSplineVal(sp, -1.10F, createFixSpline(ss,  0.044F), 0.0F);
#     addSplineVal(sp, -1.02F, createFixSpline(ss, -0.2222F), 0.0F);
#     addSplineVal(sp, -0.51F, createFixSpline(ss, -0.2222F), 0.0F);
#     addSplineVal(sp, -0.44F, createFixSpline(ss, -0.12F), 0.0F);
#     addSplineVal(sp, -0.18F, createFixSpline(ss, -0.12F), 0.0F);
#     addSplineVal(sp, -0.16F, sp1, 0.0F);
#     addSplineVal(sp, -0.15F, sp1, 0.0F);
#     addSplineVal(sp, -0.10F, sp2, 0.0F);
#     addSplineVal(sp,  0.25F, sp3, 0.0F);
#     addSplineVal(sp,  1.00F, sp4, 0.0F);

#     bn->sp = sp;
#     bn->mc = mc;
# }

@only_float32 function initBiomeNoise(bn::BiomeNoise)
    spline1 = land_spline(-0.15, 0, 0, 0.1, 0, -0.03, Val(false))
    spline2 = land_spline(-0.10, 0.03, 0.1, 0.1, 0.01, -0.03, Val(false))
    spline3 = land_spline(-0.10, 0.03, 0.1, 0.7, 0.01, -0.03, Val(true))
    spline4 = land_spline(-0.05, 0.03, 0.1, 1.0, 0.01, 0.01, Val(true))

    locations = (-1.10, -1.02, -0.51, -0.44, -0.18, -0.16, -0.15, -0.10, 0.25, 1.00)
    child_splines = (
        Spline{0}(0.044),
        Spline{0}(-0.2222),
        Spline{0}(-0.2222),
        Spline{0}(-0.12),
        Spline{0}(-0.12),
        spline1,
        spline1,
        spline2,
        spline3,
        spline4,
    )
    derivatives = zeros_like(locations)

    return Spline(Continentalness, locations, derivatives, child_splines)
end

# int sampleBiomeNoise(const BiomeNoise *bn, int64_t *np, int x, int y, int z,
#     uint64_t *dat, uint32_t sample_flags)
# {
#     if (bn->nptype >= 0)
#     {   // initialized for a specific climate parameter
#         if (np)
#             memset(np, 0, NP_MAX*sizeof(*np));
#         int64_t id = (int64_t) (10000.0 * sampleClimatePara(bn, np, x, z));
#         return (int) id;
#     }

#     float t = 0, h = 0, c = 0, e = 0, d = 0, w = 0;
#     double px = x, pz = z;
#     if (!(sample_flags & SAMPLE_NO_SHIFT))
#     {
#         px += sampleDoublePerlin(&bn->climate[NP_SHIFT], x, 0, z) * 4.0;
#         pz += sampleDoublePerlin(&bn->climate[NP_SHIFT], z, x, 0) * 4.0;
#     }

#     c = sampleDoublePerlin(&bn->climate[NP_CONTINENTALNESS], px, 0, pz);
#     e = sampleDoublePerlin(&bn->climate[NP_EROSION], px, 0, pz);
#     w = sampleDoublePerlin(&bn->climate[NP_WEIRDNESS], px, 0, pz);

#     if (!(sample_flags & SAMPLE_NO_DEPTH))
#     {
#         float np_param[] = {
#             c, e, -3.0F * ( fabsf( fabsf(w) - 0.6666667F ) - 0.33333334F ), w,
#         };
#         double off = getSpline(bn->sp, np_param) + 0.015F;

#         //double py = y + sampleDoublePerlin(&bn->shift, y, z, x) * 4.0;
#         d = 1.0 - (y * 4) / 128.0 - 83.0/160.0 + off;
#     }

#     t = sampleDoublePerlin(&bn->climate[NP_TEMPERATURE], px, 0, pz);
#     h = sampleDoublePerlin(&bn->climate[NP_HUMIDITY], px, 0, pz);

#     int64_t l_np[6];
#     int64_t *p_np = np ? np : l_np;
#     p_np[0] = (int64_t)(10000.0F*t);
#     p_np[1] = (int64_t)(10000.0F*h);
#     p_np[2] = (int64_t)(10000.0F*c);
#     p_np[3] = (int64_t)(10000.0F*e);
#     p_np[4] = (int64_t)(10000.0F*d);
#     p_np[5] = (int64_t)(10000.0F*w);

#     int id = none;
#     if (!(sample_flags & SAMPLE_NO_BIOME))
#         id = climateToBiome(bn->mc, (const uint64_t*)p_np, dat);
#     return id;
# }

# function sample_biome(bn::BiomeNoise, )
