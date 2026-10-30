-- One supermagnet ring set in a corner of the gravity battery, before it is
-- welded in.
--
-- Its facing names the corner arc it draws (north is the north-west arc,
-- then clockwise) and comes from the two emitters it was set between, so it
-- does not turn by hand. A wrench packs it back onto its cart.
local grav_smes = require("@lib/grav_smes")

local CORNERS = { "north", "east", "south", "west" }

return {
    id = "grav_supermagnet_ring",
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.grav_supermagnet_ring.name",
    name = "supermagnet ring",
    sprite = "grav_supermagnet_ring_north",
    dense = true,
    opaque = false,
    category = "power",
    script = "grav_supermagnet_ring",
    examine = {
        flavor = "A ring of superconducting coil, set in a corner of the gravity battery.",
    },
    states = { "anchored" },
    facings = CORNERS,
    facing_sprites = {
        anchored = {
            north = "grav_supermagnet_ring_north",
            east = "grav_supermagnet_ring_east",
            south = "grav_supermagnet_ring_south",
            west = "grav_supermagnet_ring_west",
        },
    },
    rotates = {},
    hint_flags = { grav_smes.ASSEMBLY_READY },
    actions = { grav_smes.weld_row() },
    transitions = {
        {
            sound = "ratchet",
            at = "anchored",
            tool = "wrench",
            hint = { id = "unanchor", label = "lunatic/tfs:ui.affordance.unanchor" },
            secs = 1.0,
            gone = true,
            leaves = "grav_supermagnet",
            start = "lunatic/tfs:entity.grav_supermagnet_ring.unanchor.start",
            done = "lunatic/tfs:entity.grav_supermagnet_ring.unanchor.done",
        },
    },
}
