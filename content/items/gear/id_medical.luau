return {
    id = "id_medical",
    visual_layer = "entities",
    held_visual_layer = "held",
    worn_visual_layer = "equipment_id",
    name_label = "lunatic/tfs:entity.id_medical.name",
    name = "medical ID card",
    sprite = "id",
    slot = "id",
    inhand_sprite = { "held_id_l", "held_id_r" },
    grants = "medical",
    -- tg cards_ids.dm:29-30.
    pickup_sound = "id_card_pickup",
    drop_sound = "id_card_drop",
    -- What a card reader calls this while a hand holds it.
    hint_tags = { "card" },
}
