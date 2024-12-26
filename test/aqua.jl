using Aqua: Aqua
using Cubiomes: Cubiomes

# Test ambiguities separately with only the Cubiomes ones
# Ref: https://github.com/JuliaTesting/Aqua.jl/issues/77
Aqua.test_all(Cubiomes; ambiguities=false)
Aqua.test_ambiguities(Cubiomes)
