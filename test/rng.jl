using Cubiomes
using Supposition
using Test
using JavaCall
JavaCall.init()

@testset "Supposition" begin
    java_random = @jimport "java.util.Random"
    seed_gen = Data.Integers{Int64}()
    stop_gen = filter(>=(0), Data.Integers{Int32}())

    @check function next_Int32_stop(seed=seed_gen, stop=stop_gen)
        rng_java = java_random((jlong,), seed)
        rng_jl = Cubiomes.JavaRNG(seed)
        jcall(rng_java, "nextInt", jint, (jint,), stop+1) == Cubiomes.next🎲(rng_jl, Int32; stop=stop)
    end
end
