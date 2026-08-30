local content = {
    id = "beaker_bluespace", name = "bluespace beaker", sprite = "beaker_bluespace",
    volume_ml = 300, acts_on_items = true,
}
if sim ~= nil then
    vessel.attach({ id = content.id, noun = "beaker", phases = { "liquid", "solid" },
        pour = { units = 10 }, sip = { units = 2 }, spill = true })
end
return content
