local vessel = require("@lib/vessel")

local content = {
    id = "beaker_bluespace",
    visual_layer = "item",
    name_label = "lunatic/tfs:entity.beaker_bluespace.name",
    name = "bluespace beaker",
    sprite = "beaker_bluespace",
    volume_ml = 300,
    acts_on_items = true,
}
local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "beaker",
    phases = { "liquid", "solid" },
    pour = { units = 10 },
    sip = { units = 2 },
    spill = true,
}
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end
return content
