-- The finished EVA catwalk, still fixed and passable. Canonical
-- description, art, two-rod refund, and one-way smoothing are
-- code/game/objects/structures/lattice.dm:107-142; rod construction
-- and floor tiling are code/game/turfs/open/_open.dm:606-652.
-- Removal declares dependent power-cable loss; replacement keeps supported runs.
return {
    id = "catwalk",
    visual_layer = "support",
    name_label = "lunatic/tfs:entity.catwalk.name",
    name = "catwalk",
    sprite = "catwalk-0",
    dense = false,
    turf = "component:catwalk",
    examine = {
        flavor = "A catwalk for easier EVA maneuvering and cable placement.",
    },
    smooth = {
        group = "catwalk",
        sprites = "catwalk",
    },
    transitions = {
        {
            sound = "smash",
            with = { floor_tile = 1 },
            into = "replace_component:station_base",
        },
        {
            sound = "smash",
            tool = "cutters",
            yields = { rod = 2 },
            into = "remove_component",
            composition_transition = "remove_catwalk",
            done = "Slicing catwalk joints ...",
        },
    },
}
