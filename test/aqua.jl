using Test: @testset
import Aqua
using Cubiomes: Cubiomes
@testset "Aqua.jl" begin
    # Test ambiguities separately without Base and Core
    # Ref: https://github.com/JuliaTesting/Aqua.jl/issues/77
    Aqua.test_all(Cubiomes; ambiguities=false)
    Aqua.test_ambiguities(Cubiomes)
end