include("../biome_generation/infra.jl")

#region Noise Parameters
# ---------------------------------------------------------------------------- #
#                               Noise Parameters                               #
# ---------------------------------------------------------------------------- #
using StaticArrays: SVector
using InteractiveUtils: subtypes

abstract type NoiseParameter end

struct NP_SHIFT <: NoiseParameter end
struct NP_TEMPERATURE <: NoiseParameter end
struct NP_HUMIDITY <: NoiseParameter end
struct NP_CONTINENTALNESS <: NoiseParameter end
struct NP_EROSION <: NoiseParameter end
struct NP_WEIRDNESS <: NoiseParameter end

const NOISE_PARAMETERS = Tuple(subtypes(NoiseParameter))
const NB_NOISE_PARAMETERS = length(NOISE_PARAMETERS)

# only here for documentation purposes
# functions are created "dynamically" in the next block, using the _DATA dictionary
function amplitudes(noise_param::Type{NoiseParameter}) end
function octave_min(noise_param::Type{NoiseParameter}, large::Val) end
function id(noise_param::Type{NoiseParameter}, large::Val) end
function magic_xlo(noise_param::Type{NoiseParameter}, large::Val) end
function magic_xhi(noise_param::Type{NoiseParameter}, large::Val) end

const _DATA_NOISE_PARAM = Dict(
    NP_SHIFT => (amp=(1, 1, 1, 0), oct=-3, id="minecraft:offset", large=nothing),
    NP_TEMPERATURE => (
        amp=(1.5, 0.0, 1.0, 0.0, 0.0, 0.0),
        oct=-10,
        id="minecraft:temperature",
        large=-12,
    ),
    NP_HUMIDITY => (amp=(1, 1, 0, 0, 0, 0), oct=-8, id="minecraft:vegetation", large=-10),
    NP_CONTINENTALNESS => (
        amp=(1, 1, 2, 2, 2, 1, 1, 1, 1),
        oct=-9,
        id="minecraft:continentalness",
        large=-11,
    ),
    NP_EROSION => (amp=(1, 1, 0, 1, 1), oct=-9, id="minecraft:erosion", large=-11),
    NP_WEIRDNESS => (amp=(1, 2, 1, 0, 0, 0), oct=-7, id="minecraft:ridge", large=nothing),
)

@assert Set(keys(_DATA_NOISE_PARAM)) == Set(NOISE_PARAMETERS)

for (noise_param, (amp, oct, id_str, oct_large)) in _DATA_NOISE_PARAM
    @eval amplitudes(noise_param::Type{$noise_param}) = $amp
    @eval octave_min(noise_param::Type{$noise_param}, large::Val{false}) = $oct
    @eval id(noise_param::Type{$noise_param}, large::Val{false}) = $id_str

    if isnothing(oct_large)
        @eval octave_min(noise_param::Type{$noise_param}, large::Val{true}) = $oct
        @eval id(noise_param::Type{$noise_param}, large::Val{true}) = $id_str
    else
        @eval octave_min(noise_param::Type{$noise_param}, large::Val{true}) = $oct_large
        @eval id(noise_param::Type{$noise_param}, large::Val{true}) = $(id_str * "_large")
    end

    filtered_amp = filter(!iszero, amp)
    nb_octaves_ = length(filtered_amp)
    @eval filtered_amplitudes(noise_param::Type{$noise_param}) = $filtered_amp
    @eval nb_octaves(noise_param::Type{$noise_param}) = $nb_octaves_
    @eval function create_octaves(noise_param::Type{$noise_param}, nb::Val{N}) where {N}
        return ntuple(i -> Octaves{$nb_octaves_}(undef), Val(N))
    end
    xlo, xhi = md5_to_uint64(id(noise_param, Val(false)))
    xlo_large, xh_large = md5_to_uint64(id(noise_param, Val(true)))
    @eval magic_xlo(noise_param::Type{$noise_param}, large::Val{true}) = $xlo_large
    @eval magic_xhi(noise_param::Type{$noise_param}, large::Val{true}) = $xh_large
    @eval magic_xlo(noise_param::Type{$noise_param}, large::Val{false}) = $xlo
    @eval magic_xhi(noise_param::Type{$noise_param}, large::Val{false}) = $xhi
end

@eval TupleClimate = Tuple{
    $((:(DoublePerlin{nb_octaves($i)}) for i in NOISE_PARAMETERS)...)
}

struct BiomeNoise <: Dimension
    climate::TupleClimate
end

function BiomeNoise(::UndefInitializer)
    return BiomeNoise(
        Tuple(
            Noise(
                DoublePerlin{nb_octaves(np)},
                    undef, length_of_trimmed(amplitudes(np), iszero)
                ) for np in NOISE_PARAMETERS
            ),
        )
end

function set_seed!(
    dp::DoublePerlin, xlo, xhi, noise_param, large=Val(true)
)
    xlo ⊻= magic_xlo(noise_param, large)
    xhi ⊻= magic_xhi(noise_param, large)
    rng = JavaXoroshiro128PlusPlus(xlo, xhi)
    set_rng!🎲(dp, rng, filtered_amplitudes(noise_param), octave_min(noise_param, large))
    return nothing
end

function set_seed!(noise::BiomeNoise, seed::UInt64, large=Val(true))
    climate = noise.climate
    rng = JavaXoroshiro128PlusPlus(seed)
    xlo = next🎲(rng, UInt64)
    xhi = next🎲(rng, UInt64)

    for i in 1:NB_NOISE_PARAMETERS
        set_seed!(climate[i], xlo, xhi, NOISE_PARAMETERS[i], large)
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

struct Spline{N,T}
    spline_type::SplineType
    locations::NTuple{N,Float32}
    derivatives::NTuple{N,Float32}
    child_splines::T
end

function Spline{0}(spline_type::SplineType)
    return Spline(spline_type, (), (), ())
end
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
    spline_type, slope, offset_pos1, offset_neg1, ::Val{true}
)
    return Spline(
        spline_type,
        (-1, 0, 1),
        (0, slope, slope),
        Spline{0}(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1), offset_pos1),
    )
end

@only_float32 function spline_38219(
    spline_type, slope, offset_pos1, offset_neg1, ::Val{false}
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

function additional_values_land_spline(x₁, x₂, x₃, x₅, spline_6, ::Val{false})
    return (), ()
end

zeros_like(::NTuple{N,T}) where {N,T} = ntuple(i -> zero(T), Val{N}())

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

function get_spline(spline::Spline{0}, vals::NTuple{N2,T}) where {N2,T}
    Float32(Int(spline.spline_type))
end

# TODO: transform the recursive to an iterate one, since Julia is very bad with recursion :(
function get_spline(spline::Spline{N}, vals::NTuple{N2,T}) where {N,N2,T}
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

# function get_spline_iterative(spline::Spline{N}, vals::NTuple{N2,T}) where {N,N2,T}
#     # Base case for invalid parameters
#     if !((1 <= Int(spline.spline_type) <= 4) && (0 <= N <= 11))
#         throw(
#             ArgumentError(
#                 "getSpline(): bad parameters (spline_type: $(spline.spline_type), N: $N)"
#             ),
#         )
#     end

#     # Handle the case where N == 0 directly
#     if N == 0
#         return Float32(Int(spline.spline_type))
#     end

#     f = vals[Int(spline.spline_type)]
#     state_stack = ((spline, f, :start),)  # Stack to simulate recursion: (spline, f, state)
#     result_stack = ()  # To store intermediate results during processing

#     while !isempty(state_stack)
#         # Pop the current state
#         current_state, state_stack = first(state_stack), Base.tail(state_stack)
#         current_spline, current_f, state = current_state[1:3]  # Extract main components
#         current_N = length(current_spline.locations)  # Dynamically determine the length

#         if current_N == 0
#             # Handle Spline{0} directly
#             result_stack = (Float32(Int(current_spline.spline_type)), result_stack...)
#             continue
#         end

#         if state == :start
#             # Initial state: compute index and determine next steps
#             i = findfirst_default(>=(current_f), current_spline.locations, current_N)
#             if i == 1 || i == current_N
#                 # Boundary case: handle single child spline
#                 loc = current_spline.locations[i]
#                 der = current_spline.derivatives[i]
#                 sp = current_spline.child_splines[i]
#                 state_stack = (
#                     (sp, current_f, :start),
#                     (current_spline, current_f, :boundary, loc, der),
#                     state_stack...,
#                 )
#             else
#                 # General case: handle two child splines
#                 g = current_spline.locations[i - 1]
#                 h = current_spline.locations[i]
#                 k = (current_f - g) / (h - g)
#                 l = current_spline.derivatives[i - 1]
#                 m = current_spline.derivatives[i]
#                 sp1 = current_spline.child_splines[i - 1]
#                 sp2 = current_spline.child_splines[i]
#                 state_stack = (
#                     (sp2, current_f, :start),
#                     (sp1, current_f, :start),
#                     (current_spline, current_f, :combine, g, h, k, l, m),
#                     state_stack...,
#                 )
#             end
#         elseif state == :boundary
#             # Boundary case: combine derivative and single child result
#             loc, der = current_state[4:5]  # Extract saved data
#             v = popfirst!(result_stack)  # Result from the single child spline
#             pushfirst!(result_stack, muladd(der, current_f - loc, v))
#         elseif state == :combine
#             # General case: combine two child spline results
#             g, h, k, l, m = current_state[4:8]  # Extract saved data
#             n = popfirst!(result_stack)        # Result from the first child spline
#             o = popfirst!(result_stack)        # Result from the second child spline
#             p = l * (h - g) - (o - n)
#             q = -m * (h - g) + (o - n)
#             pushfirst!(result_stack, lerp(k, n, o) + k * (1.0 - k) * lerp(k, p, q))
#         end
#     end

#     # Final result should be the only value left on the result stack
#     return first(result_stack)
# end

# @only_float32 land_spline(0.2, 0.5, 0.8, 1.0, 1.2, 1.5, Val{true}())
# @code_warntype get_spline(spline, (0.1f0, 0.2f0, 0.3f0, 0.4f0, 0.5f0, 0.6f0))

# float getSpline(const Spline *sp, const float *vals)
# {
#     if (!sp || sp->len <= 0 || sp->len >= 12)
#     {
#         printf("getSpline(): bad parameters\n");
#         exit(1);
#     }

#     if (sp->len == 1)
#         return ((FixSpline*)sp)->val;

#     float f = vals[sp->typ];
#     int i;

#     for (i = 0; i < sp->len; i++)
#         if (sp->loc[i] >= f)
#             break;
#     if (i == 0 || i == sp->len)
#     {
#         if (i) i--;
#         float v = getSpline(sp->val[i], vals);
#         return v + sp->der[i] * (f - sp->loc[i]);
#     }
#     const Spline *sp1 = sp->val[i-1];
#     const Spline *sp2 = sp->val[i];
#     float g = sp->loc[i-1];
#     float h = sp->loc[i];
#     float k = (f - g) / (h - g);
#     float l = sp->der[i-1];
#     float m = sp->der[i];
#     float n = getSpline(sp1, vals);
#     float o = getSpline(sp2, vals);
#     float p = l * (h - g) - (o - n);
#     float q = -m * (h - g) + (o - n);
#     float r = lerp(k, n, o) + k * (1.0F - k) * lerp(k, p, q);
#     return r;
# }
