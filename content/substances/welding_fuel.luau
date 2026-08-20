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
    -- What it does over a flame. tg: `burning_temperature = 1725`
    -- ("more refined than oil") and `burning_volume = 0.2`
    -- (other_reagents.dm:1377-1378) — twice ethanol's rate at a lower
    -- temperature, which is what "refined" buys you.
    --   0.2 u x 0.025 mol/u / 2 s x 0.5 s = 0.00125 mol per pass
    burn = { k = 1725, rate = 0.00125 },
    -- What it looks like through glass (tg: other_reagents.dm:1373).
    color = "#660000",
    on_mob_life = function(ctx, mob, moles)
        ctx.damage(mob, { brute = 1.0 })
        if ctx.random(1, 8) == 1 then
            ctx.system_msg(mob, "Your throat burns.")
        end
    end,
}
