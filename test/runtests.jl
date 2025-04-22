using Test: @testset
using Cubiomes

@testset "Aqua" begin
    include("aqua.jl")
end


if "javarng" in ARGS || "onlyjavarng" in ARGS
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
    if "onlyjavarng" in ARGS
        exit(0)
    end
end
@testset "Noise" begin
    include("noise.jl")
end
