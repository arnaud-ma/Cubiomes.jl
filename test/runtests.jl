using Test: @testset
using Cubiomes

if "javarng" in ARGS || "onlyjavarng" in ARGS
    try
        using JavaCall: JavaCall
        JavaCall.init()
    catch e
        @warn "Something went wrong with Java. Ignorging the error and continue the tests. \
         Error: \n $(sprint(showerror, e))"
    end
    @testset "JavaRNG" begin
        include("rng.jl")
    end
    if "onlyjavarng" in ARGS
        exit(0)
    end
end

@testset "Aqua" begin
    include("aqua.jl")
end


@testset "Noise" begin
    include("noise.jl")
end
