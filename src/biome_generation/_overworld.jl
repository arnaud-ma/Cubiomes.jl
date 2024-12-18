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

# TODO: like the end generation, make a function with (getter::Function) and it can be
# either x -> stack[x] or x -> getter(x, y , z) or something like that
# to allow to stack the splines or not, since the splines are only computed
# for the getSpline function (in the C implementation) so see the getSpline function
# and create it with the getter function instead of a Spline object that store
# every splines

function get_offset_value(weirdness, continentalness)
    f1 = (continentalness - 1f0) * 0.5f0
    f0 = 1f0 + f1
    f2 = (weirdness + 1.17f0) * 0.46082947f0
    off = muladd(f0, f2, f1)
    weirdness < -0.7f0 && return max(off, -0.2222f0)
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

struct Spline
    spline_type::SplineType
    locations::Vector{Float32}
    derivatives::Vector{Float32}
    child_splines::Vector{Spline}
end

const EMPTY_FLOAT32 = Float32[]
const EMPTY_SPLINE = Spline[]

function fix_spline(spline_type::SplineType)
    return Spline(spline_type, EMPTY_FLOAT32, EMPTY_FLOAT32, EMPTY_SPLINE)
end
fix_spline(spline_value) = fix_spline(trunc(SplineType, spline_value))

function spline_38219(coeff, bl::Bool)
    # TODO: maybe use sizehint! to preallocate memory
    spline_type = SP_RIDGES

    offset_neg1 = get_offset_value(-1.0f0, coeff)
    offset_pos1 = get_offset_value(1.0f0, coeff)
    half_factor = 0.5f0 * (1.0f0 - coeff)
    adjusted_factor = half_factor / (0.46082947f0 * (1.0f0 - half_factor)) - 1.17f0

    if -0.65f0 <= adjusted_factor <= 1.0f0
        offset_neg065 = get_offset_value(-0.65f0, coeff)
        offset_neg075 = get_offset_value(-0.75f0, coeff)
        scaled_diff = (offset_neg075 - offset_neg1) * 4.0f0
        offset_adjusted = get_offset_value(adjusted_factor, coeff)
        slope = (offset_pos1 - offset_adjusted) / (1.0f0 - adjusted_factor)

        return Spline(
            spline_type,
            [-1.0f0, -0.75f0, -0.65f0, adjusted_factor - 0.01f0, adjusted_factor, 1.0f0],
            [scaled_diff, 0, 0, 0, slope, slope],
            [
                fix_spline(offset_neg1),
                fix_spline(offset_neg075),
                fix_spline(offset_neg065),
                fix_spline(offset_adjusted),
                fix_spline(offset_adjusted),
                fix_spline(offset_pos1),
            ],
        )
    end
    slope = (offset_pos1 - offset_neg1) / 0.46082947f0

    if bl
        return Spline(
            spline_type,
            [-1.0f0, 0, 1.0f0],
            [0, slope, slope],
            [
                fix_spline(max(offset_neg1, 0.2f0)),
                fix_spline(lerp(0.5f0, offset_neg1, offset_pos1)),
                fix_spline(offset_pos1),
            ],
        )
    else
        return Spline(
            spline_type,
            [-1.0f0, 1.0f0],
            [slope, slope],
            [fix_spline(offset_neg1), fix_spline(offset_pos1)],
        )
    end
end

function flat_offset_spline(start, mid1, mid2, mid3, mid4, end_)
    spline_type = SP_RIDGES
    left = max(0.5f0 * (mid1 - start), end_)
    middle = 5.0f0 * (mid2 - mid1)
    return Spline(
        spline_type,
        [-1.0f0, -0.4f0, 0.0f0, 0.4f0, 1.0f0],
        [left, max(left, middle), middle, 2.0f0 * (mid3 - mid2), 0.7f0 * (mid4 - mid3)],
        [fix_spline(start), fix_spline(mid1), fix_spline(mid2), fix_spline(mid3), fix_spline(end_)],
    )
end

function land_spline(f, g, h, i, j, k, bl::Bool)
    # create initial splines with different linear interpolation values
    lerp_i_1 = lerp(i, 0.6f0, 1.5f0)
    lerp_i_2 = lerp(i, 0.6f0, 1.0f0)
    spline_1 = spline_38219(lerp_i_1, bl)
    spline_2 = spline_38219(lerp_i_2, bl)
    spline_3 = spline_38219(i, bl)

    # create flat offset splines
    half_i = 0.5f0 * i
    spline_4 = flat_offset_spline(f - 0.15f0, half_i, half_i, half_i, i * 0.6f0, 0.5f0)
    spline_5 = flat_offset_spline(f, j * i, g * i, half_i, i * 0.6f0, 0.5f0)
    spline_6 = flat_offset_spline(f, j, j, g, h, 0.5f0)

    # Initialize locations and associated splines
    locations = [-0.85f0, -0.7f0, -0.4f0, -0.35f0, -0.1f0, 0.2f0]
    child_splines = [spline_1, spline_2, spline_3, spline_4, spline_5, spline_6]
    if bl
        # add additional splines if bl is true
        spline_7 = flat_offset_spline(f, j, j, g, h, 0.5f0)
        spline_8 = Spline(
            SP_RIDGES,
            [-1.0f0, -0.4f0, 0.0f0],
            zeros(Float32, 3),
            [fix_spline(f), spline_6, fix_spline(h + 0.07f0)],
        )

        push!(locations, 0.4f0, 0.45f0, 0.55f0, 0.58f0)
        push!(child_splines, spline_7, spline_8, spline_8, spline_7)

        # 11 child splines if bl is true
        derivatives = zeros(Float32, 11)
    else
        # 7 child splines if bl is false
        derivatives = zeros(Float32, 7)
    end

    # child spline common to both cases
    push!(locations, 0.7f0)
    push!(child_splines, flat_offset_spline(-0.02f0, k, k, g, h, 0.0f0))

    # Create and return the final spline
    return Spline(SP_EROSION, locations, derivatives, child_splines)
end

function count_elements(spline::Spline)
    if isempty(spline.child_splines)
        return 0
    end
    return length(spline.locations) + sum(count_elements(child) for child in spline.child_splines)
end

using BenchmarkTools

@code_typed land_spline(1.4f0, 0.5f0, 5.6f0, 3.4f0, 5.8f0, 3.5f0, true)
x = land_spline(1.4f0, 0.5f0, .6f0, .4f0, .8f0, 3.5f0, true)
@btime land_spline(1.4f0, 0.5f0, 0.6f0, 0.4f0, 0.8f0, 3.5f0, true);

@profview for _ in 1:100_000
    land_spline(1.4f0, 0.5f0, 0.6f0, 0.4f0, 0.8f0, 3.5f0, true)
end

# static Spline *createLandSpline(
#     SplineStack *ss, float f, float g, float h, float i, float j, float k, int bl)
# {
#     Spline *sp1 = createSpline_38219(ss, lerp(i, 0.6F, 1.5F), bl);
#     Spline *sp2 = createSpline_38219(ss, lerp(i, 0.6F, 1.0F), bl);
#     Spline *sp3 = createSpline_38219(ss, i, bl);
#     const float ih = 0.5F * i;
#     Spline *sp4 = createFlatOffsetSpline(ss, f-0.15F, ih, ih, ih, i*0.6F, 0.5F);
#     Spline *sp5 = createFlatOffsetSpline(ss, f, j*i, g*i, ih, i*0.6F, 0.5F);
#     Spline *sp6 = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5F);
#     Spline *sp7 = createFlatOffsetSpline(ss, f, j, j, g, h, 0.5F);

#     Spline *sp8 = &ss->stack[ss->len++];
#     sp8->typ = SP_RIDGES;
#     addSplineVal(sp8, -1.0F, createFixSpline(ss, f), 0.0F);
#     addSplineVal(sp8, -0.4F, sp6, 0.0F);
#     addSplineVal(sp8,  0.0F, createFixSpline(ss, h + 0.07F), 0.0F);

#     Spline *sp9 = createFlatOffsetSpline(ss, -0.02F, k, k, g, h, 0.0F);
#     Spline *sp = &ss->stack[ss->len++];
#     sp->typ = SP_EROSION;
#     addSplineVal(sp, -0.85F, sp1, 0.0F);
#     addSplineVal(sp, -0.7F,  sp2, 0.0F);
#     addSplineVal(sp, -0.4F,  sp3, 0.0F);
#     addSplineVal(sp, -0.35F, sp4, 0.0F);
#     addSplineVal(sp, -0.1F,  sp5, 0.0F);
#     addSplineVal(sp,  0.2F,  sp6, 0.0F);
#     if (bl) {
#         addSplineVal(sp, 0.4F,  sp7, 0.0F);
#         addSplineVal(sp, 0.45F, sp8, 0.0F);
#         addSplineVal(sp, 0.55F, sp8, 0.0F);
#         addSplineVal(sp, 0.58F, sp7, 0.0F);
#     }
#     addSplineVal(sp, 0.7F, sp9, 0.0F);
#     return sp;
# }