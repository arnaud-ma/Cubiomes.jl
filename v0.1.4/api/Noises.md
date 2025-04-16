
# Noises
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises' href='#Cubiomes.Noises'><span class="jlbinding">Cubiomes.Noises</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



::: tip Note

Working over raw noise functions is very low-level and should only be used as a last resort or for performance reasons.

:::

Noises is a module to generate and sample various types of noise functions used in the procedural generation of Minecraft worlds. The result are always floating, but the input can be any type of number.

A noise object can be quite big in memory, so we can create an undefined noise object and initialize it without copying it with the `set_rng!🎲` function, saving time and memory.

The main uses are with the functions:
- [`Noise`](/api/Noises#Cubiomes.Noises.Noise) : create an undefined noise object.
  
- [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲) : initialize the noise object.
  
- [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N}) : create and initialize the noise object in one step.
  
- [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise) : sample the noise at a given point.
  

The noises implemented are:
- [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin) : a Perlin noise.
  
- [`Octaves`](/api/Noises#Cubiomes.Noises.Octaves) : a sum of `N` Perlin noises.
  
- [`DoublePerlin`](/api/Noises#Cubiomes.Noises.DoublePerlin) : a sum of two independent and identically distributed Octaves noises.
  


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/Noises.jl#L2-L24" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.Noises.DoublePerlin`](#Cubiomes.Noises.DoublePerlin)
- [`Cubiomes.Noises.Noise`](#Cubiomes.Noises.Noise)
- [`Cubiomes.Noises.Noise`](#Cubiomes.Noises.Noise-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20UndefInitializer,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})
- [`Cubiomes.Noises.Octaves`](#Cubiomes.Noises.Octaves)
- [`Cubiomes.Noises.Perlin`](#Cubiomes.Noises.Perlin)
- [`Cubiomes.Noises.Noise🎲`](#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})
- [`Cubiomes.Noises.indexed_lerp`](#Cubiomes.Noises.indexed_lerp-Tuple{Integer,%20Any,%20Any,%20Any})
- [`Cubiomes.Noises.init_coord_values`](#Cubiomes.Noises.init_coord_values-Tuple{Any})
- [`Cubiomes.Noises.interpolate_perlin`](#Cubiomes.Noises.interpolate_perlin-Tuple{OffsetArrays.OffsetVector{UInt8,%20StaticArraysCore.MVector{257,%20UInt8}},%20Vararg{Any,%209}})
- [`Cubiomes.Noises.is_undef`](#Cubiomes.Noises.is_undef)
- [`Cubiomes.Noises.next_perlin🎲`](#Cubiomes.Noises.next_perlin🎲)
- [`Cubiomes.Noises.sample_noise`](#Cubiomes.Noises.sample_noise)
- [`Cubiomes.Noises.sample_simplex`](#Cubiomes.Noises.sample_simplex)
- [`Cubiomes.Noises.set_rng!🎲`](#Cubiomes.Noises.set_rng!🎲)
- [`Cubiomes.Noises.shuffle!🎲`](#Cubiomes.Noises.shuffle!🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG,%20OffsetArrays.OffsetVector{UInt8,%20StaticArraysCore.MVector{257,%20UInt8}}})
- [`Cubiomes.Noises.simplex_gradient`](#Cubiomes.Noises.simplex_gradient-NTuple{5,%20Any})
- [`Cubiomes.Noises.smoothstep_perlin_unsafe`](#Cubiomes.Noises.smoothstep_perlin_unsafe-Tuple{Any})
- [`Cubiomes.Noises.unsafe_set_rng!🎲`](#Cubiomes.Noises.unsafe_set_rng!🎲)


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.DoublePerlin' href='#Cubiomes.Noises.DoublePerlin'><span class="jlbinding">Cubiomes.Noises.DoublePerlin</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
DoublePerlin{N} <: Noise
```


A double Perlin noise implementation. It&#39;s a sum of two independent and identically distributed (iid) Octaves{N} noise.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/double_perlin.jl#L9-L14" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.Noise' href='#Cubiomes.Noises.Noise'><span class="jlbinding">Cubiomes.Noises.Noise</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Noise
```


The abstract type for a Noise sampler.

**Methods**
- [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise)
  
- [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲)
  
- `Noise(::Type{Noise}, ::UndefInitializer, ...)`
  
- [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})
  
- [`is_undef`](/api/Noises#Cubiomes.Noises.is_undef)
  

See also:  [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin), [`Octaves`](/api/Noises#Cubiomes.Noises.Octaves), [`DoublePerlin`](/api/Noises#Cubiomes.Noises.DoublePerlin)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L3-L16" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.Noise-Union{Tuple{N}, Tuple{T}, Tuple{Type{T}, UndefInitializer, Vararg{Any, N}}} where {T<:Cubiomes.Noises.Noise, N}' href='#Cubiomes.Noises.Noise-Union{Tuple{N}, Tuple{T}, Tuple{Type{T}, UndefInitializer, Vararg{Any, N}}} where {T<:Cubiomes.Noises.Noise, N}'><span class="jlbinding">Cubiomes.Noises.Noise</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
Noise(::Type{T}, ::UndefInitializer) where {T<:Noise}
Noise(::Type{DoublePerlin}; ::UndefInitializer, amplitudes)
```


Create a noise of type `T` with an undefined state, i.e., it is not initialized yet. Use [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲) or [`unsafe_set_rng!🎲`](/api/Noises#Cubiomes.Noises.unsafe_set_rng!🎲) to initialize it.

See also: [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N}), [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲), [`unsafe_set_rng!🎲`](/api/Noises#Cubiomes.Noises.unsafe_set_rng!🎲)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L79-L87" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.Octaves' href='#Cubiomes.Noises.Octaves'><span class="jlbinding">Cubiomes.Noises.Octaves</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Octaves{N} <: Noise
```


An ordered collection of `N` Perlin objects representing the octaves of a noise.

See also: [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`sample_noise`], [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin), [`DoublePerlin`](/api/Noises#Cubiomes.Noises.DoublePerlin)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/octaves.jl#L7-L13" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.Perlin' href='#Cubiomes.Noises.Perlin'><span class="jlbinding">Cubiomes.Noises.Perlin</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
Perlin <: Noise
```


The type for the perlin noise. See https://en.wikipedia.org/Perlin_Noise to know how it works.

See also: [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise), [`sample_simplex`](/api/Noises#Cubiomes.Noises.sample_simplex)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L73-L79" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.Noise🎲-Union{Tuple{N}, Tuple{T}, Tuple{Type{T}, Cubiomes.JavaRNG.AbstractJavaRNG, Vararg{Any, N}}} where {T<:Cubiomes.Noises.Noise, N}' href='#Cubiomes.Noises.Noise🎲-Union{Tuple{N}, Tuple{T}, Tuple{Type{T}, Cubiomes.JavaRNG.AbstractJavaRNG, Vararg{Any, N}}} where {T<:Cubiomes.Noises.Noise, N}'><span class="jlbinding">Cubiomes.Noises.Noise🎲</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
Noise🎲(::Type{T}, rng::AbstractJavaRNG, args...) where {N, T<:Noise}
```


Create a noise of type `T` and initialize it with the given random number generator `rng`. Other arguments are used to initialize the noise. They depend on the noise type and they are the same as the arguments of the [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲) function.

Strictly equivalent to

```julia
julia> noise = Noise(T, undef) # or Noise(T, undef, args[1]) for DoublePerlin
T(...)

julia> set_rng!🎲(noise, rng, args...)`.
```


See also: [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L91-L106" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.is_undef' href='#Cubiomes.Noises.is_undef'><span class="jlbinding">Cubiomes.Noises.is_undef</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
is_undef(noise::Noise)
```


Check if the noise is undefined, i.e., it has not been initialized yet.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L113-L117" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.sample_noise' href='#Cubiomes.Noises.sample_noise'><span class="jlbinding">Cubiomes.Noises.sample_noise</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
sample_noise(noise::Perlin, x, z, y=missing, yamp=0, ymin=0)
sample_noise(noise::Octaves, x, z, y=missing, yamp=missing, ymin=missing)
sample_noise(noise::DoublePerlin, x, z, y=missing, [move_factor,])
```


Sample the given noise at the specified coordinates.

See also: [`sample_simplex`](/api/Noises#Cubiomes.Noises.sample_simplex), [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L27-L35" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.sample_simplex' href='#Cubiomes.Noises.sample_simplex'><span class="jlbinding">Cubiomes.Noises.sample_simplex</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
sample_simplex(noise::Perlin, x, y)
```


Sample the given noise at the given coordinate using the simplex noise algorithm instead of the perlin one. See https://en.wikipedia.org/wiki/Simplex_noise

See also: [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise), [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L342-L349" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.set_rng!🎲' href='#Cubiomes.Noises.set_rng!🎲'><span class="jlbinding">Cubiomes.Noises.set_rng!🎲</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
set_rng!🎲(noise::Perlin, rng)
set_rng!🎲(noise::Octaves{N}, rng::JavaRandom, octave_min) where N
set_rng!🎲(noise::Octaves{N}, rng::JavaXoroshiro128PlusPlus, amplitudes, octave_min) where N
set_rng!🎲(noise::DoublePerlin{N}, rng, octave_min) where N
set_rng!🎲(noise::DoublePerlin{N}, rng, amplitudes, octave_min) where N
```


` Initialize the noise in place with the given random number generator (of type AbstractJavaRNG).

::: warning Warning

`N` represents the number of octaves, each associated with a non-zero amplitude. Therefore, `N` **MUST** be equal to the number of non-zero values in amplitudes. This number can be obtained with `Cubiomes.length_filter(!iszero, amplitudes)`. For performance reasons, it is possible to lower `N` and completely ignore the last amplitudes using [`unsafe_set_rng!🎲`](/api/Noises#Cubiomes.Noises.unsafe_set_rng!🎲).

:::

::: tip Tip

Since the last amplitudes are ignored if they are set to zero, replace the tuple of amplitudes with the trimmed version without the last zeros can save a very small amount of memory / time. However, only do this if the trimmed amplitudes are already known. Computing them only for this function call will not save any time.

:::

See also: [`unsafe_set_rng!🎲`](/api/Noises#Cubiomes.Noises.unsafe_set_rng!🎲), [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L42-L65" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.unsafe_set_rng!🎲' href='#Cubiomes.Noises.unsafe_set_rng!🎲'><span class="jlbinding">Cubiomes.Noises.unsafe_set_rng!🎲</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
unsafe_set_rng!🎲(noise, rng::JavaXoroshiro128PlusPlus, amplitudes, octave_min)
```


Same as [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲) but allows to skip some octaves for performance reasons, i.e. `N` can be less than the number of non-zero values in `amplitudes`, and the last octaves are completely ignored. If instead `N` is greater, the behavior is undefined.

See also: [`set_rng!🎲`](/api/Noises#Cubiomes.Noises.set_rng!🎲), [`Noise`](/api/Noises#Cubiomes.Noises.Noise), [`Noise🎲`](/api/Noises#Cubiomes.Noises.Noise🎲-Union{Tuple{N},%20Tuple{T},%20Tuple{Type{T},%20Cubiomes.JavaRNG.AbstractJavaRNG,%20Vararg{Any,%20N}}}%20where%20{T<:Cubiomes.Noises.Noise,%20N})


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/interface.jl#L68-L76" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.indexed_lerp-Tuple{Integer, Any, Any, Any}' href='#Cubiomes.Noises.indexed_lerp-Tuple{Integer, Any, Any, Any}'><span class="jlbinding">Cubiomes.Noises.indexed_lerp</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
indexed_lerp(idx::Integer, x, y, z)
```


Use the lower 4 bits of `idx` as a simple hash to combine the `x`, `y`, and `z` values into a single number (a new index), to be used in the Perlin noise interpolation.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L175-L180" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.init_coord_values-Tuple{Any}' href='#Cubiomes.Noises.init_coord_values-Tuple{Any}'><span class="jlbinding">Cubiomes.Noises.init_coord_values</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
init_coord_values(coord)
```


Initialize one coordinate for the Perlin noise sampling.

**Returns:**
- the fractional part of `coord`
  
- the integer part of `coord`, modulo UInt8
  
- the smoothstep value of the fractional part of `coord`
  

See also: [`smoothstep_perlin_unsafe`](/api/Noises#Cubiomes.Noises.smoothstep_perlin_unsafe-Tuple{Any}), [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise), [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L155-L166" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.interpolate_perlin-Tuple{OffsetArrays.OffsetVector{UInt8, StaticArraysCore.MVector{257, UInt8}}, Vararg{Any, 9}}' href='#Cubiomes.Noises.interpolate_perlin-Tuple{OffsetArrays.OffsetVector{UInt8, StaticArraysCore.MVector{257, UInt8}}, Vararg{Any, 9}}'><span class="jlbinding">Cubiomes.Noises.interpolate_perlin</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
interpolate_perlin(
            idx::PermsType,
            d1, d2, d3,
            h1, h2, h3,
            t1, t2, t3
        ) -> Real
```


Interpolate the Perlin noise at the given coordinates.

**Arguments**
- The `idx` parameter is the permutations array.
  
- The `d1`, `d2`, and `d3` parameters are the fractional parts of the `x`, `y`, and `z`
  

coordinates.
- The `h1`, `h2`, and `h3` parameters are the integer parts of the `x`, `y`, and `z`
  

coordinates. They **MUST** be between 0 and 255.
- The `t1`, `t2`, and `t3` parameters are the smoothstep values of the fractional parts
  

of the `x`, `y`, and `z` coordinates.

See also: [`init_coord_values`](/api/Noises#Cubiomes.Noises.init_coord_values-Tuple{Any}), [`sample_noise`](/api/Noises#Cubiomes.Noises.sample_noise), [`Perlin`](/api/Noises#Cubiomes.Noises.Perlin)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L203-L223" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.next_perlin🎲' href='#Cubiomes.Noises.next_perlin🎲'><span class="jlbinding">Cubiomes.Noises.next_perlin🎲</span></a> <Badge type="info" class="jlObjectType jlFunction" text="Function" /></summary>



```julia
next_perlin🎲(rng::JavaRandom, ::Type{Int32}; start=0, stop) -> Int32
next_perlin🎲(rng::JavaXoroshiro128PlusPlus, ::Type{Int32}; start=0, stop) -> Int3
```


Same as [`next🎲`](/api/JavaRNG#Cubiomes.JavaRNG.next🎲-Union{Tuple{T},%20Tuple{T,%20Any}}%20where%20T<:Cubiomes.JavaRNG.AbstractJavaRNG) but with a different implementation specific for the perlin noise. Don&#39;t ask why this is different, it&#39;s just how Minecraft does it.

See also: [`next🎲`](/api/JavaRNG#Cubiomes.JavaRNG.next🎲-Union{Tuple{T},%20Tuple{T,%20Any}}%20where%20T<:Cubiomes.JavaRNG.AbstractJavaRNG)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L13-L21" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.shuffle!🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG, OffsetArrays.OffsetVector{UInt8, StaticArraysCore.MVector{257, UInt8}}}' href='#Cubiomes.Noises.shuffle!🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG, OffsetArrays.OffsetVector{UInt8, StaticArraysCore.MVector{257, UInt8}}}'><span class="jlbinding">Cubiomes.Noises.shuffle!🎲</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
shuffle!🎲(rng::AbstractRNG_MC, perms::PermsType)
```


Shuffle the permutations array using the given random number generator.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L131-L135" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.simplex_gradient-NTuple{5, Any}' href='#Cubiomes.Noises.simplex_gradient-NTuple{5, Any}'><span class="jlbinding">Cubiomes.Noises.simplex_gradient</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
simplex_gradient(idx, x, y, z, d)
```


Compute the gradient of the simplex noise at the given coordinates.

**Arguments**
- `idx`: Index used for interpolation.
  
- `x`, `y`, `z`: Coordinates in the simplex grid.
  
- `d`: Constant used to determine the influence of the point in the grid.
  

See also: [`sample_simplex`](/api/Noises#Cubiomes.Noises.sample_simplex)


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L317-L328" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.Noises.smoothstep_perlin_unsafe-Tuple{Any}' href='#Cubiomes.Noises.smoothstep_perlin_unsafe-Tuple{Any}'><span class="jlbinding">Cubiomes.Noises.smoothstep_perlin_unsafe</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
smoothstep_perlin_unsafe(x)
```


Compute $6x^5 - 15x^4 + 10x^3$, the smoothstep function used in Perlin noise. See https://en.wikipedia.org/wiki/Smoothstep#Variations for more details.

This function is unsafe because it is assuming that $0 \leq x \leq 1$ (it does not clamp the input).


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/noises/perlin.jl#L145-L152" target="_blank" rel="noreferrer">source</a></Badge>

</details>

