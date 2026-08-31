-- tg's chemist jumpsuit, including its inventory and worn state
-- (code/modules/clothing/under/jobs/medical.dm:132-141). TfS does not
-- yet model its fire and acid armour, so this file claims no protection.
return {
    id = "uniform_chemist",
    name = "chemist's jumpsuit",
    sprite = "uniform_chemist",
    slot = "uniform",
    covers = { "chest", "pelvis", "l_arm", "r_arm", "l_leg", "r_leg" },
    worn_sprite = "worn_uniform_chemist",
    pickup_sound = "cloth_pickup",
    drop_sound = "cloth_drop",
}
