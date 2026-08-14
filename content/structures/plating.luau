-- The subfloor: what a laid tile stands on and what a sliced wall
-- leaves behind. Tiling over it is quick because the plating already
-- did the structural work -- the tile on top is the cosmetic half.
return {
    id = "plating",
    name = "plating",
    sprite = "plating",
    turf = "plating",
    transitions = {
        {
            with = { floor_tile = 1 },
            secs = 0.5,
            into = "turf:floor",
            start = "You start tiling the floor.",
            done = "The floor is tiled.",
        },
    },
}
