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

struct Spline
    spline_type::SplineType
    locations::Vector{Float32}
    derivatives::Vector{Float32}
    values::Vector{Float32} # The values of the spline at the locations
    # child_splines::Vector{Spline}
end

function _create_spline_38219(f::Float32, bl::Bool)
    spline_type = SP_RIDGES

    offset_neg1 = get_offset_value(-1f0, f)
    offset_pos1 = get_offset_value(1f0, f)
    half_factor = 0.5f0 * (1.0f0 - f)
    adjusted_factor = half_factor / (0.46082947f0 * (1f0 - half_factor)) - 1.17f0

    if (-0.65 <= adjusted_factor <= 1)
        offset_neg065 = get_offset_value(-0.65f0, f)
        offset_neg075 = get_offset_value(-0.75f0, f)
        scaled_diff = (offset_neg075 - offset_neg1) * 4f0
        offset_adjusted = get_offset_value(adjusted_factor, f)
        slope = (offset_pos1 - offset_adjusted) / (1f0 - adjusted_factor)

        return Spline(
            spline_type,
            [-1f0, -0.75f0, -0.65f0, adjusted_factor - 0.01f0, adjusted_factor, 1f0],
            [scaled_diff, 0, 0, 0, slope, slope],
            [offset_neg1, offset_neg075, offset_neg065, offset_adjusted, offset_adjusted, offset_pos1],
        )
    else
        slope = (offset_pos1 - offset_neg1) / 0.46082947f0
        if bl
            return Spline(
                spline_type,
                [-1f0, 0, 1f0],
                [0, slope, slope],
                [max(offset_neg1, 0.2f0), lerp(0.5f0, offset_neg1, offset_pos1), offset_pos1],
            )
        else
            return Spline(
                spline_type,
                [-1f0, 1f0],
                [slope, slope],
                [offset_neg1, offset_pos1],
            )
        end
    end
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