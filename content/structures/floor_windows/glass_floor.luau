-- A glass floor window (tg glass.dm:2-3); all four join one smoothing group
-- (glass.dm:10-11). Construction and the starlight glow are not ported.
return {
    id = "glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.glass_floor.name",
    name = "glass floor",
    sprite = "glass_floor-0",
    dense = false,
    turf = "component:glass_floor",
    examine = {
        flavor = "Don't jump on it, or do, I'm not your mom.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "glass_floor",
    },
}
