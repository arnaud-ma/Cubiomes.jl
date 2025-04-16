
# Utils
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils' href='#Cubiomes.Utils'><span class="jlbinding">Cubiomes.Utils</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



Some utility functions and types that are used in various places in the codebase. It should not be used directly by the user and could be nice if this module does not exist at all.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L1-L4" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.Utils.bytes2uint64`](#Cubiomes.Utils.bytes2uint64-Tuple{Any})
- [`Cubiomes.Utils.findfirst_default`](#Cubiomes.Utils.findfirst_default-Tuple{Function,%20Any,%20Any})
- [`Cubiomes.Utils.length_of_trimmed`](#Cubiomes.Utils.length_of_trimmed-Tuple{Any,%20Any})
- [`Cubiomes.Utils.u64_seed`](#Cubiomes.Utils.u64_seed)
- [`Cubiomes.Utils.@map_inline`](#Cubiomes.Utils.@map_inline-Tuple{Any,%20Any})
- [`Cubiomes.Utils.@only_float32`](#Cubiomes.Utils.@only_float32-Tuple{Any})


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.length_of_trimmed-Tuple{Any, Any}' href='#Cubiomes.Utils.length_of_trimmed-Tuple{Any, Any}'><span class="jlbinding">Cubiomes.Utils.length_of_trimmed</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
length_of_trimmed(predicate, x) where N
```


Returns the length of the collection `x` after removing the elements from the beginning and the end that satisfy the `predicate`.

⚠ The collection _must_ have the property so that `x[i]` for `i` in firstindex(x):lastindex(x) is valid.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L179-L187" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.u64_seed' href='#Cubiomes.Utils.u64_seed'><span class="jlbinding">Cubiomes.Utils.u64_seed</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
u64_seed(x)
```


Converts `x` to `UInt64` for use as a seed, exactly as the Minecraft Java Edition does. It can be any integer or a string.

**Example**

```julia
julia> u64_seed(1234)
0x00000000000004d2

julia> u64_seed("hello world")
0x000000006aefe2c4
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L46-L60" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.@only_float32-Tuple{Any}' href='#Cubiomes.Utils.@only_float32-Tuple{Any}'><span class="jlbinding">Cubiomes.Utils.@only_float32</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@only_float32 expr
```


Transforms all real literals in the expr to Float32.

**Example**

```julia
@only_float32 function f()
    x = 1 + 2im # expand to `1.0f0 + 2.0f0im`
    x += 1 # expand to `x += 1.0f0`
    return x
end
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L266-L279" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.bytes2uint64-Tuple{Any}' href='#Cubiomes.Utils.bytes2uint64-Tuple{Any}'><span class="jlbinding">Cubiomes.Utils.bytes2uint64</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
bytes2uint64(itr)
```


Converts an iterator of bytes to an iterator of UInt64.

**Example**

```julia
>>> bytes2uint64([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]) |> collect
2-element Vector{UInt64}:
0x0102030405060708
0x090a0b0c0d0e0f10
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L16-L28" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.findfirst_default-Tuple{Function, Any, Any}' href='#Cubiomes.Utils.findfirst_default-Tuple{Function, Any, Any}'><span class="jlbinding">Cubiomes.Utils.findfirst_default</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
findfirst_default(predicate::Function, A, default)
```


Return the first index i of A where predicate(A[i]) is true. If no i satisfy this, default is returned instead.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L245-L250" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Utils.@map_inline-Tuple{Any, Any}' href='#Cubiomes.Utils.@map_inline-Tuple{Any, Any}'><span class="jlbinding">Cubiomes.Utils.@map_inline</span></a> <Badge type="info" class="jlObjectType jlMacro" text="Macro" /></summary>



```julia
@map_inline(func, tuple)
```


Inline the loop done by map(func, tuple), i.e. transform it to the tuple of the form `(:func(x1), :func(x2), ...)` at compile-time. Improves performance for small tuples.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/utils.jl#L304-L309" target="_blank" rel="noreferrer">source</a></Badge>

</details>

