
@testitem "Aqua.jl" begin
    # deactivate unbound_args until
    # https://github.com/JuliaTesting/Aqua.jl/pull/316 is merged
    using Aqua: Aqua
    Aqua.test_all(Cubiomes; unbound_args=false)
end