-- Furniture with opinions.
return {
    id = "tv",
    name = "television set",
    sprite = "tv",
    dense = true,
    script = "tv",
    corded = true,
    -- AND BACK APART. tg gives every machine the same two rungs
    -- generically: a screwdriver opens the maintenance panel
    -- (`default_deconstruction_screwdriver`, _machinery.dm:1049) and a
    -- crowbar takes it apart behind the open panel
    -- (`default_deconstruction_crowbar`, :912). Both are instant there,
    -- so neither names a `secs` here.
    --
    -- What is left standing is the assembly it was screwed together
    -- from, in the state that holds a board and its parts -- so the
    -- board and everything in the sockets come back out of the frame's
    -- own crowbar, at the tiers that are actually fitted
    -- (docs/CONSTRUCTION.md, "machine teardown").
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
}
