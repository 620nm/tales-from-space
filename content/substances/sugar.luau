-- Dissolved sugar: mild pick-me-up. The physics half (cv, molar mass)
-- feeds the matter registry; metabolism_rate and on_mob_life are the
-- gameplay half. moles is how much this metabolism tick burned.
return {
    id = "sugar",
    name = "sugar",
    molar_mass = 342.3,
    cv = 120.0,
    metabolism_rate = 0.004,
    -- What it looks like through glass (tg: food_reagents.dm:313 (COLOR_WHITE)).
    color = "#FFFFFF",
    on_mob_life = function(ctx, mob, moles)
        ctx.heal(mob, { oxy = 0.5 })
        if ctx.random(1, 12) == 1 then
            ctx.system_msg(mob, "The sugar perks you up a little.")
        end
    end,
}
