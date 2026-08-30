local content = {
    id = "beaker_cryostasis", name = "cryostasis beaker", sprite = "beaker_cryostasis",
    volume_ml = 50, reactive = false, acts_on_items = true,
    fill_sprites = {
        { 1, "beaker_cryostasis_fill_1" }, { 20, "beaker_cryostasis_fill_20" },
        { 40, "beaker_cryostasis_fill_40" }, { 60, "beaker_cryostasis_fill_60" },
        { 80, "beaker_cryostasis_fill_80" }, { 100, "beaker_cryostasis_fill_100" },
    },
}
if sim ~= nil then
    vessel.attach({ id = content.id, noun = "beaker", phases = { "liquid", "solid" },
        pour = { units = 10 }, sip = { units = 2 }, spill = true })
end
return content
