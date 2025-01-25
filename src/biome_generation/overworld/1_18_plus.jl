using StaticArrays: SVector
using InteractiveUtils: subtypes

import ..Cubiomes
using ..Utils: Utils, @only_float32, md5_to_uint64, lerp
using ..JavaRNG: JavaXoroshiro128PlusPlus, next🎲
using ..Noises
using ..MCVersions

using .BiomeTrees

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
function trimmed_amplitudes(::NoiseParameter)
    throw(MethodError(trimmed_amplitudes, (NoiseParameter,)))
end

nb_octaves(::NoiseParameter) = throw(MethodError(nb_octaves, (NoiseParameter,)))
nb_trimmed(::NoiseParameter) = throw(MethodError(nb_trimmed, (NoiseParameter,)))
function create_octaves(::NoiseParameter, ::Val{N}) where {N}
    throw(MethodError(create_octaves, (NoiseParameter, Val{N})))
end
function magic_xlo(::NoiseParameter, large)
    throw(MethodError(magic_xlo, (NoiseParameter, typeof(large))))
end
function magic_xhi(::NoiseParameter, large)
    throw(MethodError(magic_xhi, (NoiseParameter, typeof(large))))
end

function create_noise_param(noise_param, amp, oct, id_str, oct_large)
    amp = float.(amp)
    filtered_amp = filter(!iszero, amp)
    nb_octaves_ = length(filtered_amp)
    trimmed_ = Utils.trim(iszero, amp)
    nb_trimmed_ = length(trimmed_)

    if isnothing(oct_large)
        oct_large = oct
        id_str_large = id_str
    else
        oct_large = oct_large
        id_str_large = "$(id_str)_large"
    end

    xlo, xhi = Utils.md5_to_uint64(id_str)
    xlo_large, xh_large = Utils.md5_to_uint64(id_str_large)

    T = Type{noise_param}
    @eval begin
        amplitudes(::$T) = $amp
        octave_min(::$T, ::Val{false}) = $oct
        octave_min(::$T, ::Val{true}) = $oct_large
        id(::$T, ::Val{false}) = $id_str
        id(::$T, ::Val{true}) = $id_str_large
        filtered_amplitudes(::$T) = $filtered_amp
        nb_octaves(::$T) = $nb_octaves_
        nb_trimmed(::$T) = $nb_trimmed_
        trimmed_amplitudes(::$T) = $trimmed_
        magic_xlo(::$T, ::Val{false}) = $xlo
        magic_xhi(::$T, ::Val{false}) = $xhi
        magic_xlo(::$T, ::Val{true}) = $xlo_large
        magic_xhi(::$T, ::Val{true}) = $xh_large

        function create_octaves(::$T, ::Val{N}) where {N}
            ntuple(i -> Octaves{$nb_octaves_}(undef), Val(N))
        end
    end
end

struct Temperature <: NoiseParameter end
create_noise_param(Temperature, (1.5, 0, 1, 0, 0, 0), -10, "minecraft:temperature", -12)

struct Humidity <: NoiseParameter end
create_noise_param(Humidity, (1, 1, 0, 0, 0, 0), -8, "minecraft:vegetation", -10)

#! format: off
struct Continentalness <: NoiseParameter end
create_noise_param(Continentalness, (1, 1, 2, 2, 2, 1, 1, 1, 1), -9, "minecraft:continentalness", -11)
#! format: on

struct Shift <: NoiseParameter end
create_noise_param(Shift, (1, 1, 1, 0), -3, "minecraft:offset", nothing)

struct Weirdness <: NoiseParameter end
create_noise_param(Weirdness, (1, 2, 1, 0, 0, 0), -7, "minecraft:ridge", nothing)

struct Erosion <: NoiseParameter end
create_noise_param(Erosion, (1, 1, 0, 1, 1), -9, "minecraft:erosion", -11)

const NOISE_PARAMETERS = (Temperature, Humidity, Continentalness, Shift, Weirdness, Erosion)

for (i, np) in enumerate(NOISE_PARAMETERS)
    @eval Base.Int(::Type{$np}) = $(Int(i))
end

const TypeTupleClimate = Tuple{(DoublePerlin{nb_octaves(np)} for np in NOISE_PARAMETERS)...}

Base.getindex(tc::TypeTupleClimate, np::Type{<:NoiseParameter}) = @inbounds tc[Int(np)]

struct BiomeNoise <: Dimension
    climate::TypeTupleClimate
    sha::SomeSha
end

@inline function create_noise(noise_param::Type{<:NoiseParameter})
    return Noise(
        DoublePerlin{nb_octaves(noise_param)},
        undef,
        trimmed_amplitudes(noise_param),
        Val(true), # tell the constructor it is already trimmed
    )
end
function BiomeNoise(::UndefInitializer)
    return BiomeNoise(map(create_noise, NOISE_PARAMETERS), SomeSha(nothing))
end

function set_seed!(noise::BiomeNoise, seed::UInt64; sha=Val(true), large=Val(false))
    return _set_seed!(noise, seed, sha, large)
end

function _set_seed!(noise::BiomeNoise, seed, sha::Val{false}, large)
    __set_seed!(noise::BiomeNoise, seed::UInt64, large)
    noise.sha[] = nothing
    return nothing
end

function _set_seed!(noise::BiomeNoise, seed, sha::Val{true}, large)
    __set_seed!(noise::BiomeNoise, seed::UInt64, large)
    noise.sha[] = Utils.sha256_from_seed(seed)
    return nothing
end

function __set_seed!(noise::BiomeNoise, seed, large)
    rng = JavaXoroshiro128PlusPlus(seed)
    xlo = next🎲(rng, UInt64)
    xhi = next🎲(rng, UInt64)

    for (clim, noise_param) in zip(noise.climate, NOISE_PARAMETERS)
        set_seed!(clim, xlo, xhi, noise_param, large)
    end
    return nothing
end

function set_seed!(
    dp::DoublePerlin, xlo, xhi, noise_param, large=Val(false),
)
    xlo ⊻= magic_xlo(noise_param, large)
    xhi ⊻= magic_xhi(noise_param, large)
    rng = JavaXoroshiro128PlusPlus(xlo, xhi)
    set_rng!🎲(
        dp,
        rng,
        trimmed_amplitudes(noise_param),
        octave_min(noise_param, large),
        length(amplitudes(noise_param)),
    )
    return nothing
end

#endregion
#region Spline creation

# ---------------------------------------------------------------------------- #
#                              Splines Creation                                #
# ---------------------------------------------------------------------------- #
#! The entire goal of this part is to get the SPLINE_STACK constant
# (at the end of the part)

# I think it's better here to use enums instead of types
@enum SplineType begin
    SP_CONTINENTALNESS
    SP_EROSION
    SP_RIDGES
    SP_WEIRDNESS
    FIXSPLINE = typemax(Int32)
end
Base.trunc(::Type{SplineType}, x) = SplineType(trunc(Int, x))

# ? NTuple vs Vector ?
# if we use ntuple, julia will always try to do some dynamic dispatch on N.
# since the elements are getting accessed in get_spline very randomly, julia will
# never be able to infer N.
struct Spline{N}
    spline_type::SplineType
    locations::NTuple{N, Float32}
    derivatives::NTuple{N, Float32}
    child_splines::NTuple{N, Spline}
    fix_value::Float32
end
Base.length(spline::Spline) = length(spline.locations)

function Spline(spline_type::SplineType, locations, derivatives, child_splines)
    return Spline(spline_type, locations, derivatives, child_splines, zero(Float32))
end
fixspline(value::Real) = Spline(FIXSPLINE, (), (), (), value)

# function Spline(spline_type::SplineType, locations, derivatives, child_splines)
#     return Spline(
#         spline_type,
#         collect(locations),
#         collect(derivatives),
#         collect(child_splines),
#         zero(Float32),
#     )
# end
# fixspline(value::Real) = Spline(FIXSPLINE, [], [], [], value)

fixsplines(values...) = map(fixspline, values)

@only_float32 function get_offset_value(weirdness, continentalness)
    f1 = (continentalness - 1) * 0.5
    f0 = 1 + f1
    f2 = (weirdness + 1.17) * 0.46082947
    off = muladd(f0, f2, f1)
    weirdness < -0.7 && return max(off, -0.2222)
    return max(off, zero(off))
end

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
    slope = (offset_pos1 - offset_neg1) * 0.5
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
        fixsplines(
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
        fixsplines(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1), offset_pos1),
    )
end

@only_float32 function spline_38219(
    spline_type, slope, offset_pos1, offset_neg1, ::Val{false},
)
    return Spline(
        spline_type,
        (-1, 1),
        (slope, slope),
        fixsplines(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1)),
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
        fixsplines(x1, x2, x3, x4, x5),
    )
end

@only_float32 function additional_values_land_spline(x1, x2, x3, x5, spline_6, ::Val{true})
    # add additional splines if bl is true
    spline_7 = flat_offset_spline(x1, x5, x5, x2, x3, 0.5)
    spline_8 = Spline(
        SP_RIDGES,
        (-1.0, -0.4, 0),
        (0, 0, 0),
        (fixspline(x1), spline_6, fixspline(x3 + 0.07)),
    )

    locations = (0.4, 0.45, 0.55, 0.58)
    child_splines = (spline_7, spline_8, spline_8, spline_7)
    # 11 child splines if bl is true
    return locations, child_splines
end

additional_values_land_spline(x1, x2, x3, x5, spline_6, ::Val{false}) = (), ()

zero_like(::NTuple{N, T}) where {N, T} = ntuple(i -> zero(T), Val{N}())
zero_like(x::Tuple{}) = x

@only_float32 function land_spline(x1, x2, x3, x4, x5, x6, bl::Val{BL}) where {BL}
    # create initial splines with different linear interpolation values
    lerp_4_15 = lerp(x4, 0.6, 1.5)
    lerp_4_1 = lerp(x4, 0.6, 1.0)
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
    derivatives = zero_like(locations)

    # Create and return the final spline
    return Spline(SP_EROSION, locations, derivatives, child_splines)
end

@only_float32 function world_spline()
    spline1 = land_spline(-0.15, 0, 0, 0.1, 0, -0.03, Val(false))
    spline2 = land_spline(-0.10, 0.03, 0.1, 0.1, 0.01, -0.03, Val(false))
    spline3 = land_spline(-0.10, 0.03, 0.1, 0.7, 0.01, -0.03, Val(true))
    spline4 = land_spline(-0.05, 0.03, 0.1, 1.0, 0.01, 0.01, Val(true))

    locations = (-1.10, -1.02, -0.51, -0.44, -0.18, -0.16, -0.15, -0.10, 0.25, 1.00)
    child_splines = (
        fixspline(0.044),
        fixspline(-0.2222),
        fixspline(-0.2222),
        fixspline(-0.12),
        fixspline(-0.12),
        spline1,
        spline1,
        spline2,
        spline3,
        spline4,
    )
    derivatives = zero_like(locations)

    return Spline(SP_CONTINENTALNESS, locations, derivatives, child_splines)
end

const SPLINE_STACK = world_spline()
#endregion
#region Spline getter
# ---------------------------------------------------------------------------- #
#                                 Spline Getter                                #
# ---------------------------------------------------------------------------- #

function get_spline_offset(spline::Spline, index, vals, f)
    loc, der, sp =
        spline.locations[index], spline.derivatives[index], spline.child_splines[index]
    v = get_spline(sp, vals)
    return muladd(der, f - loc, v)
end

# TODO: transform the recursive to an iterate one, since Julia is very bad with recursion :(
function get_spline(spline::Spline, vals)
    N = length(spline)
    iszero(N) && return spline.fix_value
    f = vals[Int(spline.spline_type) + 1]
    i = Utils.findfirst_default(>=(f), spline.locations, N)
    isone(i) && return get_spline_offset(spline, 1, vals, f)
    i == (N + 1) && return get_spline_offset(spline, N, vals, f)

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

    r = lerp(k, n, o) + k * (1 - k) * lerp(k, p, q)
    return r
end
#endregion
#region Biome Getter
# ---------------------------------------------------------------------------- #
#                                 Biome Getter                                 #
# ---------------------------------------------------------------------------- #
# TODO: get_biome for scale != (1, 4)

function get_biome(
    bn::BiomeNoise,
    x, z, y,
    ::T📏"1:1",
    version::mcvt">=1.18",
    spline=SPLINE_STACK;
    skip_shift=Val(false), skip_depth=Val(false),
)
    x, z, y = voronoi_access(bn.sha[], x, z, y)
    return get_biome(
        bn,
        x, z, y,
        📏"1:4", version, spline;
        skip_shift=skip_shift, skip_depth=skip_depth,
    )
end

function get_biome(
    bn::BiomeNoise,
    x, z, y,
    ::T📏"1:4", version::mcvt">=1.18",
    spline=SPLINE_STACK;
    skip_shift=Val(false), skip_depth=Val(false), old_idx=nothing,
)
    return _get_biome(
        bn, x, z, y, 📏"1:4", version, spline, skip_shift, skip_depth, old_idx,
    )
end

# The use of two _get_biome that are almost the same is a bit ugly but im too lazy
# it works so it's fine, the issue is that we have two values to return if old_idx is not nothing
function _get_biome(
    bn::BiomeNoise,
    x, z, y,
    ::T📏"1:4", version::mcvt">=1.18",
    spline, skip_shift, skip_depth, old_idx::Nothing,
)
    return BiomeID(get_biome_int(
        bn, x, z, y, version, spline,
        skip_shift, skip_depth, old_idx,
    ))
end

function _get_biome(
    bn::BiomeNoise,
    x, z, y,
    ::T📏"1:4", version::mcvt">=1.18",
    spline, skip_shift, skip_depth, old_idx,
)
    biome_int, old_idx = get_biome_int(
        bn, x, z, y, version, spline,
        skip_shift, skip_depth, old_idx,
    )
    return BiomeID(biome_int), old_idx
end

function get_biome_int(
    bn::BiomeNoise,
    x, z, y,
    version::mcvt">=1.18",
    spline=SPLINE_STACK,
    skip_shift=Val(false), skip_depth=Val(false), old_idx=nothing,
)
    noiseparams = sample_biomenoises(
        bn, x, z, y, spline, skip_shift, skip_depth,
    )
    return climate_to_biome(noiseparams, version, old_idx)
end

function sample_biomenoises(
    bn::BiomeNoise,
    x, z, y,
    spline=SPLINE_STACK,
    skip_shift=Val(false), skip_depth=Val(false),
)
    px, pz = sample_shift(bn, x, z, skip_shift)
    continentalness::Float32 = sample_noise(bn.climate[Continentalness], px, pz, 0)
    erosion::Float32 = sample_noise(bn.climate[Erosion], px, pz, 0)
    weirdness::Float32 = sample_noise(bn.climate[Weirdness], px, pz, 0)
    depth = sample_depth(spline, continentalness, erosion, weirdness, y, skip_depth)

    temperature::Float32 = sample_noise(bn.climate[Temperature], px, pz, 0)
    humidity::Float32 = sample_noise(bn.climate[Humidity], px, pz, 0)

    return map(
        x -> Base.unsafe_trunc(Int64, 10_000.0f0 * x),
        (temperature, humidity, continentalness, erosion, depth, weirdness),
    )
end

function sample_shift(bn::BiomeNoise, x, z, skip_shift::Val{false})
    px = sample_noise(bn.climate[Shift], x, z, 0) * 4.0
    pz = sample_noise(bn.climate[Shift], z, 0, x) * 4.0
    return x + px, z + pz
end
sample_shift(bn::BiomeNoise, x, z, skip_shift::Val{true}) = x, z
sample_shift(bn, x, z, skip_shift::Bool) = sample_shift(bn, x, z, Val(skip_shift))

@only_float32 eval_weirdness(x) = -3 * (abs(abs(x) - 2 / 3) - 1 / 3)

@only_float32 function sample_depth(spline, c, e, w, y, skip_depth::Val{false})
    vals = (c, e, eval_weirdness(w), w)
    off = get_spline(spline, vals) + 0.015
    return 1 - (y * 4) / 128 - 83 / 160 + off
end
sample_depth(spline, c, e, w, y, skip_depth::Val{true}) = 0.0f0
function sample_depth(spline, c, e, w, y, skip_depth::Bool)
    sample_depth(spline, c, e, w, y, Val(skip_depth))
end

function climate_to_biome(
    noise_parameters::NTuple{6},
    version::mcvt">=1.18",
    old_idx=nothing,
)
    return climate_to_biome(noise_parameters, get_biome_tree(version), old_idx)
end

climate_to_biome(np::NTuple{6}, bt::BiomeTree, ::Nothing) = climate_to_biome(np, bt)
function climate_to_biome(noise_parameters::NTuple{6}, biome_tree::BiomeTree)
    idx = get_resulting_node(noise_parameters, biome_tree)
    return extract_biome_index(biome_tree, idx)
end
function climate_to_biome(noise_parameters::NTuple{6}, biome_tree::BiomeTree, old_idx)
    dist = noise_params_distance(noise_parameters, biome_tree, old_idx)
    idx = get_resulting_node(noise_parameters, biome_tree, old_idx, dist)
    return extract_biome_index(biome_tree, idx), idx
end

extract_biome_index(biome_tree::BiomeTree, idx) = (biome_tree.nodes[idx + 1] >> 48) & 0xFF

function get_resulting_node(
    noise_params::NTuple{6},
    biome_tree::BiomeTree,
    alt=0,
    dist=typemax(UInt64),
    idx=0,
    depth=1,
)
    iszero(biome_tree.steps[depth]) && return idx
    # in all the code, dist refers to the square of the distance

    local step
    while true
        step = biome_tree.steps[depth]
        depth += 1
        idx + step >= biome_tree.len_nodes || break
    end

    node = biome_tree.nodes[idx + 1]
    inner = node >> 48
    leaf = alt

    for _ in 0:(biome_tree.order - 1)
        dist_inner = noise_params_distance(noise_params, biome_tree, inner)
        if dist_inner < dist
            leaf2 = get_resulting_node(noise_params, biome_tree, leaf, dist, inner, depth)
            dist_leaf2 = if (inner == leaf2)
                dist_inner
            else
                noise_params_distance(noise_params, biome_tree, leaf2)
            end
            if dist_leaf2 < dist
                dist = dist_leaf2
                leaf = leaf2
            end
        end
        inner += step
        inner >= biome_tree.len_nodes && break
    end

    return leaf
end

function noise_params_distance(noise_params::NTuple{6}, biome_tree::BiomeTree, idx)
    dist_square = 0
    node, param = biome_tree.nodes[idx + 1], biome_tree.param
    for i in 1:6
        # idx is the index of the biome in the biome tree
        # we iterate over the 6 noise parameters
        # each noise_param is associated with 2 bytes in the biome tree
        # see the comments of the biome tree for more information
        idx = (node >> (8 * (i - 1))) & 0xFF
        dist_square +=
            calculate_distance(noise_params[i], param[idx + 1][2], param[idx + 1][1])
    end
    return dist_square
end

function calculate_distance(noise_param, param1, param2)
    a = noise_param - param1
    signed(a) > 0 && return a * a

    b = param2 - noise_param
    signed(b) > 0 && return b * b

    return zero(a)
end
#endregion
#region Biome Generation
# ---------------------------------------------------------------------------- #
#                               Biome Generation                               #
# ---------------------------------------------------------------------------- #

function gen_biomes!(bn::BiomeNoise, map3D::MCMap{3}, ::T📏"1:1", version::mcvt">=1.18")
    coords = CartesianIndices(map3D)
    # If there is only one value, simple wrapper around get_biome_unsafe
    if isone(length(coords))
        coord = first(coords)
        map3D[coord] = get_biome(bn, coord.I..., 📏"1:4", version)
    end

    # The minimal map where we are sure we can find the source coordinates at scale 4
    biome_parent_axes = get_voronoi_src_axes3D(map3D)
    biome_parents = view_reshape_cache_like(biome_parent_axes)
    gen_biomes!(bn, biome_parents, 📏"1:4", version)

    sha = bn.sha[]
    for coord in coords
        source_x, source_z, source_y = voronoi_access(sha, coord)
        result = biome_parents[source_x, source_z, source_y]
        @inbounds map3D[coord] = result
    end
end

function gen_biomes!(bn::BiomeNoise, map3D::MCMap{3}, ::T📏"1:4", version::mcvt">=1.18")
    for coord in CartesianIndices(map3D)
        map3D[coord] = get_biome(bn, coord.I..., 📏"1:4", version)
    end
    return nothing
end

function gen_biomes!(
    bn::BiomeNoise, map3D::MCMap{3},
    ::Scale{S}, version::mcvt">=1.18",
) where {S}
    scale = S ÷ 4
    mid = scale ÷ 2
    old_idx = zero(UInt64)
    for coord in CartesianIndices(map3D)
        @inbounds coord_scale4 = (
            coord[1] * scale + mid,
            coord[2] * scale + mid,
            coord[3],
        )
        map3D[coord], old_idx = get_biome(
            bn, coord_scale4..., 📏"1:4", version;
            skip_shift=Val(true), old_idx=old_idx,
        )
    end
end
