-- One of the four emitters of the gravity battery, before it is welded in.
--
-- Facing is the way the nozzle points; the weld wants it pointing at the
-- centre. It turns with Alt+click loose or bolted down. No recipe makes
-- one: a map places it, like the heavy parts of tg's machinery.
local anchorable = require("@lib/anchorable")
local grav_smes = require("@lib/power/grav_smes")

local FACINGS = { "north", "east", "south", "west" }

-- The picture for facing F is the pillar of the opposite slot, loose or
-- bolted down.
local displaced_pictures = {
    north = "grav_emitter_north",
    south = "grav_emitter_south",
    east = "grav_emitter_east",
    west = "grav_emitter_west",
}
local anchored_pictures = {
    north = "grav_emitter_anchored_north",
    south = "grav_emitter_anchored_south",
    east = "grav_emitter_anchored_east",
    west = "grav_emitter_anchored_west",
}

local wrench_anchor, wrench_unanchor = anchorable.pair({
    sound = "ratchet",
    secs = 1.0,
    anchor = {
        start = "lunatic/tfs:entity.grav_emitter.anchor.start",
        done = "lunatic/tfs:entity.grav_emitter.anchor.done",
    },
    unanchor = {
        start = "lunatic/tfs:entity.grav_emitter.unanchor.start",
        done = "lunatic/tfs:entity.grav_emitter.unanchor.done",
    },
})

return {
    id = "grav_emitter",
    -- Large and loose, so it draws over items (large_object in content/compositions.luau).
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.grav_emitter.name",
    name = "graviton emitter",
    sprite = "grav_emitter_north",
    dense = true,
    opaque = false,
    category = "power",
    script = "grav_emitter",
    examine = {
        flavor = "A squat pillar with a nozzle that must face the centre of the gravity battery.",
    },
    motion_response = {
        mass = 120.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    states = { "displaced", "anchored" },
    state_sprites = {
        displaced = "grav_emitter_north",
        anchored = "grav_emitter_anchored_north",
    },
    -- Loose leads; the bolted-down preset is in its palette flyout.
    palette_states = { "displaced", "anchored" },
    facings = FACINGS,
    facing_sprites = { displaced = displaced_pictures, anchored = anchored_pictures },
    loose = { "displaced" },
    rotates = { "displaced", "anchored" },
    hint_flags = { grav_smes.ASSEMBLY_READY },
    actions = { grav_smes.weld_row() },
    transitions = {
        wrench_anchor,
        wrench_unanchor,
    },
}
