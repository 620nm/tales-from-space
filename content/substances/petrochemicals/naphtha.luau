-- Light hydrocarbon fuel, solvent and feedstock, represented as C8H16.
-- The fixed liquid phase and rounded mass convention are documented in
-- docs/PETROCHEMISTRY.md; this is a blend, not a pure compound.
local content = {
    id = "naphtha",
    name = "naphtha",
    molar_mass = 112.22,
    cv = 100.0,
    metabolism_rate = 0.004,
    phase = { unmodeled = "liquid" },
    -- A light hydrocarbon blend. Convention rather than a pure-compound
    -- measurement (docs/CHEMISTRY.md, D2).
    density = { liquid = 0.75 },
    flow = {
        viscosity = 0.7,
        surface_tension = 25.0,
        contact_angle = 15,
    },
    -- Fuel use is intentionally close to the old torch fuel's gameplay
    -- feel while using the new name and the blend's broader applications.
    burn = { k = 2100, rate = 0.00125 },
    color = "#9B5A24",
    group = "volatile",
    hazard = { health = 1, fire = 3, instability = 1 },
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob = ev.entity
        sim.damage.apply({ target = mob, amounts = { brute = 1.0 } })
        if math.random(1, 8) == 1 then
            sim.message.send({
                recipient = mob,
                message = sim.msg("lunatic/tfs:substances.naphtha.your_throat_burns", {}),
            })
        end
    end)
end

return content
