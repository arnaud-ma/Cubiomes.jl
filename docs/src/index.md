# Cubiomes.jl Documentation

**Imitation of Minecraft's world generation in Julia.**

*Julia port of Cubiomes C library*

Cubiomes.jl provides a powerful and efficient implementation of Minecraft's world generation algorithms in the Julia programming language. Built as a port of the popular Cubiomes C library, this package offers superior performance while maintaining an elegant and approachable API.

## Quick Links

```@raw html
<div class="quick-links">
    <a href="gettingstarted/" class="quick-link-box">
        <h3>🚀 Getting Started</h3>
        <p>Install and run your first program</p>
    </a>
    <a href="guide/" class="quick-link-box">
        <h3>📖 User Guide</h3>
        <p>Learn core concepts and usage</p>
    </a>
    <a href="api/" class="quick-link-box">
        <h3>📚 API Reference</h3>
        <p>Detailed function documentation</p>
    </a>
</div>

<style>
.quick-links {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
    margin: 30px 0;
}
.quick-link-box {
    flex: 1;
    min-width: 250px;
    padding: 20px 25px;
    border-radius: 10px;
    background-color: rgba(127, 127, 127, 0.05);
    border: 1px solid rgba(127, 127, 127, 0.2);
    text-decoration: none;
    color: inherit;
    transition: transform 0.2s, box-shadow 0.2s, background-color 0.2s;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.05);
}
.quick-link-box:hover {
    transform: translateY(-3px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.1);
    background-color: rgba(127, 127, 127, 0.1);
}
.quick-link-box h3 {
    margin-top: 0;
    /* Using currentColor which inherits from the parent text color */
    color: currentColor;
    opacity: 0.9;
    font-size: 1.3em;
}
.quick-link-box p {
    margin-bottom: 0;
    opacity: 0.7;
    font-size: 1.05em;
}
</style>
```
## Audience

You should be familiar with programming. That's all. If you are not familiar with Julia, the syntax is quite easy (similar to Python in some ways). You can learn it by working with this package. Look at the [Examples](#examples) or [Getting Started](gettingstarted.md) pages to see how to use it.

There are already a lot of tools for Minecraft seed generation. Maybe Cubiomes.jl is not the best choice.
The goal of this package is to provide more than just a tool to generate Minecraft worlds, with a focus on performance. So it involves writing code, but an easy code thanks to Julia's high-level syntax. An example would be doing some statistics, or very specific seed searches.



## New to Julia?

Read the [Getting Started](gettingstarted.md) page to learn how to install Julia and Cubiomes.jl and run your first program.

## Examples

Find a mushroom fields biome at a predefined location:

```@example language=julia
using Cubiomes

function search_biome_at(gen, x, z, y)
    seed = 0
    while true
        setseed!(gen, seed)
        if getbiome(gen, x, z, y) == Biomes.mushroom_fields
            println("Seed $seed has a Mushroom Fields at $((x, z, y))")
            break
        end
        seed += 1
    end
end

const gen = Overworld(undef, mcv"1.18")
search_biome_at(gen, 0, 0, 63)
```

Generate a map of biomes and save it as an image:

```julia
using Cubiomes
using FileIO

const overworld1_18 = Overworld(undef, mcv"1.18")
const worldmap = WorldMap(x=-1000:1000, z=-1000:1000, y=63)

setseed!(overworld1_18, 42)
genbiomes!(overworld1_18, worldmap, 📏"1:16")
save("world.png", to_color(view2d(worldmap)))
```

![world.png](assets/world.png)
