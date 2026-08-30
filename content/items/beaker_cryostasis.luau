local content = {
    id = "beaker_cryostasis", name = "cryostasis beaker", sprite = "beaker_cryostasis",
    volume_ml = 50, reactive = false, acts_on_items = true,
}
if sim ~= nil then
    vessel.attach({ id = content.id, noun = "beaker", phases = { "liquid", "solid" },
        pour = { units = 10 }, sip = { units = 2 }, spill = true })
end
return content
