-- The humble backpack: seven slots of anything, worn on the back.
return {
    id = "backpack",
    name = "backpack",
    sprite = "backpack",
    inhand_sprite = { "held_backpack_l", "held_backpack_r" },
    -- tg backpack.dm:26-27.
    pickup_sound = "backpack_pickup",
    drop_sound = "backpack_drop",
    slot = "back",
    storage = 7,
    worn_sprite = "worn_backpack",
}
