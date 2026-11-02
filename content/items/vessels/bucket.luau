local physical_profiles = require("@lib/physical_profiles")
local vessel = require("@lib/vessel")

-- The bucket: tg's `/obj/item/reagent_containers/cup/bucket`
-- (code/modules/reagents/reagent_containers/cups/_cup.dm:585-613). Every row
-- is docs/janitorial/bucket.md. tg's 70 units keep their ratio to the mop's
-- head (15 u, 250 mL here), so the bucket still holds four and two-thirds
-- heads. Pour and sip are the vessel's; a wrung mop arrives through the mop.
local content = {
    id = "bucket",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.bucket.name",
    name = "bucket",
    sprite = "bucket",
    inhand_sprite = { "held_bucket_l", "held_bucket_r" },
    examine = { flavor = "It's a bucket." },
    volume_ml = 1167,
    -- `fill_icon_thresholds = list(50, 90)` (_cup.dm:595).
    fill_sprites = {
        { 50, "bucket_fill_50" },
        { 90, "bucket_fill_90" },
    },
    acts_on_items = true,
}

local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "bucket",
    phases = { "liquid", "solid" },
    -- `amount_per_transfer_from_this = 20` (_cup.dm:598) at the same scale:
    -- a third of a litre, 18.5 mol of water, 740 of the vessel's units.
    pour = { units = 740 },
    sip = { units = 2 },
    spill = true,
}
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end

return content
