using InteractiveUtils: subtypes
using Base.Cartesian: @nexprs

using StaticArrays: SVector
using OhMyThreads: tforeach, StaticScheduler

using ..Utils: Utils, @only_float32, md5_to_uint64, lerp
using ..JavaRNG: JavaXoroshiro128PlusPlus, next🎲
using ..Noises: Noise, DoublePerlin
using .BiomeArrays: WorldMap, coordinates
using .Voronoi: voronoi_access, voronoi_source
using ..MCVersions

using .BiomeTrees

#region Noise Parameters
# ---------------------------------------------------------------------------- #
#                               Noise Parameters                               #
# ---------------------------------------------------------------------------- #

abstract type NoiseParameter end

# only here to help the editor, poor baby :(
#! format: off
amplitudes(::NoiseParameter) = throw(MethodError(amplitudes, (NoiseParameter,)))
octave_min(::NoiseParameter, large) = throw(MethodError(octave_min, (NoiseParameter, typeof(large))))
trimmed_amplitudes(::NoiseParameter) = throw(MethodError(trimmed_amplitudes, (NoiseParameter,)))
trimmed_end_amplitudes(::NoiseParameter) = throw(MethodError(trimmed_end_amplitudes, (NoiseParameter,)))
nb_octaves(::NoiseParameter) = throw(MethodError(nb_octaves, (NoiseParameter,)))
create_octaves(::NoiseParameter, ::Val) =  throw(MethodError(create_octaves, (NoiseParameter, typeof(n))))
magic_xlo(::NoiseParameter, large) = throw(MethodError(magic_xlo, (NoiseParameter, typeof(large))))
magic_xhi(::NoiseParameter, large) = throw(MethodError(magic_xhi, (NoiseParameter, typeof(large))))
#! format: on

function create_noise_param(noise_param, amp, oct, id_str, oct_large)
    amp = float.(amp)
    filtered_amp = filter(!iszero, amp)
    nb_octaves_ = length(filtered_amp)
    trimmed_ = Utils.trim(iszero, amp)
    trimmed_end_ = Utils.trim_end(iszero, amp)

    if isnothing(oct_large)
        oct_large = oct
        id_str_large = id_str
    else
        oct_large = oct_large
        id_str_large = "$(id_str)_large"
    end

    xlo, xhi = md5_to_uint64(id_str)
    xlo_large, xh_large = md5_to_uint64(id_str_large)

    T = Type{noise_param}
    return @eval begin
        amplitudes(::$T) = $amp
        octave_min(::$T, ::Val{false}) = $oct
        octave_min(::$T, ::Val{true}) = $oct_large
        nb_octaves(::$T) = $nb_octaves_
        trimmed_amplitudes(::$T) = $trimmed_
        trimmed_end_amplitudes(::$T) = $trimmed_end_
        magic_xlo(::$T, ::Val{false}) = $xlo
        magic_xhi(::$T, ::Val{false}) = $xhi
        magic_xlo(::$T, ::Val{true}) = $xlo_large
        magic_xhi(::$T, ::Val{true}) = $xh_large

        function create_octaves(::$T, ::Val{N}) where {N}
            return ntuple(i -> Octaves{$nb_octaves_}(undef), Val(N))
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

struct BiomeNoise{V} <: Overworld
    climate::TypeTupleClimate
    sha::SomeSha
    rng_temp1::JavaXoroshiro128PlusPlus
    rng_temp2::JavaXoroshiro128PlusPlus
end

@inline function create_noise(noise_param::Type{<:NoiseParameter})
    return Noise(
        DoublePerlin{nb_octaves(noise_param)},
        undef,
        trimmed_amplitudes(noise_param),
        Val(true), # tell the constructor it is already trimmed
    )
end

function BiomeNoise{V}(::UndefInitializer) where {V}
    return BiomeNoise{V}(
        map(create_noise, NOISE_PARAMETERS),
        SomeSha(nothing),
        JavaXoroshiro128PlusPlus(undef),
        JavaXoroshiro128PlusPlus(undef),
    )
end

# @eval needed for $(length(NOISE_PARAMETERS)) to be understand
# as an integer by @nexprs instead of an expression
@eval function setseed!(noise::BiomeNoise, seed::UInt64; sha = true, large = false)
    rng, param_rng = noise.rng_temp1, noise.rng_temp2
    setseed🎲(rng, seed)
    xlo = next🎲(rng, UInt64)
    xhi = next🎲(rng, UInt64)

    # Next line is the Julia syntax to unroll a "for i in 1:length(NOISE_PARAMETERS)"
    # This is needed because otherwise the specific type of each clim and noise_param
    # is not known at compile time and this is crucial to dispatch at compile time
    # setrng!🎲 and magic_xlo
    @nexprs $(length(NOISE_PARAMETERS)) i -> begin
        clim, noise_param = noise.climate[i], NOISE_PARAMETERS[i]
        param_rng.lo = xlo ⊻ magic_xlo(noise_param, Val(large))
        param_rng.hi = xhi ⊻ magic_xhi(noise_param, Val(large))

        setrng!🎲(
            clim,
            param_rng,
            trimmed_end_amplitudes(noise_param),
            octave_min(noise_param, Val(large)),
            length(amplitudes(noise_param)),
        )
    end

    if sha
        setseed!(noise.sha, seed)
    else
        reset!(noise.sha)
    end

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
    POINT_SPLINE = typemax(Int32)
end
Base.trunc(::Type{SplineType}, x) = SplineType(trunc(Int, x))

# ? NTuple vs Vector ?
# if we use ntuple, julia will always try to do some dynamic dispatch on N.
# since the elements are getting accessed in get_spline very randomly, julia will
# never be able to infer N.
struct Spline
    spline_type::SplineType
    locations::Vector{Float32} #::NTuple{N, Float32}
    derivatives::Vector{Float32} #::NTuple{N, Float32}
    child_splines::Vector{Spline} #::NTuple{N, Spline}
    fix_value::Float32
end

Base.length(spline::Spline) = length(spline.locations)

# function Spline(spline_type::SplineType, locations, derivatives, child_splines)
#     return Spline(spline_type, locations, derivatives, child_splines, zero(Float32))
# end
# point_spline(value::Real) = Spline(POINT_SPLINE, (), (), (), value)

function Spline(spline_type::SplineType, locations, derivatives, child_splines)
    return Spline(
        spline_type,
        collect(locations),
        collect(derivatives),
        collect(child_splines),
        zero(Float32),
    )
end
point_spline(value::Real) = Spline(POINT_SPLINE, Float32[], Float32[], Spline[], value)

point_splines(values...) = map(point_spline, values)

@only_float32 function moutain_continentalness(weirdness, continentalness)
    continentalness_factor = (continentalness - 1) * 0.5
    scale_factor = 1 + continentalness_factor
    scaled_weirdness = (weirdness + 1.17) * 0.46082947
    offset = muladd(scale_factor, scaled_weirdness, continentalness_factor)
    weirdness < -0.7 && return max(offset, -0.2222)
    return max(offset, zero(offset))
end

# we really need to constraint coeff to Float2 here otherwise we need to have a
# tuple full of Float32 and not of Float64
@only_float32 function mountain_ridge_spline(coeff::Float32, bl::Val{BL}) where {BL}
    spline_type = SP_RIDGES
    offset_neg1 = moutain_continentalness(-1, coeff)
    offset_pos1 = moutain_continentalness(1, coeff)
    half_factor = 0.5 * (1 - coeff)
    λ = half_factor / (0.46082947 * (1 - half_factor)) - 1.17
    if -0.65 <= λ <= 1
        return mountain_ridge_spline(spline_type, coeff, offset_pos1, offset_neg1, λ)
    end
    slope = (offset_pos1 - offset_neg1) * 0.5
    return mountain_ridge_spline(spline_type, slope, offset_pos1, offset_neg1, bl)
end

@only_float32 function mountain_ridge_spline(spline_type, coeff, offset_pos1, offset_neg1, λ::Real)
    offset_neg065 = moutain_continentalness(-0.65, coeff)
    offset_neg075 = moutain_continentalness(-0.75, coeff)
    scaled_diff = (offset_neg075 - offset_neg1) * 4
    offset_adjusted = moutain_continentalness(λ, coeff)
    slope = (offset_pos1 - offset_adjusted) / (1.0f0 - λ)

    return Spline(
        spline_type,
        (-1, -0.75, -0.65, λ - 0.01, λ, 1),
        (scaled_diff, 0, 0, 0, slope, slope),
        point_splines(
            offset_neg1,
            offset_neg075,
            offset_neg065,
            offset_adjusted,
            offset_adjusted,
            offset_pos1,
        ),
    )
end

@only_float32 function mountain_ridge_spline(
        spline_type, slope, offset_pos1, offset_neg1, ::Val{true},
    )
    return Spline(
        spline_type,
        (-1, 0, 1),
        (0, slope, slope),
        point_splines(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1), offset_pos1),
    )
end

@only_float32 function mountain_ridge_spline(
        spline_type, slope, offset_pos1, offset_neg1, ::Val{false},
    )
    return Spline(
        spline_type,
        (-1, 1),
        (slope, slope),
        point_splines(max(offset_neg1, 0.2), lerp(0.5, offset_neg1, offset_pos1)),
    )
end

@only_float32 function ridge_spline(x1, x2, x3, x4, x5, x6)
    spline_type = SP_RIDGES
    x7 = max(0.5 * (x2 - x1), x6)
    x8 = 5 * (x3 - x2)
    return Spline(
        spline_type,
        (-1, -0.4, 0, 0.4, 1),
        (x7, min(x7, x8), x8, 2 * (x4 - x3), 0.7 * (x5 - x4)),
        point_splines(x1, x2, x3, x4, x5),
    )
end

@only_float32 function additional_ridge_splines(x1, x2, x3, x5, spline6, ::Val{true})
    # add additional splines if bl is true
    spline7 = ridge_spline(x1, x5, x5, x2, x3, 0.5)
    spline8 = Spline(
        SP_RIDGES,
        (-1.0, -0.4, 0),
        (0, 0, 0),
        (point_spline(x1), spline6, point_spline(x3 + 0.07)),
    )

    locations = (0.4, 0.45, 0.55, 0.58)
    child_splines = (spline7, spline8, spline8, spline7)
    # 11 child splines if bl is true
    return locations, child_splines
end
additional_ridge_splines(x1, x2, x3, x5, spline_6, ::Val{false}) = (), ()

zerolike(::NTuple{N, T}) where {N, T} = ntuple(i -> zero(T), Val{N}())
zerolike(x::Tuple{}) = x

@only_float32 function erosion_offset_spline(x1, x2, x3, x4, x5, x6, bl::Val{BL}) where {BL}
    # initial mountain ridge spline
    spline1 = mountain_ridge_spline(lerp(x4, 0.6, 1.5), bl)
    spline2 = mountain_ridge_spline(lerp(x4, 0.6, 1.0), bl)
    spline3 = mountain_ridge_spline(x4, bl)

    # ridge spline
    halfx4 = 0.5 * x4
    spline4 = ridge_spline(x1 - 0.15, halfx4, halfx4, halfx4, x4 * 0.6, 0.5)
    spline5 = ridge_spline(x1, x5 * x4, x2 * x4, halfx4, x4 * 0.6, 0.5)
    spline6 = ridge_spline(x1, x5, x5, x2, x3, 0.5)

    #! format: off
    locations =     (-0.85  , -0.7   , -0.4   , -0.35  , -0.1   , 0.2    )
    child_splines = (spline1, spline2, spline3, spline4, spline5, spline6)
    #! format: on


    # if bl is true or not, there is additional splines that occur before the last one
    mid_locs, mid_splines = additional_ridge_splines(x1, x2, x3, x5, spline6, bl)
    last_loc, last_spline = 0.7, ridge_spline(-0.02, x6, x6, x2, x3, 0)

    # concatenate the additional and last splines to the initial ones
    locations = (locations..., mid_locs..., last_loc)
    child_splines = (child_splines..., mid_splines..., last_spline)

    # derivatives are always zero (don't ask me why, but i take it it's simpler this way)
    derivatives = zerolike(locations)

    return Spline(SP_EROSION, locations, derivatives, child_splines)
end

@only_float32 function worldspline()
    spline1 = erosion_offset_spline(-0.15, 0, 0, 0.1, 0, -0.03, Val(false))
    spline2 = erosion_offset_spline(-0.1, 0.03, 0.1, 0.1, 0.01, -0.03, Val(false))
    spline3 = erosion_offset_spline(-0.1, 0.03, 0.1, 0.7, 0.01, -0.03, Val(true))
    spline4 = erosion_offset_spline(-0.05, 0.03, 0.1, 1.0, 0.01, 0.01, Val(true))

    locations = (-1.1, -1.02, -0.51, -0.44, -0.18, -0.16, -0.15, -0.1, 0.25, 1.0)
    child_splines = (
        point_spline(0.044),
        point_spline(-0.2222),
        point_spline(-0.2222),
        point_spline(-0.12),
        point_spline(-0.12),
        spline1,
        spline1,
        spline2,
        spline3,
        spline4,
    )
    derivatives = zerolike(locations)

    return Spline(SP_CONTINENTALNESS, locations, derivatives, child_splines)
end

const SPLINE_STACK = worldspline()
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

# Scale 1 -> rescaling scale 4 with voronoi noise
function getbiome(
        bn::BiomeNoise, coord::NTuple{3, Real}, ::Scale{1};
        skip_shift = false, skip_depth = false, spline = SPLINE_STACK,
    )
    return getbiome(
        bn, voronoi_access(bn.sha[], coord), Scale(4);
        skip_shift, skip_depth, spline,
    )
end

# Scale anything except 1 and 4 -> shift the coordinates to scale 4
function getbiome(
        bn::BiomeNoise, coord::NTuple{3, Real}, ::Scale{S};
        skip_shift = false, skip_depth = false, spline = SPLINE_STACK,
    ) where {S}
    scale = S >> 2
    mid = scale >> 1
    coord_scale4 = coord .* scale .+ mid
    return getbiome(
        bn, coord_scale4, Scale(4);
        skip_shift, skip_depth, spline,
    )
end

# Scale 4 (the main one)
function getbiome(
        bn::BiomeNoise, coord::NTuple{3, Real}, ::Scale{4};
        skip_shift = false, skip_depth = false, spline = SPLINE_STACK,
    )
    result = getbiome_int(bn, coord; spline, skip_shift, skip_depth)
    return Biome(result)
end

function getbiome_int(
        bn::BiomeNoise{V}, coord;
        spline = SPLINE_STACK, skip_shift = false, skip_depth = false,
    ) where {V}
    noiseparams = sample_biomenoises(bn, coord...; skip_shift, skip_depth, spline)
    return climate_to_biome(noiseparams, V)
end

function sample_biomenoises(
        bn::BiomeNoise,
        x, z, y;
        skip_shift = false, skip_depth = false, spline = SPLINE_STACK,
    )
    px, pz = sample_shift(bn, x, z, skip_shift)
    continentalness::Float32 = sample_noise(bn.climate[Continentalness], px, pz)
    erosion::Float32 = sample_noise(bn.climate[Erosion], px, pz)
    weirdness::Float32 = sample_noise(bn.climate[Weirdness], px, pz)
    depth = sample_depth(spline, continentalness, erosion, weirdness, y, skip_depth)

    temperature::Float32 = sample_noise(bn.climate[Temperature], px, pz)
    humidity::Float32 = sample_noise(bn.climate[Humidity], px, pz)

    return map(
        x -> Base.unsafe_trunc(Int64, 10_000.0f0 * x),
        (temperature, humidity, continentalness, erosion, depth, weirdness),
    )
end

function sample_shift(bn::BiomeNoise, x, z, skip_shift::Bool)
    skip_shift && return x, z
    px = sample_noise(bn.climate[Shift], x, z) * 4.0
    pz = sample_noise(bn.climate[Shift], z, 0, x) * 4.0
    return x + px, z + pz
end

@only_float32 eval_weirdness(x) = -3 * (abs(abs(x) - 2 / 3) - 1 / 3)

@only_float32 function sample_depth(spline, c, e, w, y, skip_depth::Bool)
    skip_depth && return 0
    vals = (c, e, eval_weirdness(w), w)
    off = get_spline(spline, vals) + 0.015
    return 1 - (y * 4) / 128 - 83 / 160 + off
end

function climate_to_biome(noise_parameters::NTuple{6}, version::mcvt">=1.18")
    return climate_to_biome(noise_parameters, getbiome_tree(version))
end

function climate_to_biome(noise_parameters::NTuple{6}, biome_tree::BiomeTree)
    idx = get_resulting_node(noise_parameters, biome_tree)
    return extract_biome_index(biome_tree, idx)
end

extract_biome_index(biome_tree::BiomeTree, idx) = (biome_tree.nodes[idx + 1] >> 48) & 0xFF

function get_resulting_node(
        noise_params::NTuple{6},
        biome_tree::BiomeTree,
        alt = 0,
        dist = typemax(UInt64),
        idx = 0,
        depth = 1,
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
    leaf = alt
    inner_start = node >> 48
    inner_end = min(inner_start + step * (biome_tree.order - 1), biome_tree.len_nodes - 1)

    for inner in inner_start:step:inner_end
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
        idx = ((node >> (8 * (i - 1))) & 0xFF) + 1
        dist_square +=
            calculate_distance(noise_params[i], param[idx][2], param[idx][1])
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

function genbiomes!(
        bn::BiomeNoise,
        map3D::WorldMap{3},
        ::Scale{1};
        scheduler = StaticScheduler(; minchunksize = Threads.nthreads()),
        kwargs...,
    )
    tforeach(coordinates(map3D); scheduler) do coord
        @inbounds map3D[coord] = getbiome(bn, coord, Scale(1); kwargs...)
    end
    return nothing
end

function genbiomes!(
        bn::BiomeNoise,
        map3D::WorldMap{3},
        s::Scale{4};
        scheduler = StaticScheduler(; minchunksize = Threads.nthreads()),
        kwargs...,
    )
    tforeach(coordinates(map3D); scheduler) do coord
        map3D[coord] = getbiome(bn, coord, s; kwargs...)
    end
    return nothing
end

function genbiomes!(
        bn::BiomeNoise, map3D::WorldMap{3}, ::Scale{S};
        scheduler = StaticScheduler(; minchunksize = Threads.nthreads()),
        skip_depth = false, skip_shift = true,
    ) where {S}
    # Since with scale higher than 4 accruacy is not needed, there is a possible
    # optimization that involves caching an old_idx variable, that can be passed to the function
    # and return the new one (in addition to the biome) to be used in the next call
    # but it depends on the order of the coordinates iteration. The good order is not the one
    # of coordinates(map3D) so loss of performance is expected
    # (https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-column-major)
    # furthermore it is obviously not thread safe, and it seems like with >=3 threads
    # it is better to use multithreading than this cache optimization

    scale = S >> 2
    mid = scale >> 1
    coord_mid = CartesianIndex(mid, mid, 0)
    return tforeach(coordinates(map3D); scheduler) do coord
        coord_scale4 = coord .* scale .+ coord_mid
        map3D[coord] = getbiome(
            bn, coord_scale4.I, Scale(4);
            skip_depth, skip_shift,
        )
    end
end
#endregion
#region Show
# ---------------------------------------------------------------------------- #
#                                     Show                                     #
# ---------------------------------------------------------------------------- #

function Base.show(io::IO, bn::BiomeNoise{V}) where {V}
    is_initialized = !any(is_undef, bn.climate)
    if !is_initialized
        print(io, "Overworld(≥1.18, uninitialized)")
        return
    end

    sha_status = isnothing(bn.sha[]) ? "unset" : "set"
    return print(io, "Overworld(≥1.18, SHA ", sha_status, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", bn::BiomeNoise{V}) where {V}
    if any(is_undef, bn.climate)
        println(io, "Overworld Dimension (≥1.18, uninitialized)")
        return
    end

    println(io, "Overworld Dimension (≥1.18):")

    # Display SHA status
    sha_status = isnothing(bn.sha[]) ? "not set" : "set"
    println(io, "├ SHA: ", sha_status)
    println(io, "├ MC version: ", V)

    # Display each noise parameter
    for (i, (np_type, noise)) in enumerate(zip(NOISE_PARAMETERS, bn.climate))
        if i < length(bn.climate)
            prefix = "├"
            indent = "│"
        else
            prefix = "└"
            indent = " "
        end

        np_name = nameof(np_type)
        println(io, "$prefix $np_name noise:")

        # Display the noise details with proper indentation
        io_noise = IOBuffer()
        show(IOContext(io_noise, :compact => true), mime, noise)
        noise_lines = split(String(take!(io_noise)), '\n')
        for (j, line) in enumerate(noise_lines)
            if j == 1
                continue  # Skip the title line
            else
                println(io, "$indent ", line)
            end
        end
    end
    return
end

function Base.summary(io::IO, bn::BiomeNoise{V}) where {V}
    if any(is_undef, bn.climate)
        print(io, "Overworld(≥1.18, uninitialized)")
        return
    end

    print(io, "Overworld(≥1.18): ")
    print(io, "SHA: ", isnothing(bn.sha[]) ? "unset" : "set")
    return print(io, ", MC version: ", V)
end

function Base.:(==)(bn1::BiomeNoise{V}, bn2::BiomeNoise{V}) where {V}
    return all(n1 == n2 for (n1, n2) in zip(bn1.climate, bn2.climate)) &&
        bn1.sha[] == bn2.sha[]
end
#endregion
