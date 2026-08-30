local content = {
    id = "water_bottle_large", name = "large bottle of water", sprite = "water_bottle_large",
    volume_ml = 100, sealed = true, resealable = true, acts_on_items = true,
    contents = { water = 2.5 },
    fill_sprites = {
        { 10, "water_bottle_large_fill_10" }, { 25, "water_bottle_large_fill_25" },
        { 50, "water_bottle_large_fill_50" }, { 75, "water_bottle_large_fill_75" },
        { 80, "water_bottle_large_fill_80" }, { 90, "water_bottle_large_fill_90" },
    },
    variants = { empty = { name = "empty large water bottle", contents = {}, sealed = false } },
}
if sim ~= nil then
    local d = vessel.attach({ id = content.id, noun = "bottle", phases = { "liquid" },
        pour = { units = 10 }, spill = true })
    d:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        if sim.matter_read(ev.subject).sealed then sim.unseal(ev.subject) else sim.seal(ev.subject) end
        return true
    end)
end
return content
