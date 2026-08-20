-- The suit the station keeps by the way out: sealed, unglamorous, and
-- the only thing on board that lets a crewman work outside the hull.
-- Pair it with a tank and the two halves of surviving vacuum are
-- covered -- the suit keeps the pressure on the skin, the tank keeps
-- the oxygen going in, and NEITHER does the other's job. A tank alone
-- in a vacuum stops you suffocating while the vacuum still takes you
-- apart, which is tg's division and the whole reason both exist.
--
-- tg: /obj/item/clothing/suit/space/eva (code/modules/clothing/
-- spacesuits/softsuit.dm:30-33), and the STOPSPRESSUREDAMAGE its
-- /obj/item/clothing/suit/space parent carries
-- (_spacesuits.dm:80-101) -- here the `pressure_proof` flag, which the
-- engine refuses on anything not worn as a suit.
--
-- What is deliberately NOT here: tg's slowdown, cold protection,
-- armour and helmet requirement. There is no prototype field for any of
-- them, and inventing one to hold a number nothing reads would be a
-- knob rather than a feature. When those systems land, this file grows
-- the line they need.
--
-- Handled like a helmet rather than like cloth, which is tg's own
-- choice for space suits (_spacesuits.dm:33-34) rather than the
-- cloth pair its plain-suit parent uses.
return {
    id = "eva_suit",
    name = "EVA suit",
    sprite = "eva_suit",
    inhand_sprite = { "held_eva_suit_l", "held_eva_suit_r" },
    pickup_sound = "helmet_pickup",
    drop_sound = "helmet_drop",
    slot = "suit",
    worn_sprite = "worn_eva_suit",
    pressure_proof = true,
}
