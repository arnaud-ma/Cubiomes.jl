# include("infra.jl")

# abstract type SurfaceNoise end

# # TODO: SurfaceNoiseOverworld

# struct SurfaceNoiseEnd <: SurfaceNoise
#     xz_scale::Float64
#     y_scale::Float64

#     xz_factor::Float64
#     y_factor::Float64

#     octave_min::OctaveNoise{16}
#     octave_max::OctaveNoise{16}
#     octave_main::OctaveNoise{8}

#     # octaves::Vector{PerlinNoise}
# end

# function _init_octaves_surface_noise(rng::JavaRNG)
#     return (
#         OctaveNoise🎲(rng, Val(16), -15), # octave_min
#         OctaveNoise🎲(rng, Val(16), -15), # octave_max
#         OctaveNoise🎲(rng, Val(8), -7), # octave_main
#     )
# end

# _init_octaves_surface_noise(seed::Integer) = _init_octaves_surface_noise(JavaRNG(seed))

# function SurfaceNoise(seed::Integer, dim::Val{DIM_END})
#     omin, omax, om = _init_octaves_surface_noise(seed)
#     return SurfaceNoiseEnd(2.0, 1.0, 80.0, 160.0, omin, omax, om)
# end

# function sample(surface_noise::SurfaceNoise, x, y, z)
#     xz_scale = 684.412 * surface_noise.xz_scale
#     y_scale = 684.412 * surface_noise.y_scale
#     xz_step = xz_scale / surface_noise.xz_factor
#     y_step = y_scale / surface_noise.y_factor

#     min_noise = zero(Float64)
#     max_noise = zero(Float64)
#     main_noise = zero(Float64)

#     persist = one(Float64)
#     contrib = one(Float64)

#     for i in 1:16
#         dx = x * xz_scale * persist
#         dy = y * y_scale * persist
#         dz = z * xz_scale * persist
#         sy = y_scale * persist
#         ty = y * sy

#         min_noise += sample(surface_noise.octave_min[i], dx, dy, dz, sy, ty) * contrib
#         max_noise += sample(surface_noise.octave_max[i], dx, dy, dz, sy, ty) * contrib

#         if i <= 8
#             dx = x * xz_step * persist
#             dy = y * y_step * persist
#             dz = z * xz_step * persist
#             sy = y_step * persist
#             ty = y * sy
#             main_noise += sample(surface_noise.octave_main[i], dx, dy, dz, sy, ty) * contrib
#         end
#         persist *= 0.5
#         contrib *= 2.0
#     end

#     return clamped_lerp(0.5 + 0.05 * main_noise, min_noise / 512, max_noise / 512)
# end

# noise = SurfaceNoise(1, Val(DIM_END));

# sample(noise, 0, 0, 0)
