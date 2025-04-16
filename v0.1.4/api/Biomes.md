
# Biomes
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes' href='#Cubiomes.Biomes'><span class="jlbinding">Cubiomes.Biomes</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



```julia
Biomes
```


Minecraft biome constants and functions to work with them / compare them.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L1-L5" target="_blank" rel="noreferrer">source</a></Badge>

</details>


The list of all biome names (`Biomes.biome_name`):
- `ocean`
  
- `plains`
  
- `desert`
  
- `mountains`
  
- `forest`
  
- `taiga`
  
- `swamp`
  
- `river`
  
- `nether_wastes`
  
- `the_end`
  
- `frozen_ocean`
  
- `frozen_river`
  
- `snowy_tundra`
  
- `snowy_mountains`
  
- `mushroom_fields`
  
- `mushroom_field_shore`
  
- `beach`
  
- `desert_hills`
  
- `wooded_hills`
  
- `taiga_hills`
  
- `mountain_edge`
  
- `jungle`
  
- `jungle_hills`
  
- `jungle_edge`
  
- `deep_ocean`
  
- `stone_shore`
  
- `snowy_beach`
  
- `birch_forest`
  
- `birch_forest_hills`
  
- `dark_forest`
  
- `snowy_taiga`
  
- `snowy_taiga_hills`
  
- `giant_tree_taiga`
  
- `giant_tree_taiga_hills`
  
- `wooded_mountains`
  
- `savanna`
  
- `savanna_plateau`
  
- `badlands`
  
- `wooded_badlands_plateau`
  
- `badlands_plateau`
  
- `small_end_islands`
  
- `end_midlands`
  
- `end_highlands`
  
- `end_barrens`
  
- `warm_ocean`
  
- `lukewarm_ocean`
  
- `cold_ocean`
  
- `deep_warm_ocean`
  
- `deep_lukewarm_ocean`
  
- `deep_cold_ocean`
  
- `deep_frozen_ocean`
  
- `seasonal_forest`
  
- `rainforest`
  
- `shrubland`
  
- `the_void`
  
- `sunflower_plains`
  
- `desert_lakes`
  
- `gravelly_mountains`
  
- `flower_forest`
  
- `taiga_mountains`
  
- `swamp_hills`
  
- `ice_spikes`
  
- `modified_jungle`
  
- `modified_jungle_edge`
  
- `tall_birch_forest`
  
- `tall_birch_hills`
  
- `dark_forest_hills`
  
- `snowy_taiga_mountains`
  
- `giant_spruce_taiga`
  
- `giant_spruce_taiga_hills`
  
- `modified_gravelly_mountains`
  
- `shattered_savanna`
  
- `shattered_savanna_plateau`
  
- `eroded_badlands`
  
- `modified_wooded_badlands_plateau`
  
- `modified_badlands_plateau`
  
- `bamboo_jungle`
  
- `bamboo_jungle_hills`
  
- `soul_sand_valley`
  
- `crimson_forest`
  
- `warped_forest`
  
- `basalt_deltas`
  
- `dripstone_caves`
  
- `lush_caves`
  
- `meadow`
  
- `grove`
  
- `snowy_slopes`
  
- `jagged_peaks`
  
- `frozen_peaks`
  
- `stony_peaks`
  
- `old_growth_birch_forest`
  
- `old_growth_pine_taiga`
  
- `old_growth_spruce_taiga`
  
- `snowy_plains`
  
- `sparse_jungle`
  
- `stony_shore`
  
- `windswept_hills`
  
- `windswept_forest`
  
- `windswept_gravelly_hills`
  
- `windswept_savanna`
  
- `wooded_badlands`
  
- `deep_dark`
  
- `mangrove_swamp`
  
- `cherry_grove`
  

And a special `BIOME_NONE`.

## Index
- [`Cubiomes.Biomes.are_similar`](#Cubiomes.Biomes.are_similar-Tuple{MCVersion,%20Biome,%20Biome})
- [`Cubiomes.Biomes.biome_exists`](#Cubiomes.Biomes.biome_exists-Tuple{Biome,%20Union{Cubiomes.MCVersions.v1_20,%20Cubiomes.MCVersions.v1_21}})
- [`Cubiomes.Biomes.category`](#Cubiomes.Biomes.category-Tuple{Biome,%20MCVersion})
- [`Cubiomes.Biomes.is_overworld`](#Cubiomes.Biomes.is_overworld-Tuple{Biome,%20MCVersion})
- [`Cubiomes.Biomes.mutated`](#Cubiomes.Biomes.mutated-Tuple{Biome,%20MCVersion})


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes.are_similar-Tuple{MCVersion, Biome, Biome}' href='#Cubiomes.Biomes.are_similar-Tuple{MCVersion, Biome, Biome}'><span class="jlbinding">Cubiomes.Biomes.are_similar</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
are_similar(version::MCVersion, biome1::Biome, biome2::Biome)
```


For a given version, check if two biomes have the same category. `wooded_badlands_plateau` and `badlands_plateau` are considered similar even though they have a different category in `version <= 1.15`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L481-L487" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes.biome_exists-Tuple{Biome, Union{Cubiomes.MCVersions.v1_20, Cubiomes.MCVersions.v1_21}}' href='#Cubiomes.Biomes.biome_exists-Tuple{Biome, Union{Cubiomes.MCVersions.v1_20, Cubiomes.MCVersions.v1_21}}'><span class="jlbinding">Cubiomes.Biomes.biome_exists</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
biome_exists(biome::Biome, version::MCVersion)
```


Return `true` if the given biome exists in the given version and `false` otherwise.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L143-L147" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes.category-Tuple{Biome, MCVersion}' href='#Cubiomes.Biomes.category-Tuple{Biome, MCVersion}'><span class="jlbinding">Cubiomes.Biomes.category</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
category(biome::Biome, version::MCVersion)
```


Return the category of the given biome in the given version. The categories are:
- `beach`
  
- `desert`
  
- `mountains`
  
- `forest`
  
- `snowy_tundra`
  
- `jungle`
  
- `mesa`
  
- `mushroom_fields`
  
- `stone_shore`
  
- `ocean`
  
- `plains`
  
- `river`
  
- `savanna`
  
- `swamp`
  
- `taiga`
  
- `nether_wastes`
  

If the biome does not belong to any of these categories, return `BIOME_NONE`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L368-L390" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes.is_overworld-Tuple{Biome, MCVersion}' href='#Cubiomes.Biomes.is_overworld-Tuple{Biome, MCVersion}'><span class="jlbinding">Cubiomes.Biomes.is_overworld</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
is_overworld(biome::Biome, version::MCVersion)
```


Return `true` if the given biome is an overworld biome and `false` otherwise. If the biome does not exist in the given version, return `false`.

**Examples**

```julia
julia> is_overworld(Biomes.ocean, mcv"1.16",)
true

julia> [biome for biome in instances(Biome) if is_overworld(biome, mcv"1.16")]
90-element Vector{Biome}:
 ocean::Biome = 0x00
 plains::Biome = 0x01
 desert::Biome = 0x02
 ...

```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L295-L314" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Biomes.mutated-Tuple{Biome, MCVersion}' href='#Cubiomes.Biomes.mutated-Tuple{Biome, MCVersion}'><span class="jlbinding">Cubiomes.Biomes.mutated</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
mutated(biome::Biome, version::MCVersion)
```


Return the mutated variant of the given biome in the given version. If the biome does not have a mutated variant, return `BIOME_NONE`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/Biomes.jl#L331-L336" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
