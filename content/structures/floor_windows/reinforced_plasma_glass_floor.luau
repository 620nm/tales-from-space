-- A glass floor window (tg glass.dm:103-104); all four join one smoothing group
-- (glass.dm:10-11). Construction and the starlight glow are not ported.
return {
    id = "reinforced_plasma_glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.reinforced_plasma_glass_floor.name",
    name = "reinforced plasma glass floor",
    sprite = "reinforced_plasma_glass_floor-0",
    dense = false,
    turf = "component:reinforced_plasma_glass_floor",
    examine = {
        flavor = "Do jump on it, jump on it while in a mecha, it can take it.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "reinforced_plasma_glass_floor",
    },
}
