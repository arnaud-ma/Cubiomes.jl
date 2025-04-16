
# SeedUtils
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.SeedUtils' href='#Cubiomes.SeedUtils'><span class="jlbinding">Cubiomes.SeedUtils</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



Minecraft Seed Utilities, like the LCG algorithm used in the seed generation.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_seed_utils.jl#L2-L4" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR`](#Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR)
- [`Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER`](#Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER)
- [`Cubiomes.SeedUtils.mc_step_seed`](#Cubiomes.SeedUtils.mc_step_seed-Tuple{Any,%20Any})


## API

## Private API {#Private-API}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR' href='#Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR'><span class="jlbinding">Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



```julia
MAGIC_LCG_INCREMENTOR::UInt64
```


The incrementor used in the LCG algorithm. This is a constant used in the Minecraft seed generation algorithm.

See Also: [`MAGIC_LCG_MULTIPLIER`](/api/SeedUtils#Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER), [`mc_step_seed`](/api/SeedUtils#Cubiomes.SeedUtils.mc_step_seed-Tuple{Any,%20Any}), [LCG wiki](https://en.wikipedia.org/wiki/Linear_congruential_generator)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_seed_utils.jl#L19-L26" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER' href='#Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER'><span class="jlbinding">Cubiomes.SeedUtils.MAGIC_LCG_MULTIPLIER</span></a> <Badge type="info" class="jlObjectType jlConstant" text="Constant" /></summary>



```julia
MAGIC_LCG_MULTIPLIER::UInt64
```


The multiplier used in the LCG algorithm. This is a constant used in the Minecraft seed generation algorithm.

See Also: [`MAGIC_LCG_INCREMENTOR`](/api/SeedUtils#Cubiomes.SeedUtils.MAGIC_LCG_INCREMENTOR), [`mc_step_seed`](/api/SeedUtils#Cubiomes.SeedUtils.mc_step_seed-Tuple{Any,%20Any}), [LCG wiki](https://en.wikipedia.org/wiki/Linear_congruential_generator)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_seed_utils.jl#L9-L16" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.SeedUtils.mc_step_seed-Tuple{Any, Any}' href='#Cubiomes.SeedUtils.mc_step_seed-Tuple{Any, Any}'><span class="jlbinding">Cubiomes.SeedUtils.mc_step_seed</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
mc_step_seed(seed::UInt64, salt::UInt64)
```


Used to generate the next seed in the Minecraft seed generation algorithm, given the current seed and a salt.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/mc_seed_utils.jl#L29-L34" target="_blank" rel="noreferrer">source</a></Badge>

</details>

