-- The engineer's toolbelt: seven slots at the waist. `show_contents`
-- composes each tool's `stowed_sprite` into the belt object's ordinary
-- appearance (on the floor and in object views); a mob instead wears
-- tg's four-direction `mob/clothing/belt.dmi` icon.
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
    -- tg belt.dm:43-44.
    pickup_sound = "toolbelt_pickup",
    drop_sound = "toolbelt_drop",
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
