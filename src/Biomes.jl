module Biomes

export Biome, isnone, biome_exists, is_overworld, mutated, category, are_similar, is_mesa,
    is_shallow_ocean, is_deep_ocean, is_oceanic, is_snowy

using CEnum
using ..MCVersions

# TODO: a module for the biomes instead of a raw file

#! format: off
@cenum(
    Biome::UInt8,

    ocean =                   0,
    plains =                  1,
    desert =                  2,
    mountains =               3,  extremeHills = 3,
    forest =                  4,
    taiga =                   5,
    swamp =                   6,  swampland = 6,
    river =                   7,
    nether_wastes =           8,  hell=8,
    the_end =                 9,  sky = 9,
    frozen_ocean =            10,  frozenOcean = 10,
    frozen_river =            11,  frozenRiver = 11,
    snowy_tundra =            12,  icePlains = 12,
    snowy_mountains =         13,  iceMountains = 13,
    mushroom_fields =         14,  mushroomIsland = 14,
    mushroom_field_shore =    15,  mushroomIslandShore = 15,
    beach =                   16,
    desert_hills =            17,  desertHills = 17,
    wooded_hills =            18,  forestHills = 18,
    taiga_hills =             19,  taigaHills = 19,
    mountain_edge =           20,  extremeHillsEdge = 20,
    jungle =                  21,
    jungle_hills =            22,  jungleHills = 22,
    jungle_edge =             23,  jungleEdge = 23,
    deep_ocean =              24,  deepOcean = 24,
    stone_shore =             25,  stoneBeach = 25,
    snowy_beach =             26,  coldBeach = 26,
    birch_forest =            27,  birchForest = 27,
    birch_forest_hills =      28,  birchForestHills = 28,
    dark_forest =             29,  roofedForest = 29,
    snowy_taiga =             30,  coldTaiga = 30,
    snowy_taiga_hills =       31,  coldTaigaHills = 31,
    giant_tree_taiga =        32,  megaTaiga = 32,
    giant_tree_taiga_hills =  33,  megaTaigaHills = 33,
    wooded_mountains =        34,  extremeHillsPlus = 34,
    savanna =                 35,
    savanna_plateau =         36,  savannaPlateau = 36,
    badlands =                37,  mesa = 37,
    wooded_badlands_plateau = 38,  mesaPlateau_F = 38,
    badlands_plateau =        39,  mesaPlateau = 39,
    small_end_islands =       40,
    end_midlands =            41,
    end_highlands =           42,
    end_barrens =             43,
    warm_ocean =              44,  warmOcean = 44,
    lukewarm_ocean =          45,  lukewarmOcean = 45,
    cold_ocean =              46,  coldOcean = 46,
    deep_warm_ocean =         47,  warmDeepOcean = 47,
    deep_lukewarm_ocean =     48,  lukewarmDeepOcean = 48,
    deep_cold_ocean =         49,  coldDeepOcean = 49,
    deep_frozen_ocean =       50,  frozenDeepOcean = 50,
    seasonal_forest =         51,
    rainforest =              52,
    shrubland =               53,

    the_void = 127,

    # mutated variants
    sunflower_plains =                 1 + 128,
    desert_lakes =                     2 + 128,
    gravelly_mountains =               3 + 128,
    flower_forest =                    4 + 128,
    taiga_mountains =                  5 + 128,
    swamp_hills =                      6 + 128,
    ice_spikes =                       12 + 128,
    modified_jungle =                  21 + 128,
    modified_jungle_edge =             23 + 128,
    tall_birch_forest =                27 + 128,
    tall_birch_hills =                 28 + 128,
    dark_forest_hills =                29 + 128,
    snowy_taiga_mountains =            30 + 128,
    giant_spruce_taiga =               32 + 128,
    giant_spruce_taiga_hills =         33 + 128,
    modified_gravelly_mountains =      34 + 128,
    shattered_savanna =                35 + 128,
    shattered_savanna_plateau =        36 + 128,
    eroded_badlands =                  37 + 128,
    modified_wooded_badlands_plateau = 38 + 128,
    modified_badlands_plateau =        39 + 128,

    # 1.14
    bamboo_jungle =               168,
    bamboo_jungle_hills =         169,
    # 1.16
    soul_sand_valley =            170,
    crimson_forest =              171,
    warped_forest =               172,
    basalt_deltas =               173,
    # 1.17
    dripstone_caves =             174,
    lush_caves =                  175,
    # 1.18
    meadow =                      177,
    grove =                       178,
    snowy_slopes =                179,
    jagged_peaks =                180,
    frozen_peaks =                181,
    stony_peaks =                 182,
    old_growth_birch_forest =     27 + 128, # tall_birch_forest
    old_growth_pine_taiga =       32 + 128, # giant_tree_taiga
    old_growth_spruce_taiga =     32 + 128, # giant_tree_taiga
    snowy_plains =                12 + 128, # snowy_tundra
    sparse_jungle =               23 + 128, # jungle_edge
    stony_shore =                 25, # stone_shore
    windswept_hills =             3, # mountains
    windswept_forest =            34, # wooded_mountains
    windswept_gravelly_hills =    3 + 128, # gravelly_mountains
    windswept_savanna =           35 + 128, # shattered_savanna
    wooded_badlands =             38, # wooded_badlands_plateau
    # 1.19
    deep_dark =                   183,
    mangrove_swamp =              184,
    # 1.20
    cherry_grove =                185,
    BIOME_NONE = typemax(UInt8)
)
#! format: on
Biome = Biome
isnone(biome::Biome) = biome == BIOME_NONE
Base.transpose(x::Biome) = x

@inline function biome_exists(::mcvt">= 1.20", biome::Biome)
    return biome_exists(mcv"1.19", biome) || biome == cherry_grove
end

@inline function biome_exists(::mcvt"1.19<= x < 1.20", biome::Biome)
    return biome_exists(mcv"1.18", biome) || biome == deep_dark || biome == mangrove_swamp
end

@inline function biome_exists(::mcvt"1.18 <= x < 1.19", biome::Biome)
    #      nether >= 1.16
    return biome == soul_sand_valley ||
           biome == crimson_forest ||
           biome == warped_forest ||
           biome == basalt_deltas ||
           #      end >= 1.9
           biome == small_end_islands ||
           biome == end_midlands ||
           biome == end_highlands ||
           biome == end_barrens ||
           #      overworld
           biome == ocean ||
           biome == plains ||
           biome == desert ||
           biome == mountains ||
           biome == forest ||
           biome == taiga ||
           biome == swamp ||
           biome == river ||
           biome == nether_wastes ||
           biome == the_end ||
           biome == frozen_ocean ||
           biome == frozen_river ||
           biome == snowy_tundra ||
           biome == mushroom_fields ||
           biome == beach ||
           biome == jungle ||
           biome == jungle_edge ||
           biome == deep_ocean ||
           biome == stone_shore ||
           biome == snowy_beach ||
           biome == birch_forest ||
           biome == dark_forest ||
           biome == snowy_taiga ||
           biome == giant_tree_taiga ||
           biome == wooded_mountains ||
           biome == savanna ||
           biome == savanna_plateau ||
           biome == badlands ||
           biome == wooded_badlands_plateau ||
           biome == badlands_plateau ||
           biome == sunflower_plains ||
           biome == desert_lakes ||
           biome == gravelly_mountains ||
           biome == flower_forest ||
           biome == taiga_mountains ||
           biome == swamp_hills ||
           biome == ice_spikes ||
           biome == modified_jungle ||
           biome == modified_jungle_edge ||
           biome == tall_birch_forest ||
           biome == dark_forest_hills ||
           biome == snowy_taiga_mountains ||
           biome == giant_spruce_taiga ||
           biome == giant_spruce_taiga_hills ||
           biome == modified_gravelly_mountains ||
           biome == shattered_savanna ||
           biome == shattered_savanna_plateau ||
           biome == eroded_badlands ||
           biome == modified_wooded_badlands_plateau ||
           biome == modified_badlands_plateau
end

@inline function biome_exists(::mcvt"beta1.7", biome::Biome)
    return biome == plains ||
           biome == desert ||
           biome == forest ||
           biome == taiga ||
           biome == swamp ||
           biome == snowy_tundra ||
           biome == savanna ||
           biome == seasonal_forest ||
           biome == rainforest ||
           biome == shrubland ||
           biome == ocean ||
           biome == frozen_ocean
end

@inline function biome_exists(version::Type{<:MCVersion}, biome::Biome)
    if version <= mcv"beta1.8"
        biome == frozen_ocean ||
            biome == frozen_river ||
            biome == snowy_tundra ||
            biome == mushroom_fields ||
            biome == mushroom_field_shore ||
            biome == the_end && return false
    end

    if version <= mcv"1.0"
        biome == snowy_mountains ||
            biome == beach ||
            biome == desert_hills ||
            biome == wooded_hills ||
            biome == taiga_hills ||
            biome == mountain_edge && return false
    end

    ocean <= biome <= mountain_edge && return true
    jungle <= biome <= jungle_hills && return version >= mcv"1.2"
    jungle_edge <= biome <= badlands_plateau && return version >= mcv"1.7"
    small_end_islands <= biome <= end_barrens && return version >= mcv"1.9"
    warm_ocean <= biome <= deep_frozen_ocean && return version >= mcv"1.13"

    biome == the_void && return version >= mcv"1.9"
    biome == sunflower_plains ||
        biome == desert_lakes ||
        biome == gravelly_mountains ||
        biome == flower_forest ||
        biome == taiga_mountains ||
        biome == swamp_hills ||
        biome == ice_spikes ||
        biome == modified_jungle ||
        biome == modified_jungle_edge ||
        biome == tall_birch_forest ||
        biome == tall_birch_hills ||
        biome == dark_forest_hills ||
        biome == snowy_taiga_mountains ||
        biome == giant_spruce_taiga ||
        biome == giant_spruce_taiga_hills ||
        biome == modified_gravelly_mountains ||
        biome == shattered_savanna ||
        biome == shattered_savanna_plateau ||
        biome == eroded_badlands ||
        biome == modified_wooded_badlands_plateau ||
        biome == modified_badlands_plateau && return version >= mcv"1.7"

    biome == bamboo_jungle || biome == bamboo_jungle_hills && return version >= mcv"1.14"

    biome == soul_sand_valley ||
        biome == crimson_forest ||
        biome == warped_forest ||
        biome == basalt_deltas && return version >= mcv"1.16.1"

    biome == dripstone_caves || biome == lush_caves && return version >= mcv"1.17"

    return false
end

@inline function is_overworld(version::Type{<:MCVersion}, biome::Biome)::Bool
    if !biome_exists(biome, version)
        return false
    end
    end_barrens <= biome <= small_end_islands && return false
    basalt_deltas <= biome <= soul_sand_valley && return false
    biome == nether_wastes && return false
    biome == the_end && return false
    biome == frozen_ocean && return version <= mcv"1.16" || version == mcv"1.13"
    biome == mountain_edge && return version <= mcv"1.6"
    biome == deep_warm_ocean || biome == the_void && return false
    biome == tall_birch_forest && return version <= mcv"1.8" || version >= mcv"1.11"
    biome == dripstone_caves || biome == lush_caves && return version >= mcv"1.18"
    return true
end

@inline function mutated(biome::Biome, version::Type{<:MCVersion})::Biome
    biome == plains && return sunflower_plains
    biome == desert && return desert_lakes
    biome == mountains && return gravelly_mountains
    biome == forest && return flower_forest
    biome == taiga && return taiga_mountains
    biome == swamp && return swamp_hills
    biome == snowy_tundra && return ice_spikes
    biome == jungle && return modified_jungle
    biome == jungle_edge && return modified_jungle_edge
    biome == birch_forest && return if version >= mcv"1.9" && version <= mcv"1.10"
        tall_birch_hills
    else
        tall_birch_forest
    end
    biome == birch_forest_hills &&
        return version >= mcv"1.9" && version <= mcv"1.10" ? BIOME_NONE : tall_birch_hills
    biome == dark_forest && return dark_forest_hills
    biome == snowy_taiga && return snowy_taiga_mountains
    biome == giant_tree_taiga && return giant_spruce_taiga
    biome == giant_tree_taiga_hills && return giant_spruce_taiga_hills
    biome == wooded_mountains && return modified_gravelly_mountains
    biome == savanna && return shattered_savanna
    biome == savanna_plateau && return shattered_savanna_plateau
    biome == badlands && return eroded_badlands
    biome == wooded_badlands_plateau && return modified_wooded_badlands_plateau
    biome == badlands_plateau && return modified_badlands_plateau
    return BIOME_NONE
end

@inline function category(version::Type{<:MCVersion}, biome::Biome)
    (biome == beach || biome == snowy_beach) && return beach
    (biome == desert || biome == desert_hills || biome == desert_lakes) && return desert
    (
        biome == mountains ||
        biome == mountain_edge ||
        biome == wooded_mountains ||
        biome == gravelly_mountains ||
        biome == modified_gravelly_mountains
    ) && return mountains
    (
        biome == forest ||
        biome == wooded_hills ||
        biome == birch_forest ||
        biome == birch_forest_hills ||
        biome == dark_forest ||
        biome == flower_forest ||
        biome == tall_birch_forest ||
        biome == tall_birch_hills ||
        biome == dark_forest_hills
    ) && return forest
    (biome == snowy_tundra || biome == snowy_mountains || biome == ice_spikes) &&
        return snowy_tundra
    (
        biome == jungle ||
        biome == jungle_hills ||
        biome == jungle_edge ||
        biome == modified_jungle ||
        biome == modified_jungle_edge ||
        biome == bamboo_jungle ||
        biome == bamboo_jungle_hills
    ) && return jungle
    (
        biome == badlands ||
        biome == eroded_badlands ||
        biome == modified_wooded_badlands_plateau ||
        biome == modified_badlands_plateau
    ) && return mesa
    (biome == wooded_badlands_plateau || biome == badlands_plateau) &&
        return version <= mcv"1.15" ? mesa : badlands_plateau
    (biome == mushroom_fields || biome == mushroom_field_shore) && return mushroom_fields
    biome == stone_shore && return stone_shore
    (
        biome == ocean ||
        biome == frozen_ocean ||
        biome == deep_ocean ||
        biome == warm_ocean ||
        biome == lukewarm_ocean ||
        biome == cold_ocean ||
        biome == deep_warm_ocean ||
        biome == deep_lukewarm_ocean ||
        biome == deep_cold_ocean ||
        biome == deep_frozen_ocean
    ) && return ocean
    (biome == plains || biome == sunflower_plains) && return plains
    (biome == river || biome == frozen_river) && return river
    (
        biome == savanna ||
        biome == savanna_plateau ||
        biome == shattered_savanna ||
        biome == shattered_savanna_plateau
    ) && return savanna
    (biome == swamp || biome == swamp_hills) && return swamp
    (
        biome == taiga ||
        biome == taiga_hills ||
        biome == snowy_taiga ||
        biome == snowy_taiga_hills ||
        biome == giant_tree_taiga ||
        biome == giant_tree_taiga_hills ||
        biome == taiga_mountains ||
        biome == snowy_taiga_mountains ||
        biome == giant_spruce_taiga ||
        biome == giant_spruce_taiga_hills
    ) && return taiga
    (
        biome == nether_wastes ||
        biome == soul_sand_valley ||
        biome == crimson_forest ||
        biome == warped_forest ||
        biome == basalt_deltas
    ) && return nether_wastes
    return BIOME_NONE
end


@inline function _are_similar(version::Type{<:MCVersion}, biome1::Biome, biome2::Biome)
    biome1 == biome2 && return true
    return category(version, biome1) == category(version, biome2)
end

"""
    are_similar(V::Type{MCVersion}, B1::Type{Biome}, B2::Type{Biome})::Bool

For a given version, check if two biomes have the same category.
`wooded_badlands_plateau` and `badlands_plateau` are considered similar even though
they have a different category in `version <= 1.15`.
"""
@inline function are_similar(version::Type{<:MCVersion}, biome1::Biome, biome2::Biome)
    return _are_similar(version, biome1, biome2)
end

@inline function are_similar(version::mcvt"<=1.15", biome1::Biome, biome2::Biome)
    if biome1 == wooded_badlands_plateau || biome1 == badlands_plateau
        return biome2 == wooded_badlands_plateau || biome2 == badlands_plateau
    end
    return _are_similar(version, biome1, biome2)
end

@inline function is_mesa(biome::Biome)
    return (
        biome == badlands ||
        biome == eroded_badlands ||
        biome == modified_wooded_badlands_plateau ||
        biome == modified_badlands_plateau ||
        biome == wooded_badlands_plateau ||
        biome == badlands_plateau
    )
end

@inline function is_shallow_ocean(biome::Biome)
    return (
        biome == ocean ||
        biome == frozen_ocean ||
        biome == warm_ocean ||
        biome == lukewarm_ocean ||
        biome == cold_ocean
    )
end

@inline function is_deep_ocean(biome::Biome)
    return (
        biome == deep_ocean ||
        biome == deep_warm_ocean ||
        biome == deep_lukewarm_ocean ||
        biome == deep_cold_ocean ||
        biome == deep_frozen_ocean
    )
end

@inline is_oceanic(biome::Biome) = is_shallow_ocean(biome) || is_deep_ocean(biome)
@inline is_water(biome::Biome) = is_oceanic(biome) || biome == river

@inline function is_snowy(biome::Biome)
    return (
        biome == frozen_ocean ||
        biome == frozen_river ||
        biome == snowy_tundra ||
        biome == snowy_mountains ||
        biome == snowy_beach ||
        biome == snowy_taiga ||
        biome == snowy_taiga_hills ||
        biome == ice_spikes ||
        biome == snowy_taiga_mountains
    )
end

end # module