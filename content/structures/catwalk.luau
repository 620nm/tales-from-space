-- The finished EVA catwalk, still fixed and passable. Canonical
-- description, art, two-rod refund, and one-way smoothing are
-- code/game/objects/structures/lattice.dm:107-142; rod construction
-- and floor tiling are code/game/turfs/open/_open.dm:606-652.
-- Lava, fall, footstep, and cable effects have no pack substrate.
return {
    id = "catwalk",
    name = "catwalk",
    sprite = "catwalk-0",
    dense = false,
    examine = {
        flavor = "A catwalk for easier EVA maneuvering and cable placement.",
    },
    smooth = {
        group = "catwalk",
        sprites = "catwalk",
    },
    transitions = {
        {
            with = { floor_tile = 1 },
            into = "turf:plating",
        },
        {
            tool = "cutters",
            yields = { rod = 2 },
            gone = true,
            done = "Slicing catwalk joints ...",
        },
    },
}
