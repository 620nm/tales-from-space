-- The engineer's toolbelt: seven slots at the waist, and — unlike the
-- backpack — a container that WEARS its contents. `show_contents` is
-- the standing invitation; each tool's own `stowed_sprite` is what
-- gets drawn, so the belt on a hip is a running inventory you can read
-- across the room.
--
-- tg: /obj/item/storage/belt/utility (belt.dm:35), whose
-- `content_overlays = TRUE` does exactly this, and
-- /obj/item/storage/belt/utility/full/engi (belt.dm:119) for the
-- seven things it arrives with.
return {
    id = "toolbelt",
    name = "toolbelt",
    sprite = "toolbelt",
    inhand_sprite = { "held_toolbelt_l", "held_toolbelt_r" },
    slot = "belt",
    worn_sprite = "worn_toolbelt",
    storage = 7,
    show_contents = true,
    holds = {
        "screwdriver",
        "wrench",
        "welder",
        "crowbar",
        "wirecutters",
        "multitool",
        "cable_coil",
    },
}
