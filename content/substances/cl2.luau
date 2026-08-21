-- Chlorine GAS -- Cl2, the diatomic molecule, as against the single
-- atom the bench calls `chlorine`.
--
-- The same split nh3.luau explains, and for the same reason (policy D3,
-- docs/reagents.md): tg's chlorine reagent is one atom because its salt
-- recipe is 1:1 with sodium, and salt is a shipped recipe that runs at
-- room temperature. Give that file a curve and every batch of salt
-- becomes a race against its own reactant evaporating. So the reagent
-- keeps tg's arithmetic and this file keeps chemistry's, and
-- reactions/chlorine_gas.luau is the door between them: two atoms make
-- one molecule, above 420 K, as gas.
--
-- Numbers are NIST's for Cl2: boiling 239.11 K, melting 171.6 K, heat
-- of vaporization 20.41 kJ/mol, heat of fusion 6.406 kJ/mol, liquid
-- density 1.468 g/mL. Heat capacity 33.9 J/(mol*K), the real molar
-- figure for the gas, carried across all three phases.
--
-- WHAT IT DOES TO YOU, and where 16 000 comes from.
--
-- The derivation is nh3.luau's, run at the other end. One breath is
-- 1.99 L, so 1 kPa of partial pressure is
--   n = P*V/RT = 1000 * 0.00199 / (8.314 * 293.15) = 8.166e-4 mol
-- and `inhale = 0.9` keeps nine tenths of it: 7.35e-4 mol per breath.
-- Times 16 000 that is 11.8 oxy, against the 5 a good breath heals:
-- 6.8 net per breath, 15 breaths to OXY_CRIT, and a breath is eight
-- seconds. Two minutes from walking in to going down, at a
-- concentration ammonia does not register at.
--
-- That gap is the point. Chlorine is not "worse ammonia" -- it is the
-- one that gives you a shift's worth of warning in the wrong units:
-- the smell arrives long before the harm, and by the time it is
-- obviously harming you the two minutes have started. Internals stop
-- it dead, which is the answer the game wants a crewman to reach for.
--
-- MAX_SCRIPT_HIT caps any one hook at 40, so a thick cloud kills in
-- about ten breaths and no faster.
return {
    id = "cl2",
    name = "chlorine gas",
    molar_mass = 70.90,
    cv = 33.9,
    phase = { melt = 171.6, boil = 239.1, l_fus = 6406, l_vap = 20410 },
    density = { liquid = 1.468 },
    inhale = 0.9,
    metabolism_rate = 0.02,
    -- The yellow-green everybody recognizes, over tg's own visibility
    -- threshold: a quarter mole before it shows at all, full opacity at
    -- twenty times that.
    visible = { moles = 0.15, factor = 20, tint = "#C4D64A" },
    -- Through glass, the colour its reagent wears
    -- (tg: other_reagents.dm:1090).
    color = "#FFFB89",
    -- `on_mob_life(ctx, self, user, moles)` -- see nh3.luau.
    on_mob_life = function(ctx, mob, _user, moles)
        ctx.damage(mob, { oxy = moles * 16000 })
        if ctx.random(1, 3) == 1 then
            ctx.system_msg(mob, "Your chest is on fire.")
        end
    end,
}
