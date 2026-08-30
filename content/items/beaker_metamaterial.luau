local content = {
    id = "beaker_metamaterial", name = "metamaterial beaker", sprite = "beaker_metamaterial",
    volume_ml = 180, acts_on_items = true,
    fill_sprites = {
        { 1, "beaker_metamaterial_fill_1" }, { 10, "beaker_metamaterial_fill_10" },
        { 25, "beaker_metamaterial_fill_25" }, { 35, "beaker_metamaterial_fill_35" },
        { 50, "beaker_metamaterial_fill_50" }, { 60, "beaker_metamaterial_fill_60" },
        { 80, "beaker_metamaterial_fill_80" }, { 100, "beaker_metamaterial_fill_100" },
    },
}
if sim ~= nil then
    vessel.attach({ id = content.id, noun = "beaker", phases = { "liquid", "solid" },
        pour = { units = 10 }, sip = { units = 2 }, spill = true })
end
return content
