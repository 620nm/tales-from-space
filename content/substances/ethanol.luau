-- Where fermentation leads. Flavor only until drunkenness mechanics —
-- but it metabolizes, and the ledger knows you had some.
return {
    id = "ethanol",
    name = "ethanol",
    molar_mass = 46.07,
    cv = 112.0,
    metabolism_rate = 0.002,
    on_mob_life = function(ctx, mob, moles)
        if ctx.random(1, 6) == 1 then
            ctx.system_msg(mob, "You feel a little tipsy.")
        end
    end,
}
