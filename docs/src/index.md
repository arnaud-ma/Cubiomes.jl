```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page

layout: home

hero:
  title: Cubiomes.jl Docs
  text: Imitation of Minecraft's world generation in Julia.
  tagline: Julia port of Cubiomes C library
  image:
    src: /assets/world.png
    alt: world map
  actions:
    - theme: brand
      text: Getting Started
      link: /gettingstarted.md
    - theme: alt
      text: Guide 📖
      link: /guide.md
    - theme: alt
      text: API Reference 📚
      link: /api/
features:
  - icon: ⚡
    title: Fast
    details: Fully optimized for speed and efficiency. Multithreaded by default. Faster the the original Cubiomes C library, even in single-threaded mode.
  - icon: 😋
    title: Easy to Use
    details: Simple and intuitive API. No need to worry about memory management or complex data structures. Elegant code thanks to Julia's high-level syntax.
  - title: Modular
    icon: 🧩
    details: Designed to be modular and extensible. Easily add new features or modify existing ones.
---
```

## New to Julia?

Read the [Getting Started](gettingstarted.md) page to learn how to install Julia and Cubiomes.jl and run your first program.

## Examples

Find a mushroom fields biome at a predefined location:

```@example language=julia
using Cubiomes

function search_biome_at(gen, x, z, y)
    seed = 0
    while true
        set_seed!(gen, seed)
        if get_biome(gen, x, z, y) == Biomes.mushroom_fields
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

set_seed!(overworld1_18, 42)
gen_biomes!(overworld1_18, worldmap, 📏"1:16")
save("world.png", to_color(view2d(worldmap)))
```

![world.png](assets/world.png)
