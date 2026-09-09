local content = { id = "airlock_button" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock_button", { prototype = content.id })
    def:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        if ev.implement ~= nil then return { replaced = false } end
        controller.button(ev)
        return true
    end)
end
return content
