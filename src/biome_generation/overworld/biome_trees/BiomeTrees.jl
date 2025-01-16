module BiomeTrees

export biome_trees

@kwdef struct BiomeTree{N}
    order::Int # ? Maybe dispatch this
    steps::NTuple{N, Int32}
    param::Vector{Tuple{Int32, Int32}}
    nodes::Vector{UInt64}
end

function BiomeTree(order, steps, param, nodes)
    return BiomeTree(
        order,
        Int32.(steps),
        [Int32.(x) for x in param],
        nodes,
    )
end

include("1_18.jl")
include("1_19.jl")
include("1_20.jl")
include("1_19_2.jl")

const biome_trees = (
    v1_18=MC_1_18,
    v1_19=MC_1_19,
    v1_20=MC_1_20,
    v1_19_2=MC_1_19_2,
)
end
