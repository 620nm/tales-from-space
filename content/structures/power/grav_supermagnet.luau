-- One of the four supermagnet rings of the gravity battery, before it is
-- welded in.
--
-- Loose it is a cart that shows no facing; bolted down it draws the corner
-- arc its facing names (north is the north-west arc, then clockwise) and
-- turns with Alt+click. No recipe makes one: a map places it.
local loose = "grav_supermagnet_loose"

return {
    id = "grav_supermagnet",
    -- Large and loose, so it draws over items (large_object in content/compositions.luau).
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.grav_supermagnet.name",
    name = "supermagnet ring",
    sprite = loose,
    dense = true,
    opaque = false,
    category = "power",
    script = "grav_supermagnet",
    examine = {
        flavor = "A ring of superconducting coil that must sit in a corner of the gravity battery.",
    },
    motion_response = {
        mass = 160.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    states = { "displaced", "anchored" },
    -- Loose leads; the bolted-down preset is in its palette flyout.
    palette_states = { "displaced", "anchored" },
    facings = { "north", "east", "south", "west" },
    facing_sprites = {
        displaced = { north = loose, south = loose, east = loose, west = loose },
        anchored = {
            north = "grav_supermagnet_north",
            south = "grav_supermagnet_south",
            east = "grav_supermagnet_east",
            west = "grav_supermagnet_west",
        },
    },
    loose = { "displaced" },
    rotates = { "anchored" },
    transitions = {
        {
            sound = "ratchet",
            at = "displaced",
            tool = "wrench",
            secs = 1.0,
            to = "anchored",
            start = "lunatic/tfs:entity.grav_supermagnet.anchor.start",
            done = "lunatic/tfs:entity.grav_supermagnet.anchor.done",
        },
        {
            sound = "ratchet",
            at = "anchored",
            tool = "wrench",
            secs = 1.0,
            to = "displaced",
            start = "lunatic/tfs:entity.grav_supermagnet.unanchor.start",
            done = "lunatic/tfs:entity.grav_supermagnet.unanchor.done",
        },
    },
}
