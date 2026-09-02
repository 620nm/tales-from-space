-- What a torch burns. A welder's tank is an ordinary Holder, so this is
-- an ordinary substance: it pours, it spills, it mixes, and a cut girder
-- costs mols of it like everything else costs something.
-- Numbers are acetylene's (C2H2), the gas tg's welders nominally carry;
-- it sits in the tank as a liquid the way a beaker's contents do.
local content = {
    id = "welding_fuel",
    name = "welding fuel",
    molar_mass = 26.04,
    cv = 44.0,
    phase = { unmodeled = "liquid" },
    metabolism_rate = 0.004,
    -- What it does over a flame. tg: `burning_temperature = 1725`
    -- ("more refined than oil") and `burning_volume = 0.2`
    -- (other_reagents.dm:1377-1378) — twice ethanol's rate at a lower
    -- temperature, which is what "refined" buys you.
    --   0.2 u x 0.025 mol/u / 2 s x 0.5 s = 0.00125 mol per pass
    burn = { k = 1725, rate = 0.00125 },
    -- What it looks like through glass (tg: other_reagents.dm:1373).
    color = "#660000",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for acetylene, whose numbers this file carries.
    hazard = { health = 1, fire = 4, instability = 3 },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.damage.apply({ target = mob, amounts = { brute = 1.0 } })
        if math.random(1, 8) == 1 then
            sim.message.send({ recipient = mob, message = "Your throat burns." })
        end
    end)
end

return content
