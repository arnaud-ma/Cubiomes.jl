using Cubiomes
using Supposition
using Test
using JavaCall
JavaCall.init()

const java_random = @jimport "java.util.Random"

const seed_gen = Data.Integers{Int64}()
const rng_gen = @composed function rng_gen_(seed=Data.Integers{Int64}())
    rng_java = java_random((jlong,), seed)
    rng_jl = Cubiomes.JavaRNG(seed)
    return (java=rng_java, jl=rng_jl)
end

@testset "JavaRNG" begin
    stop_gen = filter(>=(0), Data.Integers{Int32}())
    @check function next_Int_stop(rng=rng_gen, stop=stop_gen)
        jcall(rng.java, "nextInt", jint, (jint,), stop + 1) ==
        Cubiomes.next🎲(rng.jl, Int32; stop=stop)
    end

    @check function next_float(rng=rng_gen)
        jcall(rng.java, "nextFloat", jfloat, ()) == Cubiomes.next🎲(rng.jl, Float32)
    end

    @check function next_double(rng=rng_gen)
        jcall(rng.java, "nextDouble", jdouble, ()) == Cubiomes.next🎲(rng.jl, Float64)
    end

    @check function next_long(rng=rng_gen)
        jcall(rng.java, "nextLong", jlong, ()) == Cubiomes.next🎲(rng.jl, Int64)
    end

    nb_jump_gen = Data.Integers(0, 1000)
    @check function randjump_int(seed=seed_gen, nb=nb_jump_gen)
        rng = Cubiomes.JavaRNG(seed)
        rng2 = copy(rng)
        Cubiomes.randjump🎲(rng2, Int32, nb)
        for _ in 1:nb
            Cubiomes.next🎲(rng, 31)
        end
        rng == rng2
    end
end
