module Display

using Colors
using RecipesBase
import ..BiomeGeneration as bg

export to_color

const BIOME_COLORS = Dict(
    bg.ocean => colorant"0x000070",
    bg.plains => colorant"0x8db360",
    bg.desert => colorant"0xfa9418",
    bg.windswept_hills => colorant"0x606060",
    bg.forest => colorant"0x056621",
    bg.taiga => colorant"0x0b6a5f",
    bg.swamp => colorant"0x07f9b2",
    bg.river => colorant"0x0000ff",
    bg.nether_wastes => colorant"0x572526",
    bg.the_end => colorant"0x8080ff",
    bg.frozen_ocean => colorant"0x7070d6",
    bg.frozen_river => colorant"0xa0a0ff",
    bg.snowy_plains => colorant"0xffffff",
    bg.snowy_tundra => colorant"0xffffff",
    bg.snowy_mountains => colorant"0xa0a0a0",
    bg.mushroom_fields => colorant"0xff00ff",
    bg.mushroom_field_shore => colorant"0xa000ff",
    bg.beach => colorant"0xfade55",
    bg.desert_hills => colorant"0xd25f12",
    bg.wooded_hills => colorant"0x22551c",
    bg.taiga_hills => colorant"0x163933",
    bg.mountain_edge => colorant"0x72789a",
    bg.jungle => colorant"0x507b0a",
    bg.jungle_hills => colorant"0x2c4205",
    bg.sparse_jungle => colorant"0x60930f",
    bg.deep_ocean => colorant"0x000030",
    bg.stony_shore => colorant"0xa2a284",
    bg.snowy_beach => colorant"0xfaf0c0",
    bg.birch_forest => colorant"0x307444",
    bg.birch_forest_hills => colorant"0x1f5f32",
    bg.dark_forest => colorant"0x40511a",
    bg.snowy_taiga => colorant"0x31554a",
    bg.snowy_taiga_hills => colorant"0x243f36",
    bg.old_growth_pine_taiga => colorant"0x596651",
    bg.giant_tree_taiga_hills => colorant"0x454f3e",
    bg.windswept_forest => colorant"0x5b7352",
    bg.savanna => colorant"0xbdb25f",
    bg.savanna_plateau => colorant"0xa79d64",
    bg.badlands => colorant"0xd94515",
    bg.wooded_badlands => colorant"0xb09765",
    bg.badlands_plateau => colorant"0xca8c65",
    bg.small_end_islands => colorant"0x4b4bab",
    bg.end_midlands => colorant"0xc9c959",
    bg.end_highlands => colorant"0xb5b536",
    bg.end_barrens => colorant"0x7070cc",
    bg.warm_ocean => colorant"0x0000ac",
    bg.lukewarm_ocean => colorant"0x000090",
    bg.cold_ocean => colorant"0x202070",
    bg.deep_warm_ocean => colorant"0x000050",
    bg.deep_lukewarm_ocean => colorant"0x000040",
    bg.deep_cold_ocean => colorant"0x202038",
    bg.deep_frozen_ocean => colorant"0x404090",
    bg.seasonal_forest => colorant"0x2f560f",
    bg.rainforest => colorant"0x47840e",
    bg.shrubland => colorant"0x789e31",
    bg.the_void => colorant"0x000000",
    bg.sunflower_plains => colorant"0xb5db88",
    bg.desert_lakes => colorant"0xffbc40",
    bg.windswept_gravelly_hills => colorant"0x888888",
    bg.flower_forest => colorant"0x2d8e49",
    bg.taiga_mountains => colorant"0x339287",
    bg.swamp_hills => colorant"0x2fffda",
    bg.ice_spikes => colorant"0xb4dcdc",
    bg.modified_jungle => colorant"0x78a332",
    bg.modified_jungle_edge => colorant"0x88bb37",
    bg.jungle_edge => colorant"0x88bb37", # TODO
    bg.old_growth_birch_forest => colorant"0x589c6c",
    bg.tall_birch_hills => colorant"0x47875a",
    bg.dark_forest_hills => colorant"0x687942",
    bg.snowy_taiga_mountains => colorant"0x597d72",
    bg.old_growth_spruce_taiga => colorant"0x818e79",
    bg.giant_spruce_taiga_hills => colorant"0x6d7766",
    bg.giant_tree_taiga => colorant"0x6d7766",
    bg.modified_gravelly_mountains => colorant"0x839b7a",
    bg.windswept_savanna => colorant"0xe5da87",
    bg.shattered_savanna_plateau => colorant"0xcfc58c",
    bg.eroded_badlands => colorant"0xff6d3d",
    bg.modified_wooded_badlands_plateau => colorant"0xd8bf8d",
    bg.modified_badlands_plateau => colorant"0xf2b48d",
    bg.bamboo_jungle => colorant"0x849500",
    bg.bamboo_jungle_hills => colorant"0x5c6c04",
    bg.soul_sand_valley => colorant"0x4d3a2e",
    bg.crimson_forest => colorant"0x981a11",
    bg.warped_forest => colorant"0x49907b",
    bg.basalt_deltas => colorant"0x645f63",
    bg.dripstone_caves => colorant"0x4e3012",
    bg.lush_caves => colorant"0x283c00",
    bg.meadow => colorant"0x60a445",
    bg.grove => colorant"0x47726c",
    bg.snowy_slopes => colorant"0xc4c4c4",
    bg.jagged_peaks => colorant"0xdcdcc8",
    bg.frozen_peaks => colorant"0xb0b3ce",
    bg.stony_peaks => colorant"0x7b8f74",
    bg.deep_dark => colorant"0x031f29",
    bg.mangrove_swamp => colorant"0x2ccc8e",
    bg.cherry_grove => colorant"0xff91c8",
)

to_color(x::bg.BiomeID) = BIOME_COLORS[x]
to_color(x::AbstractMatrix{bg.BiomeID}) = to_color.(x)

@recipe f(::Type{bg.MCMap{2}}, mc_map::bg.MCMap{2}) = to_color(mc_map)

# function Plots.plot(map::MCMap{2})#, widen_factor=0.05)
#     colors = to_color.(map)
#     xlims = first(axes(map, 1)), last(axes(map, 1))
#     ylims = first(axes(map, 2)), last(axes(map, 2))

#     # xlims = @. xlims + widen_factor * abs(xlims) * [sign(xlims)...]
#     # ylims = @. ylims + widen_factor * abs(ylims) * [sign(ylims)...]

#     return plot(colors; xlims=xlims, ylims=ylims, grid=:true)
# end

end
