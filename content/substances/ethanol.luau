-- Where fermentation leads. Flavor only until drunkenness mechanics —
-- but it metabolizes, and the ledger knows you had some.
return {
    id = "ethanol",
    name = "ethanol",
    molar_mass = 46.07,
    cv = 112.0,
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
    on_mob_life = function(ctx, mob, moles)
        if ctx.random(1, 6) == 1 then
            ctx.system_msg(mob, "You feel a little tipsy.")
        end
    end,
}
