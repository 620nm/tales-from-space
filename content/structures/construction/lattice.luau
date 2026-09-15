-- The first half of tg's EVA deck: a fixed, passable lattice raised
-- from one rod, then replaced by a catwalk with one more. Canonical
-- description, picture, smoothing, and refund are lattice.dm:1-19,
-- 69-82; the two rod steps and tile handoff are _open.dm:606-652.
-- Fall, footstep, and turf-trait effects have no pack substrate.
return {
    id = "lattice",
    visual_layer = "support",
    name_label = "lunatic/tfs:entity.lattice.name",
    name = "lattice",
    sprite = "lattice-0",
    dense = false,
    turf = "component:lattice",
    examine = {
        flavor = "A lightweight support lattice. These hold our station together.",
    },
    smooth = {
        group = "lattice",
        with = { "lattice", "catwalk" },
        sprites = "lattice",
    },
    build = {
        sound = "smash",
        on = { "substrate:space" },
        with = { rod = 1 },
        secs = 0.0,
        done = "You construct a lattice.",
    },
    transitions = {
        {
            sound = "smash",
            with = { rod = 1 },
            into = "replace_component:catwalk",
            done = "You construct a catwalk.",
        },
        {
            sound = "smash",
            with = { floor_tile = 1 },
            into = "replace_component:station_base",
        },
        {
            sound = "smash",
            tool = "cutters",
            yields = { rod = 1 },
            into = "remove_component",
            done = "Slicing lattice joints ...",
        },
    },
}
