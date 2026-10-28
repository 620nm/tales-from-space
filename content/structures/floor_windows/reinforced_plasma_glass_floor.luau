-- A glass floor window (tg glass.dm:103-104); all four join one smoothing group
-- (glass.dm:10-11). A crowbar pries it up for its tile (glass.dm:108 `floor_tile`,
-- floor.dm:144-174); the starlight glow and laying a tile are not ported.
-- It leaves plating, not a hole (floor.dm:110-111 `make_plating`), and
-- instantly: `pry_tile` has no do_after (floor.dm:159-161).
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
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "replace_component:station_base",
            yields = { reinforced_plasma_glass_tile = 1 },
            done = "You pry up the glass floor tile.",
        },
    },
}
