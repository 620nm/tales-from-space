-- A glass floor window (tg glass.dm:87-88); all four join one smoothing group
-- (glass.dm:10-11). Construction and the starlight glow are not ported.
return {
    id = "plasma_glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.plasma_glass_floor.name",
    name = "plasma glass floor",
    sprite = "plasma_glass_floor-0",
    dense = false,
    turf = "component:plasma_glass_floor",
    examine = {
        flavor = "Studies by the Nanotrasen Materials Safety Division have not yet determined if this is safe to jump on, do so at your own risk.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "plasma_glass_floor",
    },
}
