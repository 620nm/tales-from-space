-- Chlorine: Cl2, the molecule, and the most dangerous thing this bench
-- can make.
--
-- ONE ID PER MOLECULE. There used to be two files here -- a `chlorine`
-- reagent that was a single atom so tg's 1:1 salt recipe kept its
-- arithmetic, and a `cl2` beside it that was the real gas -- with a
-- fictional 420 K rule as the door between them. That is gone: a
-- substance is a molecule, a PHASE is something it reaches by being
-- warm or cold or under pressure, and a recipe that stood on the wrong
-- one was rewritten rather than bridged (reactions/salt.luau takes two
-- sodium for one Cl2, which is what the molecule actually says).
--
-- Numbers are NIST's for Cl2: boiling 239.11 K, melting 171.6 K, heat
-- of vaporization 20.41 kJ/mol, heat of fusion 6.406 kJ/mol, liquid
-- density 1.468 g/mL. Heat capacity 33.9 J/(mol*K), the real molar
-- figure for the gas, carried across all three phases.
--
-- WHERE A CHEMIST GETS IT. At 300 K and one atmosphere chlorine RESTS
-- as a gas, so a press over an open beaker is refused -- what landed
-- would leave through the same mouth before anybody looked up. Pressed
-- into a sealed bottle the same press lands, condenses under its own
-- vapour pressure (about 8 atm at 300 K), and the bottle holds LIQUID
-- chlorine, which is the reactant salt is made out of.
--
-- WHAT IT DOES TO YOU, and where 16 000 comes from.
--
-- The floor under every calibration on this shelf is BREATH_OXY_HEAL:
-- a body that breathes well takes 5 oxy off its own total every
-- breath, and oxy never goes below zero, so anything under 5 oxy per
-- breath is not gentle -- it is INVISIBLE.
--
-- One breath is 1.99 L, so 1 kPa of partial pressure is
--   n = P*V/RT = 1000 * 0.00199 / (8.314 * 293.15) = 8.166e-4 mol
-- and `inhale = 0.9` keeps nine tenths of it: 7.35e-4 mol per breath.
-- Times 16 000 that is 11.8 oxy, against the 5 a good breath heals
-- back: 6.8 net per breath, 15 breaths to OXY_CRIT, and a breath is
-- eight seconds. Two minutes from walking in to going down, at a
-- concentration ammonia does not register at (substances/ammonia.luau,
-- 12 000 and inhale 0.5, the WARNING to this one's kill).
--
-- That gap is the point. Chlorine is not "worse ammonia" -- it is the
-- one that gives you a shift's worth of warning in the wrong units:
-- the smell arrives long before the harm, and by the time it is
-- obviously harming you the two minutes have started. Internals stop
-- it dead, which is the answer the game wants a crewman to reach for.
--
-- MAX_SCRIPT_HIT caps any one hook at 40, so a thick cloud kills in
-- about ten breaths and no faster.
-- tg: /datum/reagent/chlorine (other_reagents.dm:1087).
local content = {
    id = "chlorine",
    name = "chlorine",
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
    -- A thing the station is built to keep away from itself.
    dangerous = true,
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). Reachable as room air, and
    -- rarely what a room is commissioned holding.
    relevance = 10,
    -- A caustic cloud with a metabolism hook that sets a chest on fire;
    -- tg has no gas datum for it, so its own reagent decides.
    group = "poison",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life(ctx, self, user, moles)`: the metabolism hook hands
    -- the same mob twice, as the thing the hook is on and as the body
    -- it is happening to, and the moles metabolized this tick last.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.damage.apply({ target = mob, amounts = { oxy = moles * 16000 } })
        if math.random(1, 3) == 1 then
            sim.message.send({ recipient = mob, message = "Your chest is on fire." })
        end
    end)
end

return content
