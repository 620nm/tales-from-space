local physical_profiles = require("@lib/physical_profiles")
local vessel = require("@lib/vessel")

-- A measured pellet of polymer resin. It is the short route around a
-- beaker batch: a chemist can pour one pellet into a vessel and continue
-- a toner or plastic run without carrying the packager's docked glass.
local content = {
    id = "resin_pellet",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.resin_pellet.name",
    name = "resin pellet",
    sprite = "plasteel",
    inhand_sprite = { "held_plasteel_l", "held_plasteel_r" },
    volume_ml = 15,
    acts_on_items = true,
}

local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "resin pellet",
    phases = { "solid" },
    pour = { units = "all" },
}
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end

return content
