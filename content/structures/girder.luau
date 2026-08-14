-- The first stage of every wall (tg's girders.dm). Two sheets stand one
-- up; two more plate it into hull; a torch cuts it back down to exactly
-- what it cost. Both numbers below are the only copy of themselves --
-- the radial reads cost and time from here, so the menu can no longer
-- disagree with the validator.
return {
    id = "girder",
    name = "girder",
    sprite = "girder",
    dense = true,
    build = { on = { "floor", "plating" }, with = { metal = 2 }, secs = 4.0 },
    transitions = {
        -- A Wall is a turf, not a thing standing on one: the girder is
        -- consumed into the geometry, and the seam does the rest.
        {
            with = { metal = 2 },
            secs = 4.0,
            into = "turf:wall",
            start = "You start plating the girder into a wall.",
            done = "The wall stands.",
        },
        {
            tool = "welder",
            secs = 4.0,
            fuel = 2.0,
            yields = { metal = 2 },
            gone = true,
            start = "You start cutting the girder apart.",
            done = "The girder comes apart.",
        },
    },
}
