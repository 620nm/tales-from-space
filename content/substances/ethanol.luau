-- Where fermentation leads. Flavor only until drunkenness mechanics —
-- but it metabolizes, and the ledger knows you had some.
--
-- Its phase curve is REAL, unlike ammonia's and chlorine's, and it can
-- be: ethanol is a product and nothing on this shelf consumes it as a
-- reactant, so a curve costs no recipe anything. NIST: boiling 351.5 K,
-- melting 159.0 K, heat of vaporization 38.56 kJ/mol, heat of fusion
-- 4.90 kJ/mol, liquid density 0.789 g/mL. Gas heat capacity is 65.4
-- J/(mol*K); the condensed columns keep tg's 112.
--
-- The visible consequence is small and correct: a bottle of spirit left
-- open in a warm room slowly goes down. A burner does not, because a
-- burner has a lid on it (items/burner.luau, `sealed`) -- without one
-- a standing burner would evaporate its own fuel in a couple of hours.
local content = {
    id = "ethanol",
    name = "ethanol",
    molar_mass = 46.07,
    cv = { solid = 112.0, liquid = 112.0, gas = 65.4 },
    phase = { melt = 159.0, boil = 351.5, l_fus = 4900, l_vap = 38560 },
    density = { liquid = 0.789 },
    metabolism_rate = 0.002,
    -- What it does over a flame. tg: `burning_temperature = 2193`
    -- ("ethanol burns at 1970C (at its peak)") and `burning_volume =
    -- 0.1` (drinks/alcohol_reagents.dm:13-14).
    --
    -- The rate converts through two constants and nothing else:
    --   0.1 u per tg burn tick x 0.025 mol/u  = 0.0025 mol per tick
    --   / 2 s per tg tick x 0.5 s per pass    = 0.000625 mol per pass
    -- so a burner's 15 u tank burns for tg's own five minutes.
    burn = { k = 2193, rate = 0.000625 },
    -- What it looks like through glass (tg: alcohol_reagents.dm:7).
    color = "#404030",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        if math.random(1, 6) == 1 then
            sim.message.send({ recipient = mob, message = "You feel a little tipsy." })
        end
    end)
end

return content
