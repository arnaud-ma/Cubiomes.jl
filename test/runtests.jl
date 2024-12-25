if !("not_aqua" in ARGS)
    include("aqua.jl")
end

try
    include("rng.jl")
catch e
    if isa(e, JavaNotFoundException)
        @warn "Java not found in the system. Skipping RNG tests."
    else
        throw(e)
    end
end

include("noise.jl")
