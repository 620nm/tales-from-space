-- Wire-reinforced lead-silicate glass floor window; joins `transparent_glass_floor`
-- smoothing and pries up instantly to `station_base`, yielding its tile.
return {
    id = "reinforced_lead_glass_floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.reinforced_lead_glass_floor.name",
    name = "reinforced lead glass floor",
    sprite = "reinforced_lead_glass_floor-0",
    dense = false,
    turf = "component:reinforced_lead_glass_floor",
    examine = {
        flavor = "Wire-reinforced amber lead-silicate glass deck plating built for structural and radiological shielding between levels.",
    },
    smooth = {
        group = "transparent_glass_floor",
        sprites = "reinforced_lead_glass_floor",
    },
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "replace_component:station_base",
            yields = { reinforced_lead_glass_tile = 1 },
            done = "You pry up the glass floor tile.",
        },
    },
}
