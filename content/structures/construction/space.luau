-- Vacuum's reaction table: one tile of it, one floor tile, and the
-- station is a tile bigger. `anchored` is the rule that keeps it a
-- station and not an archipelago -- plating grows outward from ground
-- that already exists, never floating alone in the dark.
return {
    id = "space",
    visual_layer = "substrate",
    name_label = "lunatic/tfs:entity.space.name",
    name = "space",
    sprite = "plating", -- turf entries never spawn; this is the finish it lays
    turf = "substrate:space",
    transitions = {
        {
            sound = "smash",
            with = { floor_tile = 1 },
            secs = 1.5,
            into = "add_component:station_base",
            anchored = true,
            start = "You start laying plating.",
            done = "The plating settles into place.",
        },
        -- Welding restores the station base over the retained space substrate.
        {
            sound = "smash",
            tool = "welder",
            secs = 4.0,
            fuel = 0.3,
            into = "add_component:station_base",
            anchored = true,
            start = "You start welding the breach shut.",
            done = "You weld the breach shut.",
        },
    },
}
