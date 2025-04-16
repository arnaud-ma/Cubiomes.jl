
# BiomeGeneration
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration' href='#Cubiomes.BiomeGeneration'><span class="jlbinding">Cubiomes.BiomeGeneration</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



```julia
BiomeGeneration
```


Module for generating biomes in Minecraft worlds.

::: warning Warning

Like almost everything in this package, the coordinates order is always`(x, z, y)`, not `(x, y, z)` weither it is for function calls, world indexing, etc. If it is too confusing, hide the order by working directly over the coordinate objects, or use keyword arguments.

:::

The typical workflow is:
1. Create a dimension object (e.g. `Overworld`, `Nether`, `End`) -&gt; [`Dimension`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Dimension)
  
2. Set the seed of the dimension -&gt; [`set_seed!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension,%20Any})
  
3. Get the biome at a specific coordinate -&gt; [`get_biome`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.get_biome)
  

Or:
1. Create a world object -&gt; [`WorldMap`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.WorldMap-Union{NTuple{N,%20UnitRange},%20Tuple{N}}%20where%20N)
  
2. Generate the biomes in the world -&gt; [`gen_biomes!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension,%20AbstractArray{Biome}})
  

The biomes are stored in a `WorldMap` object, which is a 3D array of biomes. To get the coordinates of the biomes, use the `coordinates` function. It gives an iterator of `CartesianIndex` objects, a built-in Julia type. So any intuitive indexing should work out of the box.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/BiomeGeneration.jl#L1-L27" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.BiomeGeneration.Dimension`](#Cubiomes.BiomeGeneration.Dimension)
- [`Cubiomes.BiomeGeneration.End`](#Cubiomes.BiomeGeneration.End)
- [`Cubiomes.BiomeGeneration.Nether`](#Cubiomes.BiomeGeneration.Nether)
- [`Cubiomes.BiomeGeneration.Overworld`](#Cubiomes.BiomeGeneration.Overworld)
- [`Cubiomes.BiomeGeneration.Scale`](#Cubiomes.BiomeGeneration.Scale)
- [`Cubiomes.BiomeGeneration.SomeSha`](#Cubiomes.BiomeGeneration.SomeSha)
- [`Cubiomes.BiomeGeneration.fill_radius!`](#Cubiomes.BiomeGeneration.fill_radius!-Union{Tuple{N},%20Tuple{AbstractArray{Biome,%20N},%20CartesianIndex{2},%20Biome,%20Any}}%20where%20N)
- [`Cubiomes.BiomeGeneration.gen_biomes!`](#Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension,%20AbstractArray{Biome}})
- [`Cubiomes.BiomeGeneration.get_biome`](#Cubiomes.BiomeGeneration.get_biome)
- [`Cubiomes.BiomeGeneration.original_get_biome`](#Cubiomes.BiomeGeneration.original_get_biome-Tuple{Cubiomes.BiomeGeneration.End1_9Plus,%20Any,%20Any,%20Scale{4}})
- [`Cubiomes.BiomeGeneration.set_seed!`](#Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension,%20Any})
- [`Cubiomes.BiomeGeneration.similar_expand`](#Cubiomes.BiomeGeneration.similar_expand-Union{Tuple{T},%20Tuple{Type{T},%20OffsetArrays.OffsetMatrix{T}%20where%20T,%20Int64,%20Int64}}%20where%20T)
- [`Cubiomes.BiomeGeneration.view_reshape_cache_like`](#Cubiomes.BiomeGeneration.view_reshape_cache_like)


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.Dimension' href='#Cubiomes.BiomeGeneration.Dimension'><span class="jlbinding">Cubiomes.BiomeGeneration.Dimension</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Dimension
```


The parent type of every Minecraft dimension. There is generally three steps to use a dimension:
1. Create one dimension with a specific [`MCVersion`](/api/MCVersions#Cubiomes.MCVersions.MCVersion) and maybe some specific arguments.
  
2. Set the seed of the dimension with [`set_seed!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension,%20Any}).
  
3. Do whatever you want with the dimension: get biomes, generate biomes, etc.
  

**Examples**

```julia
julia> overworld = Overworld(undef, mcv"1.18");

julia> set_seed!(overworld, 42)

julia> get_biome(overworld, 0, 0, 63)
dark_forest::Biome = 0x1d

julia> set_seed!(overworld, "I love cats")

julia> world = WorldMap(x=-100:100, z=-100:100, y=63);

julia> gen_biomes!(overworld, world, scale=📏"1:4")
```


See also:
- [`Nether`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Nether), [`Overworld`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Overworld), [`End`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.End)
  
- [`set_seed!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension,%20Any}), [`get_biome`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.get_biome), [`gen_biomes!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension,%20AbstractArray{Biome}})
  
- [`WorldMap`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.WorldMap-Union{NTuple{N,%20UnitRange},%20Tuple{N}}%20where%20N), [`Scale`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Scale)
  

**Extended help**

This section is for developers that want to implement a new dimension.

The concrete type `TheDim` _MUST_ implement:
- An uninitialized constructor `TheDim(::UndefInitializer, ::MCVersion, args...)`
  
- An inplace constructor `set_seed!(dim::TheDim, seed::UInt64, args...)`. Be aware that the seed must be constrained to `UInt64` dispatch to work.
  
- get_biome(dim::TheDim, coord, scale::Scale, args...) -&gt; Biome where `coord` can be either (x::Real, z::Real, y::Real) or NTuple{3}
  
- gen_biomes!(dim::TheDim, out::WorldMap, scale::Scale, args...)
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L83-L124" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.End' href='#Cubiomes.BiomeGeneration.End'><span class="jlbinding">Cubiomes.BiomeGeneration.End</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
End(::UndefInitializer, version::MCVersion)
```


The Minecraft End dimension.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/end.jl#L11-L15" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.Nether' href='#Cubiomes.BiomeGeneration.Nether'><span class="jlbinding">Cubiomes.BiomeGeneration.Nether</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Nether(::UndefInitializer, V::MCVersion)
```


The Nether dimension. See [`Dimension`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Dimension) for general usage.

**Minecraft version &lt;1.16**

Before version 1.16, the Nether is only composed of nether wastes. Nothing else.

**Minecraft version &gt;= 1.16 specificities**
- If the 1:1 scale will never be used, adding `sha=Val(false)` to `set_seed!` will save a very small amount of time (of the order of 100ns up to 1µs). The sha is a precomputed value only used for the 1:1 scale. But the default behavior is to compute the sha at each seed change for simplicity.
  
- In the biome generation functions, a last paramter `confidence` can be passed. It is a performance-related parameter between 0 and 1. A bit the same as the `scale` parameter, but it is a continuous value, and the scale is not modified.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/nether.jl#L16-L35" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.Overworld' href='#Cubiomes.BiomeGeneration.Overworld'><span class="jlbinding">Cubiomes.BiomeGeneration.Overworld</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Overworld(::UndefInitializer, ::mcvt">=1.18")
```


The Overworld dimension. See [`Dimension`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Dimension) for general usage.

::: warning Warning

At the moment, only version 1.18 and above are supported. Older versions will be supported in the future.

:::

**Minecraft version &gt;= 1.18 specificities**
- If the 1:1 scale will never be used, adding `sha=Val(false)` to `set_seed!` will save a very small amount of time (of the order of 100ns up to 1µs). The sha is a precomputed value only used for the 1:1 scale. But the default behavior is to compute the sha at each seed change for simplicity.
  
- Two keyword arguments are added to the biome generation:
  - `skip_depth=Val(false)`: if `Val(true)`, the depth sampling is skipped. Time saved: 1/3 of the biome generation time.
    
  - `skip_shift=Val(false)`: only for the 1:1 and 1:4 scales. If `Val(true)`, the shift sampling is skipped. Time saved: 1/10 of the biome generation time.
    
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/overworld/overworld.jl#L3-L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.Scale' href='#Cubiomes.BiomeGeneration.Scale'><span class="jlbinding">Cubiomes.BiomeGeneration.Scale</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Scale{N}
Scale(N::Integer)
📏"1:N"
```


The scale of a map. It represents the ratio between the size of the map an the real world. For example, a 1:4 scale map means that each block in the map represents a 4x4 area in the real world. So the coordinates (5, 5) are equal to the real world coordinates (20, 20).

`N` **MUST** ne to the form $4^n, n \geq 0$. So the more common scales are 1:1, 1:4, 1:16, 1:64, 1:256. The support for big scales is not guaranteed and depends on the function that uses it. Read the documentation of the function that uses it to know the supported values.

It is possible to use the alternative syntax `📏"1:N"`. The emoji name is `:straight_ruler:`.

**Examples**

```julia
julia> Scale(4)
Scale{4}()

julia> Scale(5)
ERROR: ArgumentError: The scale must be to the form 4^n. Got 1:5. The closest valid scales are 1:4 and 1:16.

julia> 📏"1:4" === Scale(4) === Scale{4}()
true

```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L15-L43" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension, AbstractArray{Biome}}' href='#Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension, AbstractArray{Biome}}'><span class="jlbinding">Cubiomes.BiomeGeneration.gen_biomes!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
gen_biomes!(dim::Dimension, world::WorldMap, [scale::Scale,], args...; kwargs...) -> Nothing
```


Fill the world map with the biomes of the dimension `dim`. The scale is defaulted to 1:1. The args are specific to the dimension. See the documentation of the dimension for more information.

See also: [`WorldMap`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.WorldMap-Union{NTuple{N,%20UnitRange},%20Tuple{N}}%20where%20N), [`Scale`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Scale), [`Dimension`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Dimension), [`get_biome`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.get_biome)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L182-L190" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.get_biome' href='#Cubiomes.BiomeGeneration.get_biome'><span class="jlbinding">Cubiomes.BiomeGeneration.get_biome</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
get_biome(dim::Dimension, x::Real, z::Real, y::Real, [scale::Scale,], args...; kwargs...) -> Biome
get_biome(dim::Dimension, coord, [scale::Scale,], args...; kwargs...) -> Biome
```


Get the biome at the coordinates `(x, z, y)` in the dimension `dim`. The coordinates can be passed as numbers or as tuples or as `CartesianIndex` (the coords returned by [`coordinates`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.coordinates-Tuple{AbstractArray{Biome}})). The scale is defaulted to 1:1 (the more precise).

The scale is defaulted to 1:1, i.e. the exact coordinates. The args are specific to the dimension. See the documentation of the dimension for more information.

See also:     - [`Scale`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Scale), [`gen_biomes!`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.gen_biomes!-Tuple{Dimension,%20AbstractArray{Biome}}), [`Dimension`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Dimension)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L145-L158" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension, Any}' href='#Cubiomes.BiomeGeneration.set_seed!-Tuple{Dimension, Any}'><span class="jlbinding">Cubiomes.BiomeGeneration.set_seed!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
set_seed!(dim::Dimension, seed; kwargs...)
```


Set the seed of the dimension generator. It can be any valid seed you can pass like in Minecraft, but UInt64 is better if performance is a concern. To transform an UInt64 seed to a &quot;normal&quot; one, use `signed(seed)`.

Other keyword arguments can be passed, specific to the dimension / minecraft version. They are often related to some micro-optimizations. See the documentation of the specific dimension for more information.

See also: [`Nether`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Nether), [`Overworld`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.Overworld), [`End`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.End)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L129-L141" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.BiomeArrays.WorldMap-Union{NTuple{N, UnitRange}, Tuple{N}} where N' href='#Cubiomes.BiomeGeneration.BiomeArrays.WorldMap-Union{NTuple{N, UnitRange}, Tuple{N}} where N'><span class="jlbinding">Cubiomes.BiomeGeneration.BiomeArrays.WorldMap</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
WorldMap{N} where N (N = 2, 3)
WorldMap(xrange::UnitRange, zrange::UnitRange, yrange::UnitRange)
WorldMap(xrange::UnitRange, zrange::UnitRange, y::Number)
WorldMap(xrange::UnitRange, zrange::UnitRange)
WorldMap(;x, z, y)
```


A 2D or 3D array of biomes. It is the main data structure used to store the biomes of a Minecraft world. It is a simple wrapper around `AbstractArray{Biome, N}`. So anything that works with arrays should work with `WorldMap`.

See also: [`view2d`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.view2d-Tuple{AbstractArray{Biome,%203}}), [`coordinates`](/api/BiomeGeneration#Cubiomes.BiomeGeneration.BiomeArrays.coordinates-Tuple{AbstractArray{Biome}})


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/BiomeArrays.jl#L12-L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.BiomeArrays.coordinates-Tuple{AbstractArray{Biome}}' href='#Cubiomes.BiomeGeneration.BiomeArrays.coordinates-Tuple{AbstractArray{Biome}}'><span class="jlbinding">Cubiomes.BiomeGeneration.BiomeArrays.coordinates</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
coordinates(M::WorldMap) -> CartesianIndices
```


Wrapper around `CartesianIndices` to get the coordinates of the biomes in the map. Useful to iterate over the coordinates of the map.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/BiomeArrays.jl#L58-L63" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.BiomeArrays.view2d-Tuple{AbstractArray{Biome, 3}}' href='#Cubiomes.BiomeGeneration.BiomeArrays.view2d-Tuple{AbstractArray{Biome, 3}}'><span class="jlbinding">Cubiomes.BiomeGeneration.BiomeArrays.view2d</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
view2d(W::WorldMap{3}) -> WorldMap{2}
```


View a 3D world as a 2D world. Only works if the y size is 1. Otherwise, it throws an error. Useful for functions that only work with 2D worlds, even if the y size is 1, like 2d visualization.

::: warning Warning

The returned object is a view, so modifying it will also modify the original world. Use `copy` to get a new independent world.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/BiomeArrays.jl#L36-L46" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.SomeSha' href='#Cubiomes.BiomeGeneration.SomeSha'><span class="jlbinding">Cubiomes.BiomeGeneration.SomeSha</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
SomeSha
```


A struct that holds a `UInt64` or `nothing`. It is used to store the SHA of the seed if it is needed. Acts like a reference (a zero dimension array) to a `UInt64` or `nothing`. Use `sha[]` to get or store the value, or directly `set_seed!(sha, seed)` to compute the SHA of the seed and store it and `reset!(sha)` to set it to `nothing`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L195-L202" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.fill_radius!-Union{Tuple{N}, Tuple{AbstractArray{Biome, N}, CartesianIndex{2}, Biome, Any}} where N' href='#Cubiomes.BiomeGeneration.fill_radius!-Union{Tuple{N}, Tuple{AbstractArray{Biome, N}, CartesianIndex{2}, Biome, Any}} where N'><span class="jlbinding">Cubiomes.BiomeGeneration.fill_radius!</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
fill_radius!(out::WorldMap{N}, center::CartesianIndex{2}, id::Biome, radius)
```


Fills a circular area around the point `center` in `out` with the biome `id`, within a given `radius`. Assuming `radius`&gt;=0. If `center` is outside the `out` coordinates, nothing is done.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/nether.jl#L168-L174" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.original_get_biome-Tuple{Cubiomes.BiomeGeneration.End1_9Plus, Any, Any, Scale{4}}' href='#Cubiomes.BiomeGeneration.original_get_biome-Tuple{Cubiomes.BiomeGeneration.End1_9Plus, Any, Any, Scale{4}}'><span class="jlbinding">Cubiomes.BiomeGeneration.original_get_biome</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
original_get_biome(end_noise::EndNoise, x, z)
```


Original algorithm to get the biome at a given point in the End dimension. It is only here for documentation purposes, because everything else is just optimizations and scaling on this basis (for scale &gt;= 4).

But not so sure that the optimizations are really important, most of ones are just avoid √ operations, but hypot is already really fast in Julia.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/end.jl#L55-L64" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.similar_expand-Union{Tuple{T}, Tuple{Type{T}, OffsetArrays.OffsetMatrix{T} where T, Int64, Int64}} where T' href='#Cubiomes.BiomeGeneration.similar_expand-Union{Tuple{T}, Tuple{Type{T}, OffsetArrays.OffsetMatrix{T} where T, Int64, Int64}} where T'><span class="jlbinding">Cubiomes.BiomeGeneration.similar_expand</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
similar_expand{T}(mc_map::OffsetMatrix, expand_x::Int, expand_z::Int) where T
```


Create an uninitialized OffsetMatrix of type `T` but with additional rows and columns on each side of the original matrix.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/dimensions/end.jl#L131-L136" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.view_reshape_cache_like' href='#Cubiomes.BiomeGeneration.view_reshape_cache_like'><span class="jlbinding">Cubiomes.BiomeGeneration.view_reshape_cache_like</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
view_reshape_cache_like(axes)
```


Create a view of the cache with the same shape as the axes.

::: warning Warning

This function is not thread-safe and should not be used in a multithreaded context.

:::


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/interface.jl#L221-L229" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.BiomeGeneration.Voronoi.voronoi_access-Union{Tuple{T}, Tuple{UInt64, Tuple{T, T, T}}} where T' href='#Cubiomes.BiomeGeneration.Voronoi.voronoi_access-Union{Tuple{T}, Tuple{UInt64, Tuple{T, T, T}}} where T'><span class="jlbinding">Cubiomes.BiomeGeneration.Voronoi.voronoi_access</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
voronoi_access(sha::UInt64, coord::Union{CartesianIndex{3}, NTuple{3, T}}) where {T}
voronoi_access(sha::UInt64, x, z, y)
```


Compute the closest Voronoi cell based on the given coordinates (at 1:4 scale). Used by Minecraft to translate the 1:4 scale coordinates to the 1:1 scale.

For example we can find in some part of the biome generation source code:

```julia
>>> function get_biome(dimension, x, z, y, ::Scale{1})
        sx, sz, zy = voronoi_access(dimension, x, z, y)
        get_biome(dimension, sx, sz, sy, Scale(4))
    end
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/biome_generation/voronoi.jl#L55-L69" target="_blank" rel="noreferrer">source</a></Badge>

</details>

