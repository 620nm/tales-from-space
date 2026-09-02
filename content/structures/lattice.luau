-- The first half of tg's EVA deck: a fixed, passable lattice raised
-- from one rod, then replaced by a catwalk with one more. Canonical
-- description, picture, smoothing, and refund are lattice.dm:1-19,
-- 69-82; the two rod steps and tile handoff are _open.dm:606-652.
-- Fall, footstep, and turf-trait effects have no pack substrate.
return {
    id = "lattice",
    name = "lattice",
    sprite = "lattice-0",
    dense = false,
    examine = {
        flavor = "A lightweight support lattice. These hold our station together.",
    },
    smooth = {
        group = "lattice",
        with = { "lattice", "catwalk" },
        sprites = "lattice",
    },
    build = {
        on = { "space" },
        with = { rod = 1 },
        secs = 0.0,
        done = "You construct a lattice.",
    },
    transitions = {
        {
            with = { rod = 1 },
            leaves = "catwalk",
            gone = true,
            done = "You construct a catwalk.",
        },
        {
            with = { floor_tile = 1 },
            into = "turf:plating",
        },
        {
            tool = "cutters",
            yields = { rod = 1 },
            gone = true,
            done = "Slicing lattice joints ...",
        },
    },
}
