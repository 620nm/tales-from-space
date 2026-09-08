local content = {
    id = "beaker_large", name_label = "lunatic/tfs:entity.beaker_large.name", name = "large beaker", sprite = "beaker_large",
    volume_ml = 100, acts_on_items = true,
    fill_sprites = {
        { 1, "beaker_large_fill_1" }, { 20, "beaker_large_fill_20" },
        { 40, "beaker_large_fill_40" }, { 60, "beaker_large_fill_60" },
        { 80, "beaker_large_fill_80" }, { 100, "beaker_large_fill_100" },
    },
}
local vessel_spec = { id = content.id, noun = "beaker", phases = { "liquid", "solid" },
    pour = { units = 10 }, sip = { units = 2 }, spill = true }
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end
return content
