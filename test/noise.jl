using Cubiomes:
    Noise,
    Noise🎲,
    Perlin,
    JavaRandom,
    JavaXoroshiro128PlusPlus,
    set_rng!🎲,
    sample_noise,
    sample_simplex,
    Octaves,
    DoublePerlin,
    is_undef

using Test: @test, @testset, @test_throws
include("data.jl")

const atol_f64 = 1e-15

function test_perlin_creation(perlin_test, rng)
    rng2 = copy(rng)
    perlin = Noise🎲(Perlin, rng)
    perlin2 = Noise(Perlin, undef)
    set_rng!🎲(perlin2, rng2)

    @test perlin == perlin_test
    @test perlin2 == perlin_test
end

function test_perlin_sample(args...; result, rng)
    noise = Noise🎲(Perlin, rng)
    @test sample_noise(noise, args...) ≈ result atol = atol_f64
end

@testset "Perlin" begin
    @testset "next perlin" begin
        rng = JavaRandom(42)
    end

    @testset "is_undef" begin
        @test is_undef(Noise(Perlin, undef))
        @test !is_undef(Noise🎲(Perlin, JavaRandom(42)))
    end

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

        # only x, y, z
        test_perlin_sample(
            -9576.0716474206, -15007.679016448057, 70864.29954649521;
            result=0.170258628768724,
            rng=JavaRandom(0x9645a8671e48721a),
        )

        # y=0
        test_perlin_sample(
            -274.87601242269534, 0, 3786.384871608427;
            result=0.15592851862344914,
            rng=JavaRandom(0xd8122f048900922f),
        )

        # with yamp and ymin
        test_perlin_sample(
            -358.169229145166, -3049.3777333918592, -2856.7553871905966,
            684.6701337781379337, 1368.5385109903469082; # yamp, ymin
            result=0.27422491836262886,
            rng=JavaRandom(0x3cf41563fda63f77),
        )

        # with yamp and ymin that are really effective, i.e. min(some_noise(y), ymin) > yamp
        test_perlin_sample(
            3387.428651297631, -11854.03847018979, 7140.267660582517,
            0.01029567770471301, 0.934979378815115;
            result=-0.21469240338734455,
            rng=JavaRandom(0x4a9a8e281b4d812f),
        )
    end

    @testset "sample noise with JavaXoroshiro rng" begin

        # only x, y, z
        test_perlin_sample(
            39274.8390143525, -37913.420796023274, -479.7416496750789;
            result=-0.4502182120751059,
            rng=JavaXoroshiro128PlusPlus(0x3f7d8a0a0b398783),
        )

        # y=0
        test_perlin_sample(
            -29836.64915619664, 0, 24006.59163330684;
            result=-0.0603214999414799,
            rng=JavaXoroshiro128PlusPlus(0x9ec5f928bdaec33f),
        )
        # with yamp and ymin
        test_perlin_sample(
            -8887.462580367594, 22.96449274583, -17542.71611184543,
            684.6701337781379337, 1368.5385109903469082; # yamp, ymin
            result=-0.1584240761398616,
            rng=JavaXoroshiro128PlusPlus(0x6ffebc333019e103),
        )
    end

    @testset "sample simplex" begin
        seed = 0xad47b40a1754efa5
        noise = Noise🎲(Perlin, JavaRandom(seed))
        @test sample_simplex(noise, -17177.694758836762, 59022.880344655736) ≈
              0.2483472791500884 atol = atol_f64
    end
end

function test_octaves_creations(octaves_test, nb, rng, args...)
    rng2 = copy(rng)
    noise = Noise🎲(Octaves{nb}, rng, args...)
    noise2 = Noise(Octaves{nb}, undef)
    set_rng!🎲(noise2, rng2, args...)
    @test noise == octaves_test
    @test noise == noise2
end

function test_octaves_sample(nb, omin, args...; result, rng)
    noise = Noise🎲(Octaves{nb}, rng, omin)
    @test sample_noise(noise, args...) ≈ result atol = atol_f64
end

@testset "Octaves" begin
    @test_throws "at least one octave" Noise(Octaves{-6}, undef)
    @test_throws "at least one octave" Noise(Octaves{0}, undef)
    @test_throws "octave_min ≤ 1 - N" Noise🎲(Octaves{6}, JavaRandom(42), -2)
    @test_throws "octave_min ≤ 1 - N" Noise🎲(
        Octaves{1}, JavaXoroshiro128PlusPlus(42), (1,), 1)

    @testset "is_undef" begin
        @test is_undef(Noise(Octaves{6}, undef))
        @test !is_undef(Noise🎲(Octaves{6}, JavaRandom(42), -6))
    end

    @testset "creation with JavaRandom rng" begin
        for (params, octaves_test) in OCTAVES_JAVA_RANDOM
            rng = JavaRandom(params.seed)
            test_octaves_creations(octaves_test, params.nb, rng, params.octave_min)
        end
    end

    @testset "creation with Xoroshiro rng" begin
        for (params, octave_test) in OCTAVES_XOROSHIRO
            rng = JavaXoroshiro128PlusPlus(params.seed)
            test_octaves_creations(
                octave_test, params.nb, rng, params.amp, params.octave_min)
        end
    end

    @testset "sample noise with JavaRandom rng" begin

        # test x, y, z
        test_octaves_sample(
            6, -6,
            -55821.65547161641, -59.05810060012, 78572.68143564471;
            result=-0.0120778804692121,
            rng=JavaRandom(0x0ab2db9b27318cc3),
        )

        # test y=0
        test_octaves_sample(
            6, -6,
            72039.53368288082, 0, 51804.97366043652;
            result=-0.2166285933836845,
            rng=JavaRandom(0x03f966b1c9dd8063),
        )

        # test with yamp and ymin
        test_octaves_sample(
            5, -7,
            -88134.5908954708, 52.69376987529392, 91341.66243916987, # x, y, z
            113.4582167462825, 10.558772655520132; # yamp, ymin
            result=-0.1067931195961025,
            rng=JavaRandom(0x547f9a17dcf68d8f),
        )

        # test with yamp and ymin and y=nothing
        test_octaves_sample(
            9, -10,
            33860.49100816767, nothing, -70117.25276887477, # x, y, z
            113.4582167462825, 10.558772655520132; # yamp, ymin
            result=-0.0846321181639296,
            rng=JavaRandom(0x34e5c56112cddd55),
        )
    end

    # TODO: sample noise with Xoroshiro
end

@testset "Double perlin" begin
    function test_double_creation(double_test, nb, rng, args...)
        rng2 = copy(rng)
        noise = Noise🎲(DoublePerlin{nb}, rng, args...)
        noise2 = Noise(DoublePerlin{nb}, undef)
        set_rng!🎲(noise2, rng2, args...)
        @test noise == double_test
        @test noise == noise2
    end

    @testset "creation with JavaRandom rng" begin
        for (params, double_test) in DOUBLE_PERLIN_JAVA_RANDOM
            rng = JavaRandom(params.seed)
            test_double_creation(double_test, params.nb, rng, params.octave_min)
        end
    end

    # @testset "creation with Xoroshiro rng" begin
    #     for (params, double_test) in DOUBLE_PERLIN_XOROSHIRO
    #         rng = JavaXoroshiro128PlusPlus(params.seed)
    #     end
    # end
end
