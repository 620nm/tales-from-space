local anchorable = require("@lib/anchorable")

local wrench_anchor, wrench_unanchor = anchorable.pair({
    sound = "smash",
    over = "fitting",
    anchor = { done = "lunatic/tfs:structures.dewar.fasten" },
    unanchor = { done = "lunatic/tfs:structures.dewar.unfasten" },
})

-- A portable vacuum-jacketed liquid dewar (assets/sprites/95-process-machines.ron).
-- Fastened to a connector port, it equalizes condensed liquid with the pipe
-- network while keeping its gas headspace isolated; loose, its valve drains
-- liquid volumetrically onto the room tile while its relief valve vents
-- boil-off vapor above 1200 kPa.
return {
    id = "dewar",
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.dewar.name",
    name = "liquid dewar",
    sprite = "dewar",
    script = "dewar",
    ui = { modules = { "canister" } },
    sounds = { open = "hiss", toggle = "click" },
    fixture = "Canister",
    examine = {
        flavor = "A vacuum-jacketed brass-collared vessel built to hold and meter cryogenic or bulk liquids.",
    },
    canister = {
        phases = { "liquid" },
        volume_l = 1000.0,
        rated_kpa = 2500.0,
        rate_lps = 10.0,
        max_rate_lps = 50.0,
        rate_step_lps = 1.0,
        relief_kpa = 1200.0,
        relief_rate_lps = 20.0,
        gauge_sprites = { "dewar_g0", "dewar_g1", "dewar_g2", "dewar" },
    },
    dense = true,
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    states = { "anchored", "displaced", "broken" },
    passable = { "broken" },
    loose = { "displaced", "broken" },
    state_sprites = {
        anchored = "dewar_connected",
        displaced = "dewar",
        broken = "dewar_broken",
    },
    failure = {
        integrity = 250,
        break_at = 0.4,
        limit_kpa = 3000,
        jitter = 0.0,
        damage_min = 10,
        damage_max = 60,
        on_break = "dump",
        broken_state = "broken",
        sound = "spray",
        message = "lunatic/tfs:structures.dewar.split",
    },
    gestures = { "secondary" },
    interaction_labels = {
        secondary = { label = "lunatic/tfs:action.dewar.pour_in" },
    },
    transitions = {
        wrench_unanchor,
        wrench_anchor,
    },
}
