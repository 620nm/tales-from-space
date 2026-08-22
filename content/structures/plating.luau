-- The subfloor: what a laid tile stands on and what a sliced wall
-- leaves behind. Tiling over it is quick because the plating already
-- did the structural work -- the tile on top is the cosmetic half.
--
-- Two rods go the other way and reinforce it instead: three seconds,
-- tg's `do_after(user, 3 SECONDS)` at plating.dm:61, and the same two
-- rods a reinforced floor hands back when they are wrenched out again
-- (`:57`, "You need two rods to make a reinforced floor!").
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
        {
            with = { rod = 2 },
            secs = 3.0,
            into = "turf:reinforced_floor",
            start = "You start reinforcing the floor.",
            done = "The rods are wrenched down flush with the deck.",
        },
    },
}
