module BiomeTrees

export biome_trees, BiomeTree, get_biome_tree

import ...Cubiomes

struct BiomeTree{N}
    order::Int # ? Maybe dispatch this
    steps::NTuple{N, Int32}
    param::Vector{Tuple{Int32, Int32}}
    nodes::Vector{UInt64}
    len_nodes::Int
end

function BiomeTree(;order, steps, param, nodes)
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

function get_biome_tree(::Val{Version}) where Version
    if Version isa Cubiomes.MCVersions
        msg = "Biome tree not implemented for this version. Trying to get a biome for a version < 1.18 but
        you used something that is only available for 1.18+"
        throw(ArgumentError(msg))
    end
    throw(MethodError(get_biome_tree, (Version,), :Version))
end

get_biome_tree(::Val{Cubiomes.MC_1_18}) = MC_1_18
get_biome_tree(::Val{Cubiomes.MC_1_19}) = MC_1_19
get_biome_tree(::Val{Cubiomes.MC_1_20}) = MC_1_20
get_biome_tree(::Val{Cubiomes.MC_1_19_2}) = MC_1_19_2

const biome_trees = (
    v1_18=MC_1_18,
    v1_19=MC_1_19,
    v1_20=MC_1_20,
    v1_19_2=MC_1_19_2,
)
end
