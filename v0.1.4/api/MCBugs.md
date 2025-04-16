
# MCBugs
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCBugs' href='#Cubiomes.MCBugs'><span class="jlbinding">Cubiomes.MCBugs</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



Utility functions for working with known Minecraft bugs.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_bugs.jl#L1-L3" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.MCBugs.has_bug_mc159283`](#Cubiomes.MCBugs.has_bug_mc159283-Tuple{Any,%20Int64,%20Int64})
- [`Cubiomes.MCBugs.overflow_int32`](#Cubiomes.MCBugs.overflow_int32-Tuple{Int64})


## API

## Private API {#Private-API}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCBugs.has_bug_mc159283-Tuple{Any, Int64, Int64}' href='#Cubiomes.MCBugs.has_bug_mc159283-Tuple{Any, Int64, Int64}'><span class="jlbinding">Cubiomes.MCBugs.has_bug_mc159283</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
has_bug_mc159283(version::MCVersion, x::Int64, z::Int64)
```


See [MC-159283](https://bugs.mojang.com/browse/MC-159283) for more information.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_bugs.jl#L15-L19" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.MCBugs.overflow_int32-Tuple{Int64}' href='#Cubiomes.MCBugs.overflow_int32-Tuple{Int64}'><span class="jlbinding">Cubiomes.MCBugs.overflow_int32</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
overflow_int32(x::Int64)
```


Returns true if the value `x` overflows when converted to a signed 32-bit integer.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_bugs.jl#L8-L12" target="_blank" rel="noreferrer">source</a></Badge>

</details>

