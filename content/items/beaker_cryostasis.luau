local content = {
    id = "beaker_cryostasis", name_label = "lunatic/tfs:entity.beaker_cryostasis.name", name = "cryostasis beaker", sprite = "beaker_cryostasis",
    volume_ml = 50, reactive = false, acts_on_items = true,
}
local vessel_spec = { id = content.id, noun = "beaker", phases = { "liquid", "solid" },
    pour = { units = 10 }, sip = { units = 2 }, spill = true }
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end
return content
