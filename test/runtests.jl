
if !("not_aqua" in ARGS)
    @testset begin
        include("aqua.jl")
    end
end

try
    using JavaCall: JavaCall
    JavaCall.init()
catch e
    @warn "Something went wrong with Java. Probably it was not found in the system. Skipping RNG tests."
else
    @testset "JavaRNG" begin
        include("rng.jl")
    end
end

@testset "Noise" begin
    include("noise.jl")
end
