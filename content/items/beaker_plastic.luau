local content = {
    id = "beaker_plastic", name = "x-large beaker", sprite = "beaker_plastic",
    volume_ml = 120, acts_on_items = true,
    fill_sprites = {
        { 1, "beaker_plastic_fill_1" }, { 10, "beaker_plastic_fill_10" },
        { 20, "beaker_plastic_fill_20" }, { 40, "beaker_plastic_fill_40" },
        { 60, "beaker_plastic_fill_60" }, { 80, "beaker_plastic_fill_80" },
        { 100, "beaker_plastic_fill_100" },
    },
}
if sim ~= nil then
    vessel.attach({ id = content.id, noun = "beaker", phases = { "liquid", "solid" },
        pour = { units = 10 }, sip = { units = 2 }, spill = true })
end
return content
