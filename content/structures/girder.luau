-- The first stage of every wall (tg's girders.dm). Two sheets stand one
-- up; two more plate it into hull; a torch cuts it back down to exactly
-- what it cost. Both numbers below are the only copy of themselves --
-- the radial reads cost and time from here, so the menu can no longer
-- disagree with the validator.
--
-- A girder comes out of the box bolted down: tg's stack recipe is
-- literally "wall girders (anchored)" and spawns an anchored girder, so
-- the wrench is not a step in raising one -- it is how you take the
-- bolts back out. A displaced girder is a girder you can shove around
-- the deck, and it will not take a wall until it is bolted down again
-- (tg's wall recipes all demand GIRDER_NORMAL).
return {
    id = "girder",
    name = "girder",
    sprite = "girder",
    dense = true,
    states = { "anchored", "displaced" },
    state_sprites = { displaced = "girder_displaced" },
    -- Nothing holds a displaced girder to the deck, so a walker can
    -- shove it and a decompression can drag it.
    loose = { "displaced" },
    build = {
        on = { "floor", "plating" },
        with = { metal = 2 },
        secs = 4.0,
        start = "You start assembling a girder.",
        done = "The girder stands.",
    },
    transitions = {
        -- A Wall is a turf, not a thing standing on one: the girder is
        -- consumed into the geometry, and the seam does the rest. Only
        -- from the bolted state -- you cannot plate hull onto something
        -- that slides when you lean on it.
        {
            at = "anchored",
            with = { metal = 2 },
            secs = 4.0,
            into = "turf:wall",
            start = "You start plating the girder into a wall.",
            done = "The wall stands.",
        },
        -- One sheet of plasteel makes it the reinforced frame instead,
        -- five seconds (tg girders.dm:59-61, `try_construction_step(...,
        -- 5 SECONDS, req_state = GIRDER_NORMAL, amount = 1)` followed by
        -- `replace_girder`). Bolted down only, for the same reason the
        -- wall step is: tg asks GIRDER_NORMAL, and a frame that slides
        -- when you lean on it takes no reinforcement either. tg swaps
        -- one object for another, so this row does too -- the girder
        -- goes and the reinforced one is what stands there.
        {
            at = "anchored",
            with = { plasteel = 1 },
            secs = 5.0,
            gone = true,
            leaves = "reinforced_girder",
            start = "You start reinforcing the girder.",
            done = "The plasteel struts into the frame.",
        },
        {
            at = "anchored",
            tool = "wrench",
            secs = 4.0,
            to = "displaced",
            start = "You start unsecuring the girder.",
            done = "The girder shifts loose of its bolts.",
        },
        {
            at = "displaced",
            tool = "wrench",
            secs = 4.0,
            to = "anchored",
            start = "You start securing the girder.",
            done = "The girder is bolted to the deck.",
        },
        -- No `at`: a torch cuts one apart bolted or not (tg's
        -- welder_act asks no state at all).
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
