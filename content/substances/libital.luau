-- The brute-healing workhorse (tg's libital, in spirit — tg's unit
-- economy doesn't map to moles, so the numbers are lunatic-calibrated:
-- one 0.15 mol beaker heals ~75 brute over ~100 s).
local content = {
    id = "libital",
    name = "libital",
    molar_mass = 180.0,
    cv = 90.0,
    metabolism_rate = 0.003,
    -- What it looks like through glass (tg: cat2_medicine_reagents.dm:105).
    color = "#ECEC8D",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.healing.apply({ target = mob, amounts = { brute = 1.5 } })
        if math.random(1, 10) == 1 then
            sim.message.send({ recipient = mob, message = "Your bruises ache less." })
        end
    end)
end

return content
