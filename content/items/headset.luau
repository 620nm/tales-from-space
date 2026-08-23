-- Common-channel radio headset: carrying one anywhere on you is what
-- makes ';' speak on the radio (docs: closeout step 6d).
--
-- `radio` is BOTH halves of that: declaring a channel is what makes
-- this a radio at all, and the channel's name is the word every
-- listener sees the line bracketed with. The engine knows neither the
-- word "headset" nor the word "Common" -- it asks what you are carrying
-- and stamps the line with whatever the item answered.
return {
    id = "headset",
    name = "radio headset",
    sprite = "headset",
    inhand_sprite = { "held_headset_l", "held_headset_r" },
    radio = "Common",
}
