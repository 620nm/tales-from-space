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
    },
}
