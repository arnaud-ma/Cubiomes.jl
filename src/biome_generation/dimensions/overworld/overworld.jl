using ..MCVersions

"""
    Overworld(::UndefInitializer, ::mcvt">=1.18")

The Overworld dimension. See [`Dimension`](@ref) for general usage.

!!! warning
    At the moment, only version 1.18 and above are supported. Older versions
    will be supported in the future.

# Minecraft version >= 1.18 specificities

- If the 1:1 scale will never be used, adding `sha=Val(false)` to `setseed!` will
  save a very small amount of time (of the order of 100ns up to 1µs). The sha
  is a precomputed value only used for the 1:1 scale. But the default behavior is
  to compute the sha at each seed change for simplicity.

- Two keyword arguments are added to the biome generation:
  - `skip_depth=Val(false)`: if `Val(true)`, the depth sampling is skipped.
    Time saved: 1/3 of the biome generation time.
  - `skip_shift=Val(false)`: only for the 1:1 and 1:4 scales. If `Val(true)`,
    the shift sampling is skipped. Time saved: 1/10 of the biome generation time.
"""
abstract type Overworld <: Dimension end

include("biome_trees/BiomeTrees.jl")
include("1_18_plus.jl")

Overworld(undef::UndefInitializer, V::mcvt">=1.18") = BiomeNoise{V}(undef)
