const LAYER_INIT_SHA::UInt64 = typemax(UInt64)

@enum LayerKind begin # old names
    Undefined_Layer
    Continent         # Island
    ZoomFuzzy
    Zoom
    Land              # Add Island
    Land16
    LandB18
    Island            # Remove Too Much Ocean
    Snow              # Add Snow
    Snow16
    Cool              # CoolWarm
    Heat              # HeatIce
    Special
    Mushroom          # Add MushroomIsland
    DeepOcean
    Biome
    Bamboo            # Add Bamboo
    Noise             # River Init
    BiomeEdge
    Hills
    River
    Smooth
    Sunflower         # RareBiome
    Shore
    SwampRiver
    RiverMix
    OceanTemp
    OceanMix
    Voronoi           # VoronoiZoom
    Voronoi114
end

#==============================================================================#
# Essentials
#==============================================================================#

function f(x::Val{T}) where {T}
    return T
end

f(Val(Apple))

mutable struct Layer{kind}
    kind::Val{kind}
    version::MCVersion
    zoom::Int8
    edge::Int8
    scale::Int

    salt::UInt64
    start_salt::UInt64
    start_seed::UInt64

    noise::Union{PerlinNoise,Nothing}
    parent1::Union{Layer,Nothing}
    parent2::Union{Layer,Nothing}
end

function Layer(
    ::Type{kind},
    version::MCVersion,
    zoom::Integer,
    edge::Integer,
    scale::Integer,
    salt::Integer;
    noise::Union{PerlinNoise,Nothing}=nothing,
    parent1::Union{Layer,Nothing}=nothing,
    parent2::Union{Layer,Nothing}=nothing,
) where {kind}
    return Layer(
        kind,
        version,
        Int8(zoom),
        Int8(edge),
        Int(scale),
        UInt64(salt),
        zero(UInt64), # start_salt
        zero(UInt64), # start_seed
        noise,
        parent1,
        parent2,
    )
end

"""
    set_seed!(layer::Layer, world_seed::UInt64)

Apply the given world seed to the layer and all dependent layers.
"""
function set_seed!(layer::Layer, world_seed::UInt64)
    isnothing(layer.parent1) || set_seed!(layer.parent1, world_seed)
    isnothing(layer.parent2) || set_seed!(layer.parent2, world_seed)
    if !isnothing(layer.noise)
        layer.noise = PerlinNoise🎲(JavaRandom(world_seed))
    end
    ls = layer.salt
    # TODO: maybe dispatch instead of if-else
    if iszero(ls)
        # Pre 1.13 the Hills branch stays zero-initialized
        layer.start_salt = zero(UInt64)
        layer.start_seed = zero(UInt64)
    elseif ls == LAYER_INIT_SHA
        # Post 1.14 Voronoi uses SHA256 for initialization
        error("Not implemented")
        # TODO: voronoi sha
        layer.start_salt = world_seed
        layer.start_seed = world_seed
    else
        st = world_seed
        st = mc_step_seed(st, ls)
        st = mc_step_seed(st, ls)
        st = mc_step_seed(st, ls)
        layer.start_salt = st
        layer.start_seed = mc_step_seed(st, zero(UInt64))
    end
    return nothing
end

set_seed!(layer::Layer, world_seed::Integer) = set_seed!(layer, UInt64(world_seed))
function set_seed!(layer::Layer, world_seed::Int64)
    return set_seed!(layer, unsigned(world_seed))
end

"""
    map_layer!(layer::Layer, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int})

Map the layer to the given region. Modifies the `out` matrix in place. The
`width` and `height` arguments are optional and are inferred from the size of
the `out` matrix if not provided.
"""
function map_layer! end

"""
    map_layer(layer::Layer, x::Int, z::Int, width::Int, height::Int):: Matrix{Int}

Map the layer to the given region and return the result matrix.
"""
function map_layer(layer::Layer{K}, x::Int, z::Int, width::Int, height::Int) where {K}
    out = Matrix{Int}(undef, size_out(K, width, height))
    map_layer!(layer, x, z, width, height, out)
    return out
end

#==============================================================================#
# Layers
#==============================================================================#

"""
    is_any_4(id::Integer, a::Integer, b::Integer, c::Integer, d::Integer)

Equivalent to `any(id == x for x in (a, b, c, d))`.
"""
function is_any_4(id::Integer, a::Integer, b::Integer, c::Integer, d::Integer)
    return id == a || id == b || id == c || id == d
end

function select_4(chunk_seed::UInt32, st::UInt32, v00::Int, v10::Int, v01::Int, v11::Int)
    cv00 = (v00 == v10) + (v00 == v01) + (v00 == v11)
    cv10 = (v10 == v00) + (v10 == v01) + (v10 == v11)
    cv01 = (v01 == v00) + (v01 == v10) + (v01 == v11)

    (cv00 > cv10) && (cv00 > cv01) && return v00
    cv10 > cv00 && return v10
    cv01 > cv00 && return v01

    chunk_seed *= muladd(chunk_seed, 1284865837, 4150755663)
    chunk_seed += st
    r = (chunk_seed >> 24) % 3
    r == 0 && return v10
    r == 1 && return v01
    return v11
end

size_out(::Layer{Continent}, width, height) = width, height
function map_layer!(
    layer::Layer{Continent}, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int}
)
    ss = layer.start_seed
    @inbounds for col in 1:height, row in 1:width
        chunk_seed = get_chunk_seed(ss, x + row - 1, z + col - 1)
        out[row, col] = mc_first_is_zero(chunk_seed, 10)
    end

    if (-width < x <= 0) && (-height < z <= 0)
        @inbounds out[-z + 1, -x + 1] = 1
    end
    return nothing
end

function map_layer!(
    layer::Layer{ZoomFuzzy}, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int}
)
    # TODO: implement
    return error("Not implemented")
end

function map_layer!(
    layer::Layer{Zoom}, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int}
)
    return error("Not implemented")
end

# TODO: maybe refactor into small funcs
size_out(::Layer{Land}, width, height) = width + 2, height + 2
function map_layer!(
    layer::Layer{Land}, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int}
)
    parent_x = x - 1
    parent_z = z - 1
    parent_width, parent_height = size_out(layer, width, height)
    map_layer!(layer.parent1, parent_x, parent_z, parent_width, parent_height, out)

    start_salt = layer.start_salt
    start_seed = layer.start_seed
    cs = zero(UInt64)
    id_ocean = id(ocean)

    @inbounds for col in 1:height
        vz0 = @view out[col, :]
        vz1 = @view out[col + 1, :]
        vz2 = @view out[col + 2, :]

        v00 = vz0[1]
        vt0 = vz0[2]
        v02 = vz2[1]
        vt2 = vz2[2]

        for row in 1:width
            v11 = vz1[row + 1]
            v20 = vz0[row + 2]
            v22 = vz2[row + 2]
            v = v11

            if v11 == id_ocean
                if any(!iszero(x) for x in (v00, v20, v02, v22)) # corners have non-ocean
                    cs = get_chunk_seed(start_seed, x + row - 1, z + col - 1)
                    inc = 0
                    v = 1

                    if v00 != id_ocean
                        inc += 1
                        v = v00
                        cs = mc_step_seed(cs, start_salt)
                    end

                    if v20 != id_ocean
                        inc += 1
                        if inc == 1 || mc_first_is_zero(cs, 2)
                            v = v20
                        end
                        cs = mc_step_seed(cs, start_salt)
                    end

                    if v02 != id_ocean
                        inc += 1
                        if inc == 1
                            v = v02
                        elseif inc == 2 && mc_first_is_zero(cs, 2)
                            v = v02
                        elseif inc > 2 && mc_first_is_zero(cs, 3)
                            v = v02
                        end
                        cs = mc_step_seed(cs, start_salt)
                    end

                    if v22 != id_ocean
                        inc += 1
                        if inc == 1 && mc_first_is_zero(cs, 2) ||
                            (inc == 2 && mc_first_is_zero(cs, 2)) ||
                            (inc == 3 && mc_first_is_zero(cs, 3)) ||
                            (inc > 3 && mc_first_is_zero(cs, 4))
                            v = 22
                        end
                        cs = mc_step_seed(cs, start_salt)
                    end

                    if v != id(forest)
                        if !mc_first_is_zero(cs, 3)
                            v = id_ocean
                        end
                    end
                end
            elseif v11 == id(forest)
                # do nothing
            else
                if iszero(v00) || iszero(v20) || iszero(v02) || iszero(v22)
                    cs = get_chunk_seed(start_seed, x + row - 1, z + col - 1)
                    if mc_first_is_zero(cs, 5)
                        v = 0
                    end
                end
                out[col, row] = v
                v00 = vt0
                vt0 = v20
                v02 = vt2
                vt2 = v22
            end
        end
    end
end

size_out(::Layer{Land16}, width, height) = width + 2, height + 2
function map_layer!(
    layer::Layer{Land16}, x::Int, z::Int, width::Int, height::Int, out::Matrix{Int}
)
    parent_x = x - 1
    parent_z = z - 1
    parent_width, parent_height = size_out(layer, width, height)
    map_layer!(layer.parent1, parent_x, parent_z, parent_width, parent_height, out)

    start_salt = layer.start_salt
    start_seed = layer.start_seed
    id_ocean = id(ocean)

    @inbounds for col in 1:height
        vz0 = @view out[col, :]
        vz1 = @view out[col + 1, :]
        vz2 = @view out[col + 2, :]

        v00 = vz0[1]
        vt0 = vz0[2]
        v02 = vz2[1]
        vt2 = vz2[2]

        for row in 1:width
            v11 = vz1[row + 1]
            v20 = vz0[row + 2]
            v22 = vz2[row + 2]
            v = v11

            if v11 == 0 || (v00 == 0 && v20 == 0 && v02 == 0 && v22 == 0)
                cs = get_chunk_seed(start_seed, x + row - 1, z + col - 1)
                inc = 0
                v = 1

                if v00 != id_ocean
                    inc += 1
                    v = v00
                    cs = mc_step_seed(cs, start_salt)
                end

                if v20 != id_ocean
                    inc += 1
                    if inc == 1 || mc_first_is_zero(cs, 2)
                        v = v20
                    end
                    cs = mc_step_seed(cs, start_salt)
                end

                if v02 != id_ocean
                    inc += 1
                    if inc == 1
                        v = v02
                    elseif inc == 2 && mc_first_is_zero(cs, 2)
                        v = v02
                    elseif inc > 2 && mc_first_is_zero(cs, 3)
                        v = v02
                    end
                    cs = mc_step_seed(cs, start_salt)
                end

                if v22 != id_ocean
                    inc += 1
                    if inc == 1 && mc_first_is_zero(cs, 2) ||
                        (inc == 2 && mc_first_is_zero(cs, 2)) ||
                        (inc == 3 && mc_first_is_zero(cs, 3)) ||
                        (inc > 3 && mc_first_is_zero(cs, 4))
                        v = 22
                    end
                    cs = mc_step_seed(cs, start_salt)
                end
                if !mc_first_is_zero(cs, 3)
                    v = (v == id(forest)) ? id(frozen_ocean) : id(ocean)
                end
            end

            out[col, row] = v
            v00 = vt0
            vt0 = v20
            v02 = vt2
            vt2 = v22
        end
    end
end