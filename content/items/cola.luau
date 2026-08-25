-- Dispensed by the vending machine; drinkable since M7. Clicking your
-- own tile with the can in hand takes a swig — the contents transfer
-- into your bloodstream mole by mole, and metabolism does the rest.
local content = {
    id = "cola",
    name = "can of Space Cola",
    sprite = "cola",
    inhand_sprite = { "held_cola_l", "held_cola_r" },
    contents = { water = 0.30, sugar = 0.06 },
    -- tg's soda can holds 30 u (soda.dm:21), which is the DRINK; the
    -- can is a 330 mL can, which is the shell. Those were the same
    -- number here until capacity became geometry, and reading a dose
    -- as a shell left a can with a millilitre of headspace over its own
    -- syrup. The shell is the whole of what it holds, and 30 u of cola
    -- rattles around in one the way a real can does.
    volume_ml = 330,
    -- A can is shut. It does not trade its headspace with the room, it
    -- can strain against its own lid, and what ferments inside one has
    -- nowhere to go -- which is the whole of why a forgotten cola is
    -- interesting (docs/CHEMISTRY.md 9). Opening one for good is
    -- `sim.unseal`, and nothing here does it yet.
    sealed = true,
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
        -- The reading's own total, rather than a hand sum over its
        -- phase rows: same number, and it stays right when a row grows
        -- a field that is not a mole count.
        local total = sim.matter_read(self).moles
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
