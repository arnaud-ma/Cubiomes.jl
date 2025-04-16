
# Minecraft Versions {#Minecraft-Versions}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCVersions' href='#Cubiomes.MCVersions'><span class="jlbinding">Cubiomes.MCVersions</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



```julia
MCVersions
```


Representation of Minecraft versions in Julia. Works like the built in `VersionNumber` type but for Minecraft versions, with the `mcv""` string macro and the `MCVersion` abstract type.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_versions.jl#L2-L7" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.MCVersions.MCVersion`](#Cubiomes.MCVersions.MCVersion)
- [`Cubiomes.MCVersions.@mcv_str`](#Cubiomes.MCVersions.@mcv_str-Tuple{Any})
- [`Cubiomes.MCVersions.@mcvt_str`](#Cubiomes.MCVersions.@mcvt_str-Tuple{Any})


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCVersions.MCVersion' href='#Cubiomes.MCVersions.MCVersion'><span class="jlbinding">Cubiomes.MCVersions.MCVersion</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
MCVersion
```


The parent type of every Minecraft version.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_versions.jl#L19-L23" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCVersions.@mcv_str-Tuple{Any}' href='#Cubiomes.MCVersions.@mcv_str-Tuple{Any}'><span class="jlbinding">Cubiomes.MCVersions.@mcv_str</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@mcv_str
```


A string macro to get a Minecraft version. For example `mcv"1.8.9"` represents the 1.8.9 version or `mcv"beta1.7"` for the beta 1.7.

!!!warning     It does not _exactly_ represents a Minecraft version, but more a close one, where the     biome generation is the same. For example, `mcv"1.8.6"` is exactly equal to `mcv"1.8.9`     since the generation does not change between those two versions.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_versions.jl#L116-L126" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCVersions.@mcvt_str-Tuple{Any}' href='#Cubiomes.MCVersions.@mcvt_str-Tuple{Any}'><span class="jlbinding">Cubiomes.MCVersions.@mcvt_str</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@mcvt_str
```


A string macro to get the type representation of one or more (with an Union{}) Minecraft versions. Useful for functions who need to dispatch over specifics versions.

The syntax is:     - `mcvt"1.8.9"` -&gt; expands to Type{mcv&quot;1.8.9&quot;}     - `mcvt">=1.8.9"` -&gt; expands to Union{...} on every version &gt;=1.8.9.       The supported operations are `<, <=, >, >=`.     - `mcvt"1.0.0<=x<=1.8.9` -&gt; expands to Union{...} on every version such that 1.0.0&lt;=version&lt;=1.8.9.       The place holder `x` can be anything, can even be empty. The supported operations are **only** `<, <=`.

**Examples**

```julia
julia> end_type(::mcvt"<1.0.0") = nothing
end_type (generic function with 3 methods)

julia> end_type(::mcvt"1.0.0<=_<1.9.0") = :old
end_type (generic function with 3 methods)

julia> end_type(::mcvt">=1.9.0") = :new
end_type (generic function with 3 methods)

julia> end_type(mcv"1.13")
:new
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_versions.jl#L162-L189" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
