-- tg's chemistry backpack: the stain-resistant seven-pocket back slot
-- (`/obj/item/storage/backpack/chemistry`, backpack.dm:182-186).
return {
    id = "chemistry_backpack",
    name = "chemistry backpack",
    sprite = "chemistry_backpack",
    inhand_sprite = { "held_chemistry_backpack_l", "held_chemistry_backpack_r" },
    slot = "back",
    storage = 7,
    worn_sprite = "worn_chemistry_backpack",
    pickup_sound = "backpack_pickup",
    drop_sound = "backpack_drop",
}
