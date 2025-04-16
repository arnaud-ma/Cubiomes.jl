
# Display
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Display' href='#Cubiomes.Display'><span class="jlbinding">Cubiomes.Display</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



```julia
Display
```


Module for visualization of results


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/display.jl#L1-L5" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.Display.to_color`](#Cubiomes.Display.to_color-Tuple{Biome})


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Display.to_color-Tuple{Biome}' href='#Cubiomes.Display.to_color-Tuple{Biome}'><span class="jlbinding">Cubiomes.Display.to_color</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
to_color(b::Biome)
to_color(w::WorldMap)
```


Return a color / an array of colors corresponding to a biome. It should only be used for visualization, since two biomes can have the same color.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/display.jl#L117-L123" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
