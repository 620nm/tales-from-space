-- A glass floor window (tg glass.dm:2-3); all four join one smoothing group
-- (glass.dm:10-11). A crowbar pries it up for its tile (glass.dm:16 `floor_tile`,
-- floor.dm:144-174); the starlight glow and laying a tile are not ported.
-- It leaves plating, not a hole (floor.dm:110-111 `make_plating`), and
-- instantly: `pry_tile` has no do_after (floor.dm:159-161).
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
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "replace_component:station_base",
            yields = { glass_tile = 1 },
            done = "You pry up the glass floor tile.",
        },
    },
}
