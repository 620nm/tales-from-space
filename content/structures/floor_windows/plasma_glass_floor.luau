-- A glass floor window (tg glass.dm:87-88); all four join one smoothing group
-- (glass.dm:10-11). A crowbar pries it up for its tile (glass.dm:92 `floor_tile`,
-- floor.dm:144-174); the starlight glow and laying a tile are not ported.
-- It leaves plating, not a hole (floor.dm:110-111 `make_plating`), and
-- instantly: `pry_tile` has no do_after (floor.dm:159-161).
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
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "replace_component:station_base",
            yields = { plasma_glass_tile = 1 },
            done = "You pry up the glass floor tile.",
        },
    },
}
