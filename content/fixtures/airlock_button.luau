local content = { id = "airlock_button" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock_button", { prototype = content.id })
    def:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        controller.button(ev)
        return true
    end)
    -- The `press` row refused a full hand and no later step took the click;
    -- a screwdriver's removal resolves it and stays quiet.
    def:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        local refusal = ev.refusal
        if ev.outcome ~= "refused" or refusal.action ~= "press" or refusal.fact ~= "held.present"
            or refusal.resolved then return end
        sim.message.send({ recipient = ev.actor,
            message = sim.msg("lunatic/tfs:entity.airlock_button.hand_full", {}) })
    end)
end
return content
