using Cubiomes
using Supposition
using Test
using JavaCall
JavaCall.init()

const java_random_factory = @jimport "java.util.random.RandomGeneratorFactory"
const java_rng = @jimport "java.util.random.RandomGenerator"

# need to use a macro instead of a higher-order function
# because Supposition want the generator not to be nested
macro rng_gen(algorithm::String, rng_jl_type, seed_gen)
    quote
        @composed function rng_gen(seed=$seed_gen)
            rng_factory = jcall(
                java_random_factory, "of", java_random_factory, (JString,), $algorithm
            )
            rng = jcall(rng_factory, "create", java_rng, (jlong,), seed)
            rng_jl = $rng_jl_type(seed)
            return (java=rng, jl=rng_jl)
        end
    end
end

@testset "JavaRandom" begin
    seed_gen = Data.Integers{Int64}()
    rng_gen = @rng_gen("Random", Cubiomes.JavaRandom, Data.Integers{Int64}())
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

    @check function randjump_int(seed=seed_gen, nb=Data.Integers(0, 1000))
        rng = Cubiomes.JavaRandom(seed)
        rng2 = copy(rng)
        Cubiomes.randjump🎲(rng2, Int32, nb)
        for _ in 1:nb
            Cubiomes.next🎲(rng, 31)
        end
        rng == rng2
    end
end

@testset "JavaXoshiro" begin
end
