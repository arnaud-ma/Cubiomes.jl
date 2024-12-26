import Cubiomes:
    Noise,
    Noise🎲,
    Perlin,
    JavaRandom,
    JavaXoroshiro128PlusPlus,
    set_rng!🎲,
    sample_noise,
    sample_simplex,
    Octaves

using Test: @test, @testset, @test_throws
include("data.jl")

function test_perlin_creation(perlin_test, rng)
    rng2 = copy(rng)
    perlin = Noise🎲(Perlin, rng)
    perlin2 = Noise(Perlin, undef)
    set_rng!🎲(perlin2, rng2)

    @test perlin == perlin_test
    @test perlin2 == perlin_test
end

function test_sample(noise_type, args...; result, rng)
    noise = Noise🎲(noise_type, rng)
    @test sample_noise(noise, args...) ≈ result atol = 1e-15
end

@testset "Perlin" begin
    test_perlin_sample(args...; result, rng) = test_sample(Perlin, args...; result, rng)

    @testset "creation with JavaRandom rng" begin
        for (seed, perlin_test) in PERLIN_JAVA_RANDOM
            rng = JavaRandom(seed)
            test_perlin_creation(perlin_test, rng)
        end
    end
    @testset "creation with JavaXoroshiro rng" begin
        for (seed, perlin_test) in PERLIN_XOROSHIRO
            rng = JavaXoroshiro128PlusPlus(seed)
            test_perlin_creation(perlin_test, rng)
        end
    end

    @testset "sample noise with JavaRandom rng" begin

        # test x, y, z
        test_perlin_sample(
            -9576.0716474206,
            -15007.679016448057,
            70864.29954649521;
            result=0.170258628768724,
            rng=JavaRandom(0x9645a8671e48721a),
        )

        # test y=0
        test_perlin_sample(
            -274.87601242269534,
            0,
            3786.384871608427;
            result=0.15592851862344914,
            rng=JavaRandom(0xd8122f048900922f),
        )

        # test with yamp and ymin
        test_perlin_sample(
            -358.169229145166,
            -3049.3777333918592,
            -2856.7553871905966,
            684.6701337781379337, # yamp
            1368.5385109903469082; # ymin
            result=0.27422491836262886,
            rng=JavaRandom(0x3cf41563fda63f77),
        )

        # test with yamp and ymin that are really effective, i.e. min(some_noise(y), ymin) > yamp
        test_perlin_sample(
            3387.428651297631,
            -11854.03847018979,
            7140.267660582517,
            0.01029567770471301,
            0.934979378815115;
            result=-0.21469240338734455,
            rng=JavaRandom(0x4a9a8e281b4d812f),
        )
    end

    @testset "sample noise with JavaXoroshiro rng" begin

        # test x, y, z
        test_perlin_sample(
            39274.8390143525,
            -37913.420796023274,
            -479.7416496750789;
            result=-0.4502182120751059,
            rng=JavaXoroshiro128PlusPlus(0x3f7d8a0a0b398783),
        )

        # test y=0
        test_perlin_sample(
            -29836.64915619664,
            0,
            24006.59163330684;
            result=-0.0603214999414799,
            rng=JavaXoroshiro128PlusPlus(0x9ec5f928bdaec33f),
        )
        # test with yamp and ymin
        test_perlin_sample(
            -8887.462580367594,
            22.96449274583,
            -17542.71611184543,
            684.6701337781379337, # yamp
            1368.5385109903469082; # ymin
            result=-0.1584240761398616,
            rng=JavaXoroshiro128PlusPlus(0x6ffebc333019e103),
        )
    end

    @testset "sample simplex" begin
        seed = 0xad47b40a1754efa5
        noise = Noise🎲(Perlin, JavaRandom(seed))
        @test sample_simplex(noise, -17177.694758836762, 59022.880344655736) ≈
              0.2483472791500884 atol = 1e-15
    end
end


function test_octaves_creations(octaves_test, nb, rng, octave_min)
    rng2 = copy(rng)
    noise = Noise🎲(Octaves{nb}, rng, octave_min)
    noise2 = Noise(Octaves{nb}, undef)
    set_rng!🎲(noise2, rng2, octave_min)
    @test noise == octaves_test
    @test noise == noise2
end

@testset "Octaves" begin

    @test_throws ArgumentError Noise(Octaves{-6}, undef)
    @test_throws ArgumentError Noise(Octaves{0}, undef)

    @testset "creation with JavaRandom rng" begin
        for ((seed, nb, octave_min), octaves_test) in OCTAVES_JAVA_RANDOM
            rng = JavaRandom(seed)
            test_octaves_creations(octaves_test, nb, rng, octave_min)
        end
    end
end