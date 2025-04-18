
using Test: @testset

if !("not_aqua" in ARGS)
    @testset "Aqua" begin
        include("aqua.jl")
    end
end

if !("not_javarng" in ARGS)
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
end

if !("not_noise" in ARGS)
    @testset "Noise" begin
        include("noise.jl")
    end
end
