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
    -- `on_mob_life(ctx, self, user, moles)`: the hook hands the same mob
    -- twice -- as the thing it is on and as the body it is happening to
    -- -- and the moles burned this metabolism tick last.
    --
    -- The heal is written against those moles rather than flat, because
    -- what a pick-me-up is worth is how much of it you just burned. A
    -- full trip is `metabolism_rate` x 125 = the same 0.5 oxy it has
    -- always been; the dregs at the bottom of a can are worth
    -- proportionally less, which is the honest shape and the one the
    -- comment above always claimed.
    on_mob_life = function(ctx, mob, _user, moles)
        ctx.heal(mob, { oxy = moles * 125.0 })
        if ctx.random(1, 12) == 1 then
            ctx.system_msg(mob, "The sugar perks you up a little.")
        end
    end,
}
