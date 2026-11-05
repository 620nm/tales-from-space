-- Lead-silicate glass floor window; joins `transparent_glass_floor` smoothing
-- with `glass_floor` and pries up instantly to `station_base`, yielding its tile.
return {
    id = "lead_glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.lead_glass_floor.name",
    name = "lead glass floor",
    sprite = "lead_glass_floor-0",
    dense = false,
    turf = "component:lead_glass_floor",
    examine = {
        flavor = "Heavy amber lead-silicate glass deck plating formulated to attenuate ionizing radiation between levels.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "lead_glass_floor",
    },
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "replace_component:station_base",
            yields = { lead_glass_tile = 1 },
            done = "You pry up the glass floor tile.",
        },
    },
}
