using Cubiomes: JavaRNG
using Supposition: @check, @composed, Data
using Test: @testset, @test_throws
using JavaCall: @jimport, jcall, jlong, jint, jfloat, jdouble, JString

const java_random_factory = @jimport "java.util.random.RandomGeneratorFactory"
const java_rng = @jimport "java.util.random.RandomGenerator"

# need to use a macro instead of a higher-order function
# because Supposition want the generator not to be nested
macro rng_gen(algorithm::String, rng_jl_type, seed_gen)
    return quote
        @composed function rng_gen(seed = $seed_gen)
            rng_factory = jcall(
                java_random_factory, "of", java_random_factory, (JString,), $algorithm,
            )
            rng = jcall(rng_factory, "create", java_rng, (jlong,), seed)
            rng_jl = $rng_jl_type(seed)
            return (java = rng, jl = rng_jl, seed = seed)
        end
    end
end

macro rng_gen_jl(algorithm::String, rng_jl_type, seed_gen)
    return quote
        @composed rng_gen(seed = $seed_gen) = $rng_jl_type(seed)
    end
end

start_stop_int32_gen = @composed function ordered_int32(
        x = Data.Pairs(Data.Integers{Int32}(), Data.Integers{Int32}())
    )
    sort(abs.([x...]))
end

@testset "Interface" begin
    struct TestRNG <: JavaRNG.AbstractJavaRNG end
    @test_throws MethodError JavaRNG.next🎲(TestRNG(), Int32)
    @test_throws MethodError JavaRNG.randjump🎲(TestRNG(), Int32, 1)
end

@testset "Random" begin
    rng_gen = @rng_gen("Random", JavaRNG.JavaRandom, Data.Integers{Int64}())

    @check function set_seed(seed = Data.Integers{Int64}())
        rng = JavaRNG.JavaRandom(1)
        rng2 = JavaRNG.JavaRandom(seed)
        JavaRNG.set_seed🎲(rng, seed)
        rng == rng2
    end

    @check function next_int_stop(rng = rng_gen, start_stop = start_stop_int32_gen)
        start, stop = start_stop
        java_value =
            jcall(rng.java, "nextInt", jint, (jint,), (stop + 1) - start) + start
        java_value == JavaRNG.next🎲(rng.jl, Int32, start:stop)
    end

    @check function next_float(rng = rng_gen)
        jcall(rng.java, "nextFloat", jfloat, ()) == JavaRNG.next🎲(rng.jl, Float32)
    end

    @check function next_double(rng = rng_gen)
        jcall(rng.java, "nextDouble", jdouble, ()) == JavaRNG.next🎲(rng.jl, Float64)
    end

    @check function next_long(rng = rng_gen)
        jcall(rng.java, "nextLong", jlong, ()) == JavaRNG.next🎲(rng.jl, Int64)
    end

    @check function randjump_int(seed = Data.Integers{Int64}(), nb = Data.Integers(0, 1000))
        rng = JavaRNG.JavaRandom(seed)
        rng2 = copy(rng)
        JavaRNG.randjump🎲(rng2, Int32, nb)
        for _ in 1:nb
            JavaRNG.next🎲(rng, 31)
        end
        rng == rng2
    end
end

@testset "Xoroshiro128PlusPlus" begin
    rng_gen = @rng_gen(
        "Xoroshiro128PlusPlus",
        JavaRNG.JavaXoroshiro128PlusPlus,
        Data.Integers{Int64}()
    )

    @check function set_seed(seed = Data.Integers{Int64}())
        rng = JavaRNG.JavaXoroshiro128PlusPlus(0x00, 0x00)
        rng2 = JavaRNG.JavaXoroshiro128PlusPlus(seed)
        JavaRNG.set_seed🎲(rng, seed)
        rng == rng2
    end

    @check function next_int_stop(rng = rng_gen, start_stop = start_stop_int32_gen)
        start, stop = start_stop
        java_value =
            jcall(rng.java, "nextInt", jint, (jint,), (stop + 1) - start) + start
        java_value == JavaRNG.next🎲(rng.jl, Int32, start:stop)
    end

    @check function next_float(rng = rng_gen)
        jcall(rng.java, "nextFloat", jfloat, ()) == JavaRNG.next🎲(rng.jl, Float32)
    end

    @check function next_double(rng = rng_gen)
        jcall(rng.java, "nextDouble", jdouble, ()) == JavaRNG.next🎲(rng.jl, Float64)
    end

    @check function next_long(rng = rng_gen)
        jcall(rng.java, "nextLong", jlong, ()) == JavaRNG.next🎲(rng.jl, Int64)
    end

    @check function randjump_long(
            seed = Data.Integers{Int64}(), nb = Data.Integers(0, 1000),
        )
        rng = JavaRNG.JavaXoroshiro128PlusPlus(seed)
        rng2 = copy(rng)
        JavaRNG.randjump🎲(rng, UInt64, nb)
        for _ in 1:nb
            JavaRNG.next🎲(rng2, UInt64)
        end
        rng == rng2
    end
end
