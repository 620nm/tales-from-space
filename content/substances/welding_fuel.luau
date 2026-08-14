-- What a torch burns. A welder's tank is an ordinary Holder, so this is
-- an ordinary substance: it pours, it spills, it mixes, and a cut girder
-- costs mols of it like everything else costs something.
-- Numbers are acetylene's (C2H2), the gas tg's welders nominally carry;
-- it sits in the tank as a liquid the way a beaker's contents do.
return {
    id = "welding_fuel",
    name = "welding fuel",
    molar_mass = 26.04,
    cv = 44.0,
    metabolism_rate = 0.004,
    on_mob_life = function(ctx, mob, moles)
        ctx.damage(mob, { brute = 1.0 })
        if ctx.random(1, 8) == 1 then
            ctx.system_msg(mob, "Your throat burns.")
        end
    end,
}
