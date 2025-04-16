
# JavaRNG
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG' href='#Cubiomes.JavaRNG'><span class="jlbinding">Cubiomes.JavaRNG</span></a> <Badge type="info" class="jlObjectType jlModule" text="Module" /></summary>



A module that mimics the behavior of Java&#39;s random number generators in Julia. Only the functionalities needed by the Minecraft Java Edition are implemented.

The rngs implemented are:
- [`JavaRandom`](/api/JavaRNG#Cubiomes.JavaRNG.JavaRandom) for the [`java.util.Random`](https://docs.oracle.com/javase/7/docs/api/java/util/Random.html) class.
  
- [`JavaXoroshiro128PlusPlus`](/api/JavaRNG#Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus) for the [`Xoroshiro128PlusPlus`](http://prng.di.unimi.it/xoshiro128plusplus.c) PRNG.
  

Only the [`next🎲`] function is used to get random numbers. Instead of `nextDouble` or `nextInt` in Java, use `next🎲(rng, Float64)` or `next🎲(rng, Int32)` respectively.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L2-L12" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Index
- [`Cubiomes.JavaRNG.JavaRandom`](#Cubiomes.JavaRNG.JavaRandom)
- [`Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus`](#Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus)
- [`Cubiomes.JavaRNG.next🎲`](#Cubiomes.JavaRNG.next🎲-Union{Tuple{T},%20Tuple{T,%20Any}}%20where%20T<:Cubiomes.JavaRNG.AbstractJavaRNG)
- [`Cubiomes.JavaRNG.randjump🎲`](#Cubiomes.JavaRNG.randjump🎲-Union{Tuple{T},%20Tuple{T,%20Any,%20Integer}}%20where%20T<:Cubiomes.JavaRNG.AbstractJavaRNG)
- [`Cubiomes.JavaRNG.set_seed🎲`](#Cubiomes.JavaRNG.set_seed🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG,%20Any,%20Vararg{Any}})


## API
<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG.JavaRandom' href='#Cubiomes.JavaRNG.JavaRandom'><span class="jlbinding">Cubiomes.JavaRNG.JavaRandom</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
JavaRandom(seed::Integer)
```


A pseudorandom number generator that mimics the behavior of Java&#39;s [`java.util.Random`](https://docs.oracle.com/javase/7/docs/api/java/util/Random.html) class.

**Examples**

```julia
julia> rng = JavaRandom(1234);
JavaRandom(0x00000005deece2bf)

julia> next_int32_range!(rng, 10)
3
```



<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L70-L85" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus' href='#Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus'><span class="jlbinding">Cubiomes.JavaRNG.JavaXoroshiro128PlusPlus</span></a> <Badge type="info" class="jlObjectType jlType" text="Type" /></summary>



```julia
JavaXoroshiro128PlusPlus(lo::UInt64, hi::UInt64)
JavaXoroshiro128PlusPlus(seed::Integer)
```


A pseudo-random number generator that mimics the behavior of Java&#39;s implementation of [`Xoroshiro128PlusPlus`](http://prng.di.unimi.it/xoshiro128plusplus.c) PRNG.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L176-L182" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG.next🎲-Union{Tuple{T}, Tuple{T, Any}} where T<:Cubiomes.JavaRNG.AbstractJavaRNG' href='#Cubiomes.JavaRNG.next🎲-Union{Tuple{T}, Tuple{T, Any}} where T<:Cubiomes.JavaRNG.AbstractJavaRNG'><span class="jlbinding">Cubiomes.JavaRNG.next🎲</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
next🎲(rng::AbstractJavaRNG, ::Type{T}) where T
next🎲(rng::AbstractJavaRNG, ::Type{T}, stop) where T
next🎲(rng::AbstractJavaRNG, ::Type{T}, start, stop) where T
```


Generate a random number of type `T` from the given random number generator. If `start` and `stop` are provided, the random number will be in the range `[start, stop]`. `start` is default to `0`.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L23-L30" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG.randjump🎲-Union{Tuple{T}, Tuple{T, Any, Integer}} where T<:Cubiomes.JavaRNG.AbstractJavaRNG' href='#Cubiomes.JavaRNG.randjump🎲-Union{Tuple{T}, Tuple{T, Any, Integer}} where T<:Cubiomes.JavaRNG.AbstractJavaRNG'><span class="jlbinding">Cubiomes.JavaRNG.randjump🎲</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
randjump🎲(rng::AbstractJavaRNG, ::Type{T}, n::Integer) where T
```


Jump the state of the random number generator `n` steps forward, without generating any random numbers.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L33-L38" target="_blank" rel="noreferrer">source</a></Badge>

</details>

<details class='jldocstring custom-block' open>
<summary><a id='Cubiomes.JavaRNG.set_seed🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG, Any, Vararg{Any}}' href='#Cubiomes.JavaRNG.set_seed🎲-Tuple{Cubiomes.JavaRNG.AbstractJavaRNG, Any, Vararg{Any}}'><span class="jlbinding">Cubiomes.JavaRNG.set_seed🎲</span></a> <Badge type="info" class="jlObjectType jlMethod" text="Method" /></summary>



```julia
set_seed🎲(rng::AbstractJavaRNG, seed) -> AbstractJavaRNG
```


Initialize the rng with the given seed. Return the rng itself for convenience.


<Badge type="info" class="source-link" text="source"><a href="https://github.com/arnaud-ma/Cubiomes.jl/blob/4931c2c0e998671decf0afcb343b5f80b19e6a57/src/rng.jl#L43-L47" target="_blank" rel="noreferrer">source</a></Badge>

</details>


## Private API {#Private-API}
