local content = { id = "airlock_button" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock_button", { prototype = content.id })
    def:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        if ev.implement ~= nil then return { replaced = false } end
        controller.button(ev)
        return true
    end)
    -- A held item it declined, and no later step took the click either:
    -- the press wants an empty hand (structures/airlock_button.luau).
    def:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        if ev.implement == nil or ev.outcome ~= "failed" then return end
        sim.message.send({ recipient = ev.actor,
            message = sim.msg("lunatic/tfs:entity.airlock_button.hand_full", {}) })
    end)
end
return content
