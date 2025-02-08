# # Guide

# This guide should cover 90% of the use cases.
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

# ## Minecraft versions

# To get a Minecract version, simply use the `mcv` keyword
# (stands for **M**ine**c**raft **v**ersion).
mcv"1.18"

# Not that is is returned `mcv"1.18.2"`. This is because Cubiomes.jl only focuses on the
# latest mino version of Minecrat, and so `mcv"1.18"` is *exactly* the same as `mcv'1.18`.
# Generally, everything remains the same between minor versions. But to be safe, be sure to
# verify that the version is the sme as the one you are looking for.

# Comparing versions is possible
mcv"beta1.7" < mcv"1.8"

# But the main uses of the versions is to link them to a dimension.

# ## Dimension objects

# Before generating something, we often need to get a specific dimension to work with. The
# three dimensions are:
# - [`Overworld`](@ref)
# - [`Nether`](@ref)
# - [`End`](@ref)
#
# They all are subtypes of [`Dimension`](@ref). To create a new dimension, link it to a
# version

overworld = Overworld(undef, mcv"1.18")

# As suggests the `undef` word, the object is not defined and completely useless at the
# moment. We need to give it a seed to eat

set_seed!(overworld, 999)
overworld

# The seed can be any valid Minecraft seed, i.e. a string or an integer. But if performance
# is a concern, it is better to use an integer.
#
# The "!" at the end of [`set_seed!`](@ref) is a Julia convention to indicate that the function
# modifies an object (in this case `overworld`) inplace. It allows to avoid creating a new
# object each time the seed set, keeping the same `overworld` for different seeds.
# The only thing that needs to be constant in a dimension is the version.

# ## Biome generation

# We now have three information combined in a single [`Dimension`](@ref) object:
# - the dimension
# - the version
# - the seed

# Then we just have to use the [`get_biome`](@ref) function, giving it our object and a coordinate.

get_biome(overworld, -55, 45, 63)

# The coordinate can be passed as three numbers or as a tuple (x, z, y)

coord = (-55, 45, 63)
get_biome(overworld, coord)

# !!! warning
#     In Cubiomes.jl, the order of the coordinates is **ALWAYS** `(x, z, y)`.
#     This is different from the order used in Minecraft, which is `(x, y, z)`.

# ## Biome generation on a world map

# Let's generate an empty map with x and z from -100 to 100 and ``y=63``.
worldmap = WorldMap(-200:200, -200:200, 63)

# Note that it is a 3d array, even if the size of `y` is 1. The size of `y` can be other than 1
# too. Some utility functions are:
# - [`coordinates`](@ref): collection of the coordinates instead of the biomes.
# - [`view2d`](@ref): get a view withouit the `y` ax if its size is 1.
#   Useful for visualization so that Julia understands it's 2d. ⚠ This is a view, so modifying one also modifies
#   the other. Use `copy` to get an independant map.
# - [`to_color`](@ref): new map but with nice colors instead of the biomes (for example green for a forest).
#
# So to visualize our map, we can do

to_color(worldmap)
# !!! note
#     If instead of the image, you see a bunch of numbers, nothing is wrong. It's just that
#     the colors are not displayed in your environment. You can either:
#     - Use a Jupyter notebook
#     - Save the image with `using FileIO` and `save("worldmap.png", to_color(worldmap))`


# Of course now it is an empty map. We need to fill it with the biomes of
# our `overworld` object.
#
# To fill the map, we can think about simply looping over the coordinates and call
# [`get_biome`](@ref) on each block.
for coord in coordinates(worldmap)
    worldmap[coord] = get_biome(overworld, coord)
end
to_color(worldmap)

# And it works! But it's not very efficient. Because of how Minecraft generation works,
# we can use the global world view to do some optimizations. For some dimensions/versions,
# it can be much faster. That's what gen_biomes! is for.
gen_biomes!(overworld, worldmap)
to_color(worldmap)

# A world map is a basic array, it's just that the indices are the same as the coordinates
# of Minecraft.
worldmap[-55, 45]
#
worldmap[-155, 45] # show_error
#
# ## The scale object
# In `get_biome` and `gen_biomes!`, there is a last optional argument: the `Scale` object.
# The scale can be created with 📏"1:N", N being a power of 4. Let's show what it does.

worldmap2 = WorldMap(-50:50, -50:50, 16)
gen_biomes!(overworld, worldmap2, 📏"1:4")
to_color(worldmap2)

# So the scale represents the side of a square/cube region of the map where only one block
# from the region is taken into account and take one pixel. The bigger the scale, the more
# the map is zoomed out. Be aware that now the indices are **NOT** the same as the coordinates
# of Minecraft. Instead, for example for scale 📏"1:4" they correspond to the chunk coordinates.

# The first scales are:
# - `📏"1:1"` the block scale
# - `📏"1:4"` the chunk scale
# - `📏"1:16"`, `📏"1:64"`, `📏"1:256"`, `📏"1:1024"`, ..., `📏"1:4^k"` for any integer k

# In some versions/dimensions, it can be much faster than simply dividing the coordinates
# by the scale, because the original Minecraft generation algorithm is done by dividing the
# world into regions multiple times until the scale is `📏"1:1"`. 
