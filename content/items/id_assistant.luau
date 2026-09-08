return {
    id = "id_assistant",
    name_label = "lunatic/tfs:entity.id_assistant.name",
    name = "assistant ID card",
    sprite = "id",
    inhand_sprite = { "held_id_l", "held_id_r" },
    slot = "id",
    -- tg cards_ids.dm:29-30.
    pickup_sound = "id_card_pickup",
    drop_sound = "id_card_drop",
    -- What a card reader calls this while a hand holds it.
    hint_tags = { "card" },
}
