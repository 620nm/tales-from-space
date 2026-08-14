-- Vacuum's reaction table: one tile of it, one floor tile, and the
-- station is a tile bigger. `anchored` is the rule that keeps it a
-- station and not an archipelago -- plating grows outward from ground
-- that already exists, never floating alone in the dark.
return {
    id = "space",
    name = "space",
    sprite = "plating", -- turf entries never spawn; this is the finish it lays
    turf = "space",
    transitions = {
        {
            with = { floor_tile = 1 },
            secs = 1.5,
            into = "turf:plating",
            anchored = true,
            start = "You start laying plating.",
            done = "The plating settles into place.",
        },
        -- A hull breach is not a state, it is a Floor that became
        -- Space (sim/geometry.rs). So welding one shut is the same
        -- step as any other: vacuum, next to something solid, becomes
        -- plating again. `anchored` is why you cannot weld the void.
        {
            tool = "welder",
            secs = 4.0,
            fuel = 2.0,
            into = "turf:plating",
            anchored = true,
            start = "You start welding the breach shut.",
            done = "You weld the breach shut.",
        },
    },
}
