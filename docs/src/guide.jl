# # Guide

# This guide covers 90% of use cases.
#
# ## Table of contents
#
# - [Minecraft version](#Minecraft-versions)
# - [Dimension object](#Dimension-objects)
# - [Biome generation](#Biome-generation)
# - [Biome generation on a world map](#Biome-generation-on-a-world-map)
#
# First of all, do not forget to import Cubiomes
using Cubiomes
using ImageShow # hide
using DisplayAs # hide

# ## Minecraft versions

# To get a Minecraft version, simply use the `mcv` keyword
# (short for **M**ine**c**raft **v**ersion).
mcv"1.18"

# Note that the returned value is `mcv"1.18.2"`. This is because Cubiomes.jl focuses only
# on the latest minor version of Minecraft, meaning `mcv"1.18"` is *exactly* the same as
# `mcv"1.18.2"`.
# Generally, everything remains the same between minor versions. But to be safe, ensure
# that the version matches the one you need.

# Comparing versions is possible
mcv"beta1.7" < mcv"1.8"

# However, the main purpose of versions is to link them to a dimension.

# ## Dimension objects

# Before generating anything, we often need to get a specific dimension to work with.
# The three dimensions are:
# - [`Overworld`](@ref)
# - [`Nether`](@ref)
# - [`End`](@ref)
#
# They are all subtypes of [`Dimension`](@ref). To create a new dimension, link it to a version.

overworld = Overworld(undef, mcv"1.18")

# As suggested by the `undef` keyword, the object is currently uninitialized and unusable.
# We need to assign it a seed.

set_seed!(overworld, 999)
overworld

# The seed can be any valid Minecraft seed, i.e., a string or an integer. However, for
# performance reasons, integers are preferred.
#
# The "!" at the end of [`set_seed!`](@ref) follows Julia’s convention, indicating that the
# function modifies the object (`overworld`) in place. This prevents the creation of a new
# object each time a seed is set, allowing reuse of the same `overworld` instance.
# The only constant requirement in a dimension is its version.

# ## Biome generation

# We now have three key pieces of information combined in a single [`Dimension`](@ref) object:
# - the dimension
# - the version
# - the seed

# Now, we just need to call the [`get_biome`](@ref) function, providing our object and a coordinate.

get_biome(overworld, -55, 45, 63)

# The coordinates can be passed as three numbers or as a tuple (x, z, y):

coord = (-55, 45, 63)
get_biome(overworld, coord)

# !!! warning
#     In Cubiomes.jl, the coordinate order is **ALWAYS** `(x, z, y)`.
#     This differs from Minecraft’s order, which is `(x, y, z)`.

# ## Biome generation on a world map

# Let's generate an empty map with x and z ranging from -200 to 200, and `y = 63`.
worldmap = WorldMap(-200:200, -200:200, 63)

# Note that this is a 3D array, even if the size of `y` is 1. The `y` size can be greater than 1 as well.
# Some useful utility functions:
# - [`coordinates`](@ref): returns a collection of coordinates instead of biomes.
# - [`view2d`](@ref): provides a 2D view by removing the `y` axis when its size is 1.
#   Useful for visualization so that Julia recognizes it as 2D. ⚠ This is a view, meaning
#   modifying one also modifies the other. Use `copy` to create an independent map.
# - [`to_color`](@ref): creates a new map with colors representing biomes (e.g., green for forests).
#
# To visualize our map:

to_color(view2d(worldmap))
DisplayAs.PNG(to_color(view2d(worldmap)))# hide

# !!! note
#     If you see a bunch of numbers instead of an image, nothing is wrong.
#     The colors are just not displayed in your environment. You can either:
#     - Use a Jupyter notebook
#     - Save the image using `FileIO`:
#       `using FileIO; save("worldmap.png", to_color(worldmap))`

# The map is currently empty. To populate it with biomes from our `overworld` object, we
# would think about simply iterating over all coordinates and assigning the biome to each.

function populate_map!(overworld, worldmap)
    for coord in coordinates(worldmap)
        worldmap[coord] = get_biome(overworld, coord)
    end
end
populate_map!(overworld, worldmap)
to_color(view2d(worldmap))
DisplayAs.PNG(to_color(view2d(worldmap))) # hide

# And it works! However, it is inefficient. Because of how Minecraft generation works,
# we can optimize the process using algorthims that take advanatage of a global world view.
# For certain dimensions/versions, this can be significantly faster. That's what
# [`gen_biomes!`](@ref) is for.

gen_biomes!(overworld, worldmap)
to_color(view2d(worldmap))
DisplayAs.PNG(to_color(view2d(worldmap))) # hide

# Let's see the performance difference:

@time populate_map!(overworld, worldmap)
#
@time gen_biomes!(overworld, worldmap)

# A world map acts like a standard array; the only difference is that its indices correspond to Minecraft coordinates.
worldmap[-55, 45]

#
worldmap[-255, 45] # show_error

# ## The scale object

# In `get_biome` and `gen_biomes!`, there is an optional final argument: the `Scale` object.
# A scale can be created using 📏"1:N", where N is a power of 4.

worldmap2 = WorldMap(-50:50, -50:50, 16)
gen_biomes!(overworld, worldmap2, 📏"1:4")
to_color(view2d(worldmap2))
DisplayAs.PNG(to_color(view2d(worldmap2))) # hide

# The scale determines the size of square/cube regions where only one block from each region
# is "sampled" and displayed as one pixel. A larger scale results in a more zoomed-out map.
#
# ⚠ When using a scale, **the indices no longer match Minecraft coordinates**.
# Instead, for example, with scale 📏"1:4", they correspond to chunk coordinates.

# The first scales are:
# - `📏"1:1"` — Block scale
# - `📏"1:4"` — Chunk scale
# - `📏"1:16"`, `📏"1:64"`, `📏"1:256"`, `📏"1:1024"`, ..., `📏"1:4^k"` for any integer `k`

# In some versions and dimensions, this approach is much faster than simply dividing the
# coordinates by the scale, since Minecraft's biome generation algorithm inherently divides
# the world into regions multiple times until reaching scale `📏"1:1"`.
