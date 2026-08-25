-- Dissolved sugar: mild pick-me-up. The physics half (cv, molar mass)
-- feeds the matter registry; metabolism_rate and mob.life are the
-- gameplay half. moles is how much this metabolism tick burned.
local content = {
    id = "sugar",
    name = "sugar",
    molar_mass = 342.3,
    cv = 120.0,
    phase = { unmodeled = "solid" },
    metabolism_rate = 0.004,
    -- What it looks like through glass (tg: food_reagents.dm:313 (COLOR_WHITE)).
    color = "#FFFFFF",
    -- `mob.life(ctx, self, user, moles)`: the hook hands the same mob
    -- twice -- as the thing it is on and as the body it is happening to
    -- -- and the moles burned this metabolism tick last.
    --
    -- The heal is written against those moles rather than flat, because
    -- what a pick-me-up is worth is how much of it you just burned. A
    -- full trip is `metabolism_rate` x 125 = the same 0.5 oxy it has
    -- always been; the dregs at the bottom of a can are worth
    -- proportionally less, which is the honest shape and the one the
    -- comment above always claimed.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.healing.apply({ target = mob, amounts = { oxy = moles * 125.0 } })
        if math.random(1, 12) == 1 then
            sim.message.send({ recipient = mob, message = "The sugar perks you up a little." })
        end
    end)
end

return content
