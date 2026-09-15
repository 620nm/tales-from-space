-- Transparent grid cover retains the station base when pried away.
return {
    id = "grid_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.floor.name",
    name = "grid floor",
    sprite = "open_floor",
    turf = "component:grid_cover",
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "remove_component",
            yields = { floor_tile = 1 },
            done = "You pry up the floor tile.",
        },
    },
}
