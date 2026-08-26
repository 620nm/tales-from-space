-- Ammonia: NH3, the molecule, and the bench's first real synthesis.
--
-- ONE ID PER MOLECULE. There used to be two files here -- an `ammonia`
-- reagent that was a room-temperature liquid because tg's is, and an
-- `nh3` beside it with the real curve, joined by a fictional 700 K
-- rule -- and the pair is gone. A substance is a molecule; a phase is
-- something it reaches. The recipes that stood on the liquid were
-- rewritten to say which phase they mean (space_cleaner takes
-- `ammonia:liquid`, which is what a sealed bottle holds; nitrous oxide
-- takes the same liquid with an oxygen share over it).
--
-- Numbers are NIST's for NH3: boiling 239.81 K, melting 195.4 K, heat
-- of vaporization 23.35 kJ/mol at the boiling point, heat of fusion
-- 5.65 kJ/mol, liquid density 0.682 g/mL at the boiling point, solid
-- 0.817. Gas heat capacity 35.1 J/(mol*K); the condensed columns are
-- the 80.8 the old reagent carried, so a beaker of it costs what it
-- always cost to heat.
--
-- WHERE A CHEMIST GETS IT. At 300 K and one atmosphere ammonia RESTS
-- as a gas, so a press over an open beaker is refused and the same
-- press into a sealed bottle lands and condenses under its own vapour
-- pressure (about 8.6 atm at 293 K). Synthesis is the other way in:
-- reactions/ammonia.luau runs nitrogen and hydrogen together in a
-- pressurised vessel.
--
-- WHAT IT DOES TO YOU, and where 12 000 comes from.
--
-- The floor under every calibration on this shelf is BREATH_OXY_HEAL:
-- a body that breathes well takes 5 oxy off its own total every breath,
-- and oxy never goes below zero. So anything under 5 oxy per breath is
-- invisible -- not gentle, INVISIBLE -- and the question a damage
-- constant answers is "at what concentration does this start to be
-- something you notice".
--
-- One breath is 1.99 L (tg BREATH_VOLUME). At 1 kPa of partial
-- pressure and room temperature that is
--   n = P*V/RT = 1000 * 0.00199 / (8.314 * 293.15) = 8.166e-4 mol
-- of which `inhale = 0.5` keeps half: 4.08e-4 mol per breath. Times
-- 12 000 that is 4.9 oxy per breath, which is just under the heal.
--
-- So: a room at 1 kPa of ammonia is a room that smells terrible and
-- does nothing, and at 1.5 kPa it starts to hurt (7.4 against the 5).
-- That is the shape wanted -- ammonia is the WARNING, the thing a
-- chemist makes by accident and learns from. Chlorine is the one that
-- kills you (substances/chlorine.luau, 16 000 and inhale 0.9, crit in
-- two minutes at the concentration ammonia shrugs off).
--
-- MAX_SCRIPT_HIT caps any single hook at 40, so a genuinely thick
-- cloud is lethal in about ten breaths and cannot run away faster than
-- that however badly somebody misjudges a reaction.
-- tg: /datum/reagent/ammonia (other_reagents.dm:1627).
local content = {
    id = "ammonia",
    name = "ammonia",
    molar_mass = 17.03,
    cv = { solid = 80.8, liquid = 80.8, gas = 35.1 },
    phase = { melt = 195.4, boil = 239.8, l_fus = 5650, l_vap = 23350 },
    density = { liquid = 0.682, solid = 0.817 },
    inhale = 0.5,
    metabolism_rate = 0.01,
    -- Faintly yellow-green and thin: tg's MOLES_GAS_VISIBLE threshold
    -- and FACTOR_GAS_VISIBLE_MAX, so a room has to hold a quarter of a
    -- mole of it before there is anything to see at all.
    visible = { moles = 0.25, factor = 20, tint = "#DFE8C0" },
    -- What it looks like through glass (tg: other_reagents.dm:1630).
    color = "#404030",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). Reachable as room air, and
    -- rarely what a room is commissioned holding.
    relevance = 20,
    -- A caustic cloud with a metabolism hook that burns eyes and throat;
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
        sim.damage.apply({ target = mob, amounts = { oxy = moles * 12000 } })
        if math.random(1, 4) == 1 then
            sim.message.send({ recipient = mob, message = "Your eyes and throat burn." })
        end
    end)
end

return content
