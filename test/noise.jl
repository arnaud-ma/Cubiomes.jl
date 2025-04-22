using Cubiomes.Noises
using Cubiomes.JavaRNG: JavaRandom, JavaXoroshiro128PlusPlus

using Test: @test, @testset, @test_throws
using Test: Test
include("data.jl")

const atol_f64 = 1.0e-15

@testset "Perlin" begin
    function test_perlin_creation(perlin_test, rng)
        rng2 = copy(rng)
        perlin = Noise🎲(Perlin, rng)
        perlin2 = Noise(Perlin, undef)
        setrng!🎲(perlin2, rng2)

        @test perlin == perlin_test
        @test perlin2 == perlin_test
    end

    function test_perlin_sample(args...; result, rng)
        noise = Noise🎲(Perlin, rng)
        @test sample_noise(noise, args...) ≈ result atol = atol_f64
    end

    @testset "isundef" begin
        @test isundef(Noise(Perlin, undef))
        @test !isundef(Noise🎲(Perlin, JavaRandom(42)))
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

        # only x, z, y
        test_perlin_sample(
            -9576.0716474206, 70864.29954649521, -15007.679016448057;
            result = 0.170258628768724,
            rng = JavaRandom(0x9645a8671e48721a),
        )

        # y=0
        test_perlin_sample(
            -274.87601242269534, 3786.384871608427, 0;
            result = 0.15592851862344914,
            rng = JavaRandom(0xd8122f048900922f),
        )
        test_perlin_sample(
            -274.87601242269534, 3786.384871608427;
            result = 0.15592851862344914,
            rng = JavaRandom(0xd8122f048900922f),
        )

        # with yamp and ymin
        test_perlin_sample(
            -358.169229145166, -2856.7553871905966, -3049.3777333918592,
            684.6701337781379337, 1368.5385109903469082; # yamp, ymin
            result = 0.27422491836262886,
            rng = JavaRandom(0x3cf41563fda63f77),
        )

        # with yamp and ymin that are really effective, i.e. min(some_noise(y), ymin) > yamp
        test_perlin_sample(
            3387.428651297631, 7140.267660582517, -11854.03847018979,
            0.01029567770471301, 0.934979378815115;
            result = -0.21469240338734455,
            rng = JavaRandom(0x4a9a8e281b4d812f),
        )
    end

    @testset "sample noise with JavaXoroshiro rng" begin

        # only x, z, y
        test_perlin_sample(
            39274.8390143525, -479.7416496750789, -37913.420796023274;
            result = -0.4502182120751059,
            rng = JavaXoroshiro128PlusPlus(0x3f7d8a0a0b398783),
        )

        # y=0
        test_perlin_sample(
            -29836.64915619664, 24006.59163330684, 0;
            result = -0.0603214999414799,
            rng = JavaXoroshiro128PlusPlus(0x9ec5f928bdaec33f),
        )
        # with yamp and ymin
        test_perlin_sample(
            -8887.462580367594, -17542.71611184543, 22.96449274583,
            684.6701337781379337, 1368.5385109903469082; # yamp, ymin
            result = -0.1584240761398616,
            rng = JavaXoroshiro128PlusPlus(0x6ffebc333019e103),
        )
    end

    @testset "sample simplex" begin
        seed = 0xad47b40a1754efa5
        noise = Noise🎲(Perlin, JavaRandom(seed))
        @test sample_simplex(noise, -17177.694758836762, 59022.880344655736) ≈
            0.2483472791500884 atol = atol_f64
    end

    @testset "show" begin
        noise = Noise🎲(Perlin, JavaRandom(42))
        @test sprint(show, noise) ==
            "Perlin(x=186.26, y=174.91, z=79.03, const_y=0.91, const_index_y=174, const_smooth_y=0.99, amplitude=1.0, lacunarity=1.0, permutations=UInt8[0x46, 0xea, 0x3d, 0x56, 0x2a, 0xb5, 0x20, 0xfd, 0xfc, 0x1a, 0x16, 0xbf, 0xaf, 0xd2, 0x5a, 0x8d, 0x04, 0xb1, 0xcf, 0xc7, 0xee, 0x68, 0x29, 0x33, 0xaa, 0x49, 0xce, 0x30, 0x81, 0x7f, 0xfe, 0x4a, 0xf9, 0x5f, 0x39, 0x42, 0x3b, 0x09, 0xdb, 0x90, 0x8f, 0xf6, 0x41, 0x21, 0x06, 0x53, 0xae, 0x2c, 0x58, 0xf5, 0x73, 0xe1, 0x91, 0xcb, 0x19, 0x78, 0xd0, 0xeb, 0x54, 0x37, 0x5e, 0x31, 0x47, 0xd8, 0x03, 0x32, 0x59, 0x1f, 0x79, 0xc3, 0x7e, 0x5b, 0xe9, 0xa0, 0xf4, 0xd5, 0x63, 0xf2, 0xa9, 0x7c, 0x07, 0x17, 0x3f, 0xa3, 0x3e, 0x8e, 0x6d, 0xa7, 0xe7, 0x93, 0xd1, 0xf7, 0x52, 0x87, 0x55, 0x4b, 0xbc, 0xad, 0x2b, 0x44, 0xc1, 0x3c, 0x5d, 0x62, 0x65, 0x26, 0x50, 0xc8, 0xef, 0x3a, 0xf8, 0x05, 0x2e, 0x8c, 0x15, 0xac, 0xc2, 0x0d, 0x00, 0x86, 0xca, 0x8b, 0xfb, 0xab, 0x98, 0x72, 0x27, 0xe3, 0xc5, 0x6f, 0x6a, 0xc6, 0x69, 0x1e, 0x0e, 0x0c, 0x89, 0x6e, 0xa6, 0x7b, 0x01, 0x84, 0x7a, 0x43, 0xbe, 0x96, 0x9d, 0xa2, 0xb9, 0x70, 0xba, 0x11, 0xb6, 0x92, 0xd4, 0xec, 0xc4, 0x23, 0xc9, 0x57, 0x0a, 0xa5, 0x22, 0xe6, 0xdc, 0x61, 0x40, 0x1c, 0x36, 0x99, 0x71, 0x8a, 0x77, 0x18, 0xb0, 0x60, 0xe2, 0x45, 0xd6, 0xb2, 0x28, 0x95, 0x4f, 0x4e, 0xa8, 0x9f, 0x9a, 0x4d, 0x74, 0x25, 0xed, 0xb3, 0x1d, 0xcd, 0xff, 0xe5, 0x0b, 0x76, 0x9e, 0x7d, 0x94, 0xd9, 0xbd, 0x6b, 0x85, 0x24, 0xb4, 0x75, 0xcc, 0x9b, 0xd3, 0x80, 0xd7, 0x34, 0x0f, 0x2d, 0x4c, 0xf0, 0xc0, 0x14, 0xe0, 0x2f, 0xb8, 0x67, 0x10, 0xdf, 0x38, 0x08, 0xa1, 0x5c, 0x12, 0xf1, 0xdd, 0x64, 0x35, 0xb7, 0x97, 0xf3, 0xfa, 0xbb, 0x82, 0xda, 0x88, 0xde, 0x83, 0x6c, 0xa4, 0x9c, 0x51, 0x48, 0x66, 0x02, 0x13, 0xe4, 0xe8, 0x1b, 0x46]"

        @test repr(MIME"text/plain"(), noise) == """
            Perlin Noise:
            ├ Coordinates: (x=186.26, y=174.91, z=79.03)
            ├ Amplitude: 1.0
            ├ Lacunarity: 1.0
            ├ Constant Y: y=0.9052, index=174, smooth=0.9926
            └ Permutation table: [70, 234, 61, 86, ..., 232, 27, 70]"""
    end
end

@testset "Octaves" begin
    @test_throws "at least one octave" Noise(Octaves{-6}, undef)
    @test_throws "at least one octave" Noise(Octaves{0}, undef)
    @test_throws "octave_min ≤ 1 - N" Noise🎲(Octaves{6}, JavaRandom(42), -2)
    @test_throws BoundsError Noise🎲(
        Octaves{1}, JavaXoroshiro128PlusPlus(42), (1,), 1
    )

    @testset "isundef" begin
        @test isundef(Noise(Octaves{6}, undef))
        @test !isundef(Noise🎲(Octaves{6}, JavaRandom(42), -6))
    end

    function test_octaves_creations(octaves_test, nb, rng, args...)
        rng2 = copy(rng)
        noise = Noise🎲(Octaves{nb}, rng, args...)
        noise2 = Noise(Octaves{nb}, undef)
        setrng!🎲(noise2, rng2, args...)
        @test noise == octaves_test
        @test noise == noise2
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
                octave_test, params.nb, rng, params.amp, params.octave_min
            )
        end
    end

    @testset "sample noise with JavaRandom rng" begin
        function test_octaves_java_sample(nb, omin, args...; result, seed)
            noise = Noise🎲(Octaves{nb}, JavaRandom(seed), omin)
            t = @test sample_noise(noise, args...) ≈ result atol = atol_f64
            if !(t isa Test.Pass)
                @info "nb, omin, args, result, seed = $nb, $omin, $args, $result, $seed"
            end
        end

        # test x, z, y
        test_octaves_java_sample(
            6, -6,
            -55821.65547161641, 78572.68143564471, -59.05810060012, ;
            result = -0.0120778804692121,
            seed = 0x0ab2db9b27318cc3,
        )

        # test y=0
        test_octaves_java_sample(
            6, -6,
            72039.53368288082, 51804.97366043652, 0;
            result = -0.2166285933836845,
            seed = 0x03f966b1c9dd8063,
        )

        # test with yamp and ymin
        test_octaves_java_sample(
            5, -7,
            -88134.5908954708, 91341.66243916987, 52.69376987529392, # x, z, y
            113.4582167462825, 10.558772655520132; # yamp, ymin
            result = -0.1067931195961025,
            seed = 0x547f9a17dcf68d8f,
        )

        # test with yamp and ymin and no y
        test_octaves_java_sample(
            9, -10,
            33860.49100816767, -70117.25276887477, # x, z, y
            113.4582167462825, 10.558772655520132; # yamp, ymin
            result = -0.0846321181639296,
            seed = 0x34e5c56112cddd55,
        )
    end

    @testset "sample noise with Xoroshiro rng" begin
        function test_octaves_xoroshiro_sample(nb, omin, amp, args...; result, seed)
            rng = JavaXoroshiro128PlusPlus(seed)
            noise = Noise🎲(Octaves{nb}, rng, amp, omin)
            @test sample_noise(noise, args...) ≈ result atol = atol_f64
        end

        test_octaves_xoroshiro_sample(
            4, -5,
            (4.2924900488084425, 10.151127186787392, 8.852659985347511, 4.872098229275968),
            -36037.7830286071, -67113.8288679576, -45.96292447528, ;
            result = -1.7785759425550967,
            seed = 0x022843273ec17350,
        )

        test_octaves_xoroshiro_sample(
            2, -3,
            (0.0, 3.6085191731282653, 0.0, 6.120582507763649),
            905.788158662778, -54162.592229314774, 16.88841898837666, ;
            result = -0.3637842988331072,
            seed = 0x6905976105f4f341,
        )

        test_octaves_xoroshiro_sample(
            2, -6,
            (0.0, 3.6085191731282653, 0.0, 0.0, 6.120582507763649),
            905.788158662778, -54162.592229314774, 16.88841898837666, ;
            result = -0.0047320120208560745,
            seed = 0x62342335dd25f7ed,
        )
    end

    @testset "show" begin
        noise = Noise🎲(Octaves{3}, JavaRandom(54), -4)
        @test sprint(show, noise) ==
            "Octaves{3}(a=0.14,l=0.25, a=0.29,l=0.12, a=0.57,l=0.06)"

        @test repr(MIME"text/plain"(), noise) == """
            Perlin Noise Octaves{3}:
            ├ Total amplitude: 1.0
            ├ Octave 1: amplitude=0.1429 (14.3%), lacunarity=0.25
            ├ Octave 2: amplitude=0.2857 (28.6%), lacunarity=0.125
            └ Octave 3: amplitude=0.5714 (57.1%), lacunarity=0.0625"""
    end
end

@testset "Double perlin" begin
    function test_double_creation(double_test, nb, rng, omin)
        rng2 = copy(rng)
        noise = Noise🎲(DoublePerlin{nb}, rng, omin)
        noise2 = Noise(DoublePerlin{nb}, undef)
        setrng!🎲(noise2, rng2, omin)
        @test noise == double_test
        @test noise == noise2
    end

    function test_double_creation_xoroshiro(double_test, nb, rng, amp, omin)
        rng2 = copy(rng)
        noise = Noise🎲(DoublePerlin{nb}, rng, amp, omin)
        noise2 = Noise(DoublePerlin{nb}, undef, amp)
        setrng!🎲(noise2, rng2, amp, omin)
        @test noise == double_test
        @test noise == noise2
    end

    @testset "creation with JavaRandom rng" begin
        for (params, double_test) in DOUBLE_PERLIN_JAVA_RANDOM
            rng = JavaRandom(params.seed)
            test_double_creation(double_test, params.nb, rng, params.octave_min)
        end
    end

    @testset "creation with Xoroshiro rng" begin
        for (params, double_test) in DOUBLE_PERLIN_XOROSHIRO
            rng = JavaXoroshiro128PlusPlus(params.seed)
            test_double_creation_xoroshiro(
                double_test, params.nb, rng, params.amp, params.octave_min
            )
        end
    end

    @testset "sample noise with JavaRandom" begin
        function test_double_perlin_java_sample(nb, omin, args...; result, seed)
            noise = Noise🎲(DoublePerlin{nb}, JavaRandom(seed), omin)
            @test sample_noise(noise, args...) ≈ result atol = atol_f64
        end

        test_double_perlin_java_sample(
            5, -6,
            17482.450698274537, 7823.915987553664, 174.5718261451721;
            result = -0.08095342706617349,
            seed = 0xc3b7144123ebc741,
        )

        test_double_perlin_java_sample(
            3, -2,
            -9746.615351765467, 3506.085844393649, 0;
            result = -0.47050115985495045,
            seed = 0x079e9ea649862878,
        )
    end

    @testset "sample noise with Xoroshiro" begin
        function test_double_perlin_xoroshiro_sample(nb, omin, amp, args...; result, rng)
            noise = Noise🎲(DoublePerlin{nb}, rng, amp, omin)
            @test sample_noise(noise, args...) ≈ result atol = atol_f64
        end

        test_double_perlin_xoroshiro_sample(
            6, -7,
            (
                4.01439625355631,
                4.414662130640904,
                0.9316139068738465,
                3.618707614223964,
                0.07509856745037247,
                2.536358650943736,
            ),
            -38978.750307685776, -28654.026725618372, 182.94483064899111; # x, z, y
            result = -0.82090018133757814,
            rng = JavaXoroshiro128PlusPlus(0xd9836df5ca9672a5),
        )

        test_double_perlin_xoroshiro_sample(
            5, -6,
            (
                0.0,
                4.01439625355631,
                4.414662130640904,
                0.9316139068738465,
                3.0,
                0.0,
                2.536358650943736,
                0.0,
                0.0,
            ),
            -38978.750307685776, -28654.026725618372, 0; # x, z, y
            result = -1.15013160607318987,
            rng = JavaXoroshiro128PlusPlus(0xd9836df5ca9672a5),
        )
    end

    @testset "Show" begin
        rng = JavaXoroshiro128PlusPlus(0xf5f88214b3c71c67, 0x3d198dcdb6de96f0)
        nb, omin = 4, -5
        amp = (4.2924900488084425, 10.151127186787392, 8.852659985347511, 4.872098229275968)
        noise = Noise🎲(DoublePerlin{nb}, rng, amp, omin)
        @test sprint(show, noise) == "DoublePerlin{4}(amplitude=1.33)"
        @test repr(MIME"text/plain"(), noise) == """
            Double Perlin Noise{4}:
            ├ Global amplitude: 1.3333
            ├ Move factor: 1.0181
            ├ Octave Group A:
            │ ├ Total amplitude: 6.5015
            │ ├ Octave 1: amplitude=2.2893 (35.2%), lacunarity=0.0312
            │ ├ Octave 2: amplitude=2.707 (41.6%), lacunarity=0.0625
            │ ├ Octave 3: amplitude=1.1804 (18.2%), lacunarity=0.125
            │ └ Octave 4: amplitude=0.3248 (5.0%), lacunarity=0.25
            └ Octave Group B:
              ├ Total amplitude: 6.5015
              ├ Octave 1: amplitude=2.2893 (35.2%), lacunarity=0.0312
              ├ Octave 2: amplitude=2.707 (41.6%), lacunarity=0.0625
              ├ Octave 3: amplitude=1.1804 (18.2%), lacunarity=0.125
              └ Octave 4: amplitude=0.3248 (5.0%), lacunarity=0.25"""
    end
end
