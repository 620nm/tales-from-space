-- A glass floor window (tg glass.dm:69-70); all four join one smoothing group
-- (glass.dm:10-11). Construction and the starlight glow are not ported.
return {
    id = "reinforced_glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.reinforced_glass_floor.name",
    name = "reinforced glass floor",
    sprite = "reinforced_glass_floor-0",
    dense = false,
    turf = "component:reinforced_glass_floor",
    examine = {
        flavor = "Do jump on it, it can take it.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "reinforced_glass_floor",
    },
}
