-- The brute-healing workhorse (tg's libital, in spirit — tg's unit
-- economy doesn't map to moles, so the numbers are ss13rs-calibrated:
-- one 0.15 mol beaker heals ~75 brute over ~100 s).
return {
    id = "libital",
    name = "libital",
    molar_mass = 180.0,
    cv = 90.0,
    metabolism_rate = 0.003,
    on_mob_life = function(ctx, mob, moles)
        ctx.heal(mob, { brute = 1.5 })
        if ctx.random(1, 10) == 1 then
            ctx.system_msg(mob, "Your bruises ache less.")
        end
    end,
}
