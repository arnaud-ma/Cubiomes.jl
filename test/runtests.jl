using Test: @testset

@testset "Aqua" begin
    include("aqua.jl")
end

try
    using JavaCall: JavaCall
    JavaCall.init()
catch e
    @warn "Something went wrong with Java. Probably it was not found in the system. Skipping JavaRNG tests."
else
    @testset "JavaRNG" begin
        include("rng.jl")
    end
end
@testset "Noise" begin
    include("noise.jl")
end
