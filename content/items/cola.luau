-- Dispensed by the vending machine; drinkable since M7. Clicking your
-- own tile with the can in hand takes a swig — the contents transfer
-- into your bloodstream mole by mole, and metabolism does the rest.
local content = {
    id = "cola",
    name = "can of Space Cola",
    sprite = "cola",
    inhand_sprite = { "held_cola_l", "held_cola_r" },
    contents = { water = 0.30, sugar = 0.06 },
    -- tg's soda can (soda.dm:21). The can is the shell and the shell is
    -- the whole of what it holds, so what is poured in is bounded by
    -- how much room the syrup and the water leave.
    volume_ml = 30,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        local px, py = user.tile.x, user.tile.y
        if x ~= px or y ~= py then
            return { replaced = false } -- only a click on your own tile drinks
        end
        local c = sim.matter_read(self).contents
        local total = 0
        for _, phases in pairs(c) do
            for _, n in pairs(phases) do
                total = total + n
            end
        end
        if total < 0.001 then
            sim.message.send({ recipient = user, message = "The can is empty." })
            return true
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
        sim.matter.transfer({
            from = self,
            to = user,
            amount = 0.05,
            phases = { "liquid", "solid" },
        })
        sim.message.send({ recipient = user, message = "You take a swig of Space Cola." })
        return true
    end)
end

return content
