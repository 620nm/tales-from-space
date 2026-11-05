-- A supermagnet ring packed on its cart, before it is set in the gravity
-- battery.
--
-- A wrench sets it between two bolted emitters, where it unfolds into
-- `grav_supermagnet_ring` (lib/power/grav_smes.luau). No recipe makes one: a map
-- places it.
local grav_smes = require("@lib/power/grav_smes")

return {
    id = "grav_supermagnet",
    -- Large and loose, so it draws over items (large_object in content/compositions.luau).
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.grav_supermagnet.name",
    name = "packed supermagnet ring",
    sprite = "grav_supermagnet_loose",
    dense = true,
    opaque = false,
    category = "power",
    script = "grav_supermagnet",
    examine = {
        flavor = "A ring of superconducting coil, packed on a cart. It has to be set in the corner between two emitters.",
    },
    motion_response = {
        mass = 160.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    states = { "displaced" },
    loose = { "displaced" },
    -- The cart looks the same from every side, so it takes no turn.
    facings = { "north", "east", "south", "west" },
    facing_sprites = {
        displaced = {
            north = "grav_supermagnet_loose",
            east = "grav_supermagnet_loose",
            south = "grav_supermagnet_loose",
            west = "grav_supermagnet_loose",
        },
    },
    rotates = {},
    hint_flags = { grav_smes.RING_FITS },
    actions = {
        {
            id = "set_ring",
            gesture = "primary",
            route = "receiver",
            label = "lunatic/tfs:ui.affordance.anchor",
            held = { fact = "held.proto", value = "wrench" },
            uses_held = true,
            needs = "lunatic/tfs:lib.grav_smes.ring_needs_wrench",
            suggest_implement = { item = "wrench" },
            refuse = {
                {
                    when = { ["not"] = { fact = "target.flag", value = grav_smes.RING_FITS } },
                    label = "lunatic/tfs:lib.grav_smes.ring_unfit",
                    hint_only = true,
                },
            },
        },
    },
}
