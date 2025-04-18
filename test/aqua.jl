using Aqua: Aqua
using Cubiomes: Cubiomes
using Test

# deactivate unbound_args until
# https://github.com/JuliaTesting/Aqua.jl/pull/316 is merged
Aqua.test_all(Cubiomes; unbound_args=false)