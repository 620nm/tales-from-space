-- A bolted grille glazed with thick amber lead-silicate glass.
-- Separate from plain `grille` so its states share no tool triggers with
-- clear-glass rungs (`girder` <-> `reinforced_girder`), keeping state-based
-- refusal sentences exact ("The lead glass grille must be unsealed first.").
return {
    id = "lead_glass_grille",
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.lead_glass_grille.name",
    name = "lead glass grille",
    sprite = "grille",
    dense = true,
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    opaque = false,
    states = {
        "glazed",
        "unsealed",
    },
    palette_states = { "glazed" },
    airtight = {
        "glazed",
        "unsealed",
    },
    state_sprites = {
        glazed = { "grille", "lead_window" },
        unsealed = { "grille", "lead_window" },
    },
    examine = {
        flavor = "A bolted grille glazed with thick amber lead-silicate glass that attenuates ionizing radiation.",
    },
    transitions = {
        {
            sound = "smash",
            at = "glazed",
            tool = "screwdriver",
            secs = 4.0,
            to = "unsealed",
            start = "You start unfastening the lead glass from its frame.",
            done = "The lead glass comes loose in its frame.",
        },
        {
            sound = "smash",
            at = "unsealed",
            tool = "screwdriver",
            secs = 4.0,
            to = "glazed",
            start = "You start fastening the lead glass to its frame.",
            done = "The lead glass is fastened to its frame.",
        },
        {
            sound = "smash",
            at = "unsealed",
            tool = "crowbar",
            secs = 10.0,
            yields = { lead_glass = 2 },
            gone = true,
            leaves = "grille",
            start = "You start prying the lead glass out of the grille.",
            done = "The lead glass pops free of the grille.",
        },
    },
}
