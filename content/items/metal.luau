-- Metal sheets, the structural material. What they BUILD is no longer
-- written here: a girder knows two sheets raise it, a machine frame
-- knows five box it up, and both live in tfs/content/structures/. This
-- file is what a sheet IS, which is all a material has ever needed to
-- know about itself.
return {
    id = "metal",
    name = "metal sheets",
    sprite = "metal",
    inhand_sprite = { "held_metal_l", "held_metal_r" },
    -- A stack sounds like the material it is. tg sheets.dm:18-19.
    pickup_sound = "metal_pickup",
    drop_sound = "metal_drop",
    stack = 30,
}
