local physical_profiles = require("@lib/physical_profiles")
return {
    id = "id_security",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.id_security.name",
    name = "security ID card",
    sprite = "id",
    slot = "id",
    inhand_sprite = { "held_id_l", "held_id_r" },
    grants = "security",
    -- tg cards_ids.dm:29-30.
    pickup_sound = "id_card_pickup",
    drop_sound = "id_card_drop",
    -- What a card reader calls this while a hand holds it.
    hint_tags = { "card" },
}
