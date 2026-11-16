"""
    Display

Module for visualization of results
"""
module Display

using ColorTypes: N0f8, RGB
import ..Biomes as b
using ..BiomeGeneration: WorldMap

export to_color

const C = RGB{N0f8}
const BIOME_COLORS = Dict(
    # --- Oceans and rivers ---
    b.ocean => C(0.0, 0.0, 0.439),
    b.deep_ocean => C(0.0, 0.0, 0.188),
    b.cold_ocean => C(0.125, 0.125, 0.439),
    b.deep_cold_ocean => C(0.125, 0.125, 0.22),
    b.frozen_ocean => C(0.439, 0.439, 0.839),
    b.deep_frozen_ocean => C(0.251, 0.251, 0.565),
    b.lukewarm_ocean => C(0.0, 0.0, 0.565),
    b.deep_lukewarm_ocean => C(0.0, 0.0, 0.251),
    b.warm_ocean => C(0.0, 0.0, 0.675),
    b.deep_warm_ocean => C(0.0, 0.0, 0.314),
    b.river => C(0.0, 0.0, 1.0),
    b.frozen_river => C(0.627, 0.627, 1.0),

    # --- Shores ---
    b.beach => C(0.98, 0.871, 0.333),
    b.snowy_beach => C(0.98, 0.941, 0.753),
    b.stone_shore => C(0.635, 0.635, 0.518),
    b.mushroom_field_shore => C(0.627, 0.0, 1.0),

    # --- Plains and savannas ---
    b.plains => C(0.553, 0.702, 0.376),
    b.sunflower_plains => C(0.71, 0.859, 0.533),
    b.meadow => C(0.376, 0.643, 0.271),
    b.shrubland => C(0.471, 0.62, 0.192),
    b.savanna => C(0.741, 0.698, 0.373),
    b.savanna_plateau => C(0.655, 0.616, 0.392),
    b.shattered_savanna => C(0.898, 0.855, 0.529),
    b.shattered_savanna_plateau => C(0.812, 0.773, 0.549),

    # --- Forests ---
    b.forest => C(0.02, 0.4, 0.129),
    b.flower_forest => C(0.176, 0.557, 0.286),
    b.wooded_hills => C(0.133, 0.333, 0.11),
    b.seasonal_forest => C(0.184, 0.337, 0.059),
    b.cherry_grove => C(1.0, 0.569, 0.784),
    b.birch_forest => C(0.188, 0.455, 0.267),
    b.birch_forest_hills => C(0.122, 0.373, 0.196),
    b.tall_birch_forest => C(0.345, 0.612, 0.424),
    b.tall_birch_hills => C(0.278, 0.529, 0.353),
    b.dark_forest => C(0.251, 0.318, 0.102),
    b.dark_forest_hills => C(0.408, 0.475, 0.259),

    # --- Taigas ---
    b.taiga => C(0.043, 0.416, 0.373),
    b.taiga_hills => C(0.086, 0.224, 0.2),
    b.taiga_mountains => C(0.2, 0.573, 0.529),
    b.snowy_taiga => C(0.192, 0.333, 0.29),
    b.snowy_taiga_hills => C(0.141, 0.247, 0.212),
    b.snowy_taiga_mountains => C(0.349, 0.49, 0.447),
    b.giant_tree_taiga => C(0.427, 0.467, 0.4),
    b.giant_tree_taiga_hills => C(0.271, 0.31, 0.243),
    b.giant_spruce_taiga => C(0.506, 0.557, 0.475),
    b.giant_spruce_taiga_hills => C(0.427, 0.467, 0.4),

    # --- Jungles ---
    b.jungle => C(0.314, 0.482, 0.039),
    b.jungle_edge => C(0.533, 0.733, 0.216),
    b.jungle_hills => C(0.173, 0.259, 0.02),
    b.modified_jungle => C(0.471, 0.639, 0.196),
    b.modified_jungle_edge => C(0.533, 0.733, 0.216),
    b.bamboo_jungle => C(0.518, 0.584, 0.0),
    b.bamboo_jungle_hills => C(0.361, 0.424, 0.016),
    b.rainforest => C(0.278, 0.518, 0.055),

    # --- Swamps ---
    b.swamp => C(0.027, 0.976, 0.698),
    b.swamp_hills => C(0.184, 1.0, 0.855),
    b.mangrove_swamp => C(0.173, 0.8, 0.557),

    # --- Deserts and badlands ---
    b.desert => C(0.98, 0.58, 0.094),
    b.desert_hills => C(0.824, 0.373, 0.071),
    b.desert_lakes => C(1.0, 0.737, 0.251),
    b.badlands => C(0.851, 0.271, 0.082),
    b.badlands_plateau => C(0.792, 0.549, 0.396),
    b.eroded_badlands => C(1.0, 0.427, 0.239),
    b.modified_badlands_plateau => C(0.949, 0.706, 0.553),
    b.wooded_badlands_plateau => C(0.69, 0.592, 0.396),
    b.modified_wooded_badlands_plateau => C(0.847, 0.749, 0.553),

    # --- Mountains and snow ---
    b.mountains => C(0.376, 0.376, 0.376),
    b.gravelly_mountains => C(0.533, 0.533, 0.533),
    b.modified_gravelly_mountains => C(0.514, 0.608, 0.478),
    b.wooded_mountains => C(0.357, 0.451, 0.322),
    b.mountain_edge => C(0.447, 0.471, 0.604),
    b.snowy_mountains => C(0.627, 0.627, 0.627),
    b.snowy_slopes => C(0.769, 0.769, 0.769),
    b.snowy_tundra => C(1.0, 1.0, 1.0),
    b.ice_spikes => C(0.706, 0.863, 0.863),
    b.grove => C(0.278, 0.447, 0.424),
    b.jagged_peaks => C(0.863, 0.863, 0.784),
    b.frozen_peaks => C(0.69, 0.702, 0.808),
    b.stony_peaks => C(0.482, 0.561, 0.455),

    # --- Caves ---
    b.dripstone_caves => C(0.306, 0.188, 0.071),
    b.lush_caves => C(0.157, 0.235, 0.0),
    b.deep_dark => C(0.012, 0.122, 0.161),

    # --- Nether ---
    b.nether_wastes => C(0.341, 0.145, 0.149),
    b.soul_sand_valley => C(0.302, 0.227, 0.18),
    b.basalt_deltas => C(0.392, 0.373, 0.388),
    b.crimson_forest => C(0.596, 0.102, 0.067),
    b.warped_forest => C(0.286, 0.565, 0.482),

    # --- End ---
    b.the_end => C(0.502, 0.502, 1.0),
    b.end_barrens => C(0.439, 0.439, 0.8),
    b.end_midlands => C(0.788, 0.788, 0.349),
    b.end_highlands => C(0.71, 0.71, 0.212),
    b.small_end_islands => C(0.294, 0.294, 0.671),

    # --- Special ---
    b.mushroom_fields => C(1.0, 0.0, 1.0),
    b.the_void => C(0.0, 0.0, 0.0),
    b.BIOME_NONE => C(0.0, 0.0, 0.0),
)

"""
    to_color(b::Biome)
    to_color(w::WorldMap)

Return a color / an array of colors corresponding to a biome. It should only be used for
visualization, since two biomes can have the same color.
"""
to_color(x::b.Biome) = BIOME_COLORS[x]
function to_color(x::WorldMap)
    if b.BIOME_NONE in x
        @warn "The map is not fully populated, some biomes are missing"
    end
    return to_color.(x)
end

end
