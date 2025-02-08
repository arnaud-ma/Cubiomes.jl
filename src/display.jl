"""
    Display

Module for visualization of results
"""
module Display

using Colors
using RecipesBase
import ..Biomes as b
using ..BiomeGeneration: WorldMap, view2d

export to_color

# TODO using ColorTypes.jl instead of Colors.jl to not depend on Colors.jl only for this
# think to remove Colors.jl from the dependencies after that
const BIOME_COLORS = Dict(
    b.BIOME_NONE => colorant"black",
    b.ocean => colorant"0x000070",
    b.plains => colorant"0x8db360",
    b.desert => colorant"0xfa9418",
    b.windswept_hills => colorant"0x606060",
    b.forest => colorant"0x056621",
    b.taiga => colorant"0x0b6a5f",
    b.swamp => colorant"0x07f9b2",
    b.river => colorant"0x0000ff",
    b.nether_wastes => colorant"0x572526",
    b.the_end => colorant"0x8080ff",
    b.frozen_ocean => colorant"0x7070d6",
    b.frozen_river => colorant"0xa0a0ff",
    b.snowy_plains => colorant"0xffffff",
    b.snowy_tundra => colorant"0xffffff",
    b.snowy_mountains => colorant"0xa0a0a0",
    b.mushroom_fields => colorant"0xff00ff",
    b.mushroom_field_shore => colorant"0xa000ff",
    b.beach => colorant"0xfade55",
    b.desert_hills => colorant"0xd25f12",
    b.wooded_hills => colorant"0x22551c",
    b.taiga_hills => colorant"0x163933",
    b.mountain_edge => colorant"0x72789a",
    b.jungle => colorant"0x507b0a",
    b.jungle_hills => colorant"0x2c4205",
    b.sparse_jungle => colorant"0x60930f",
    b.deep_ocean => colorant"0x000030",
    b.stony_shore => colorant"0xa2a284",
    b.snowy_beach => colorant"0xfaf0c0",
    b.birch_forest => colorant"0x307444",
    b.birch_forest_hills => colorant"0x1f5f32",
    b.dark_forest => colorant"0x40511a",
    b.snowy_taiga => colorant"0x31554a",
    b.snowy_taiga_hills => colorant"0x243f36",
    b.old_growth_pine_taiga => colorant"0x596651",
    b.giant_tree_taiga_hills => colorant"0x454f3e",
    b.windswept_forest => colorant"0x5b7352",
    b.savanna => colorant"0xbdb25f",
    b.savanna_plateau => colorant"0xa79d64",
    b.badlands => colorant"0xd94515",
    b.wooded_badlands => colorant"0xb09765",
    b.badlands_plateau => colorant"0xca8c65",
    b.small_end_islands => colorant"0x4b4bab",
    b.end_midlands => colorant"0xc9c959",
    b.end_highlands => colorant"0xb5b536",
    b.end_barrens => colorant"0x7070cc",
    b.warm_ocean => colorant"0x0000ac",
    b.lukewarm_ocean => colorant"0x000090",
    b.cold_ocean => colorant"0x202070",
    b.deep_warm_ocean => colorant"0x000050",
    b.deep_lukewarm_ocean => colorant"0x000040",
    b.deep_cold_ocean => colorant"0x202038",
    b.deep_frozen_ocean => colorant"0x404090",
    b.seasonal_forest => colorant"0x2f560f",
    b.rainforest => colorant"0x47840e",
    b.shrubland => colorant"0x789e31",
    b.the_void => colorant"0x000000",
    b.sunflower_plains => colorant"0xb5db88",
    b.desert_lakes => colorant"0xffbc40",
    b.windswept_gravelly_hills => colorant"0x888888",
    b.flower_forest => colorant"0x2d8e49",
    b.taiga_mountains => colorant"0x339287",
    b.swamp_hills => colorant"0x2fffda",
    b.ice_spikes => colorant"0xb4dcdc",
    b.modified_jungle => colorant"0x78a332",
    b.modified_jungle_edge => colorant"0x88bb37",
    b.jungle_edge => colorant"0x88bb37", # TODO
    b.old_growth_birch_forest => colorant"0x589c6c",
    b.tall_birch_hills => colorant"0x47875a",
    b.dark_forest_hills => colorant"0x687942",
    b.snowy_taiga_mountains => colorant"0x597d72",
    b.old_growth_spruce_taiga => colorant"0x818e79",
    b.giant_spruce_taiga_hills => colorant"0x6d7766",
    b.giant_tree_taiga => colorant"0x6d7766",
    b.modified_gravelly_mountains => colorant"0x839b7a",
    b.windswept_savanna => colorant"0xe5da87",
    b.shattered_savanna_plateau => colorant"0xcfc58c",
    b.eroded_badlands => colorant"0xff6d3d",
    b.modified_wooded_badlands_plateau => colorant"0xd8bf8d",
    b.modified_badlands_plateau => colorant"0xf2b48d",
    b.bamboo_jungle => colorant"0x849500",
    b.bamboo_jungle_hills => colorant"0x5c6c04",
    b.soul_sand_valley => colorant"0x4d3a2e",
    b.crimson_forest => colorant"0x981a11",
    b.warped_forest => colorant"0x49907b",
    b.basalt_deltas => colorant"0x645f63",
    b.dripstone_caves => colorant"0x4e3012",
    b.lush_caves => colorant"0x283c00",
    b.meadow => colorant"0x60a445",
    b.grove => colorant"0x47726c",
    b.snowy_slopes => colorant"0xc4c4c4",
    b.jagged_peaks => colorant"0xdcdcc8",
    b.frozen_peaks => colorant"0xb0b3ce",
    b.stony_peaks => colorant"0x7b8f74",
    b.deep_dark => colorant"0x031f29",
    b.mangrove_swamp => colorant"0x2ccc8e",
    b.cherry_grove => colorant"0xff91c8",
)

"""
    to_color(b::Biome)
    to_color(w::WorldMap)

Return a color / an array of colors corresponding to a biome. It should only be used for
visualization, since two biomes can have the same color.
"""
to_color(x::b.Biome) = BIOME_COLORS[x]
to_color(x::WorldMap) = to_color.(view2d(x))

# function Plots.plot(map::MCMap{2})#, widen_factor=0.05)
#     colors = to_color.(map)
#     xlims = first(axes(map, 1)), last(axes(map, 1))
#     ylims = first(axes(map, 2)), last(axes(map, 2))

#     # xlims = @. xlims + widen_factor * abs(xlims) * [sign(xlims)...]
#     # ylims = @. ylims + widen_factor * abs(ylims) * [sign(ylims)...]

#     return plot(colors; xlims=xlims, ylims=ylims, grid=:true)
# end

end
