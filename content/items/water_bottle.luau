local content = {
    id = "water_bottle", name_label = "lunatic/tfs:entity.water_bottle.name", name = "bottle of water", sprite = "water_bottle_small",
    volume_ml = 50, sealed = true, resealable = true, acts_on_items = true,
    contents = { water = 1.2375, fluorine = 0.0125 },
    fill_sprites = {
        { 10, "water_bottle_small_fill_10" }, { 25, "water_bottle_small_fill_25" },
        { 50, "water_bottle_small_fill_50" }, { 75, "water_bottle_small_fill_75" },
        { 80, "water_bottle_small_fill_80" }, { 90, "water_bottle_small_fill_90" },
    },
    variants = { empty = { name_label = "lunatic/tfs:entity.water_bottle.empty.name", name = "empty water bottle", contents = {}, sealed = false } },
}
local vessel_spec = { id = content.id, noun = "bottle", phases = { "liquid" },
    pour = { units = 10 }, spill = true }
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    local d = vessel.attach(vessel_spec)
    d:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        if sim.matter_read(ev.subject).sealed then sim.unseal(ev.subject) else sim.seal(ev.subject) end
        return true
    end)
end
return content
