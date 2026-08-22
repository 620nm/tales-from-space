-- The apparatus: a close-fitting mask with a coupling on it, and the
-- one thing that makes a bottle of oxygen worth carrying. It does
-- nothing on its own -- it is the half of internals that has no gas in
-- it -- and everything a tank does goes through it.
--
-- tg: /obj/item/clothing/mask/breath (code/modules/clothing/masks/
-- breath.dm:1-9), whose whole contribution is MASKINTERNALS: the flag
-- that says a supply line may reach the lungs through this. Here that
-- flag is `breath_mask`, and the engine refuses it on anything that is
-- not worn on the face (docs/LUAU-API.md, Internals).
--
-- Silent on purpose: /obj/item/clothing sets no pickup_sound or
-- drop_sound and neither does _masks.dm, so a mask is picked up
-- without a noise in tg too (the rule the headset already keeps).
return {
    id = "breath_mask",
    name = "breath mask",
    sprite = "breath_mask",
    inhand_sprite = { "held_breath_mask_l", "held_breath_mask_r" },
    slot = "mask",
    worn_sprite = "worn_breath_mask",
    breath_mask = true,
}
