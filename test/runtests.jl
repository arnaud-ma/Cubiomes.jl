using TestItems
using Test
using TestItemRunner

@run_package_tests

@testset "Aqua" begin
    include("aqua.jl")
end

# @testset "JavaRNG" begin
#     try
#         using JavaCall: JavaCall
#         JavaCall.init()
#     catch e
#         @warn "Something went wrong with Java. Probably it was not found in the system. Skipping JavaRNG tests."
#     else
#         include("rng.jl")
#     end
# end

@testitem "Noises" begin
    include("noise.jl")
end