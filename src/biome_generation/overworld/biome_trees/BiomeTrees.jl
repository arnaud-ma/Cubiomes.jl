module BiomeTrees

export BiomeTree, get_biome_tree

using ...MCVersions

struct BiomeTree{N}
    order::Int # ? Maybe dispatch this
    steps::NTuple{N, Int32}
    param::Vector{Tuple{Int32, Int32}}
    nodes::Vector{UInt64}
    len_nodes::Int
end

function BiomeTree(; order, steps, param, nodes)
    return BiomeTree(
        order,
        Int32.(steps),
        [Int32.(x) for x in param],
        nodes,
        length(nodes),
    )
end

include("1_18.jl")
include("1_19.jl")
include("1_20.jl")
include("1_19_2.jl")

function get_biome_tree(::Type{<:MCVersion})
    msg = "Biome tree not implemented for this version. Trying to get a biome for a version < 1.18 but
    you used something that is only available for 1.18+"
    throw(ArgumentError(msg))
end

get_biome_tree(::mcvt"1.18") = MC_1_18
get_biome_tree(::mcvt"1.19.2") = MC_1_19_2
get_biome_tree(::mcvt"1.19.4") = MC_1_19
get_biome_tree(::mcvt"1.20") = MC_1_20
get_biome_tree(::mcvt"1.21") = MC_1_20
end
