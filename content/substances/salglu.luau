-- Saline-glucose solution: the medicine anybody can make. Water, salt
-- and sugar (reactions/salglu.luau), which is three dispenser buttons
-- and the only healing chem on this bench whose legs are all on the
-- shelf.
--
-- WHERE THE NUMBERS COME FROM. The bridge is spelled out in
-- substances/multiver.luau. Salglu metabolizes at `0.5 x
-- REAGENTS_METABOLISM` (medicine_reagents.dm:310) like a c2, so its
-- `metabolization_ratio` is 0.5.
--
-- tg's line is
--   if(SPT_PROB(18, spt))
--     adjust_brute_loss(-0.5 x ratio)
--     adjust_fire_loss(-0.5 x ratio)
-- (medicine_reagents.dm:333-338). Note what is NOT on those two lines:
-- `seconds_per_tick`. The heal is a quarter point of each per tick,
-- and it only lands on the roll -- which tg's own description puts at
-- "a 33% chance per metabolism cycle" (medicine_reagents.dm:308), and
-- which is what `SPT_PROB(18, 2)` works out to. Both halves ship: a
-- weak heal, on a die.
--
-- The blood-volume half of tg's hook is not ported. Salglu there is a
-- temporary blood substitute and nudges `adjust_blood_volume` every
-- tick; this engine has blood and no content call that moves it, and
-- inventing one for a single reagent is the wrong shape (AGENTS.md's
-- boundary test). What ships is the healing.
--
-- Fiction-grade product -- it is a SOLUTION rather than a molecule, so
-- there is nothing real to measure. The mass and the heat capacity are
-- the shelf's convention (D2, docs/CHEMISTRY.md) and the density is a
-- plausible round figure for a sugar solution, which geometry reads
-- when it caps the reaction by the free shell volume (D16).
-- tg: /datum/reagent/medicine/salglu_solution (medicine_reagents.dm:306).
local content = {
    id = "salglu",
    name = "saline-glucose solution",
    molar_mass = 180.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.1 },
    -- tg's 0.5 x REAGENTS_METABOLISM through this engine's own 0.005
    -- mol a tick: 0.0025.
    metabolism_rate = 0.0025,
    -- What it looks like through glass (tg: medicine_reagents.dm:309).
    color = "#DCDCDC",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life(ctx, self, user, moles)`: the metabolism hook hands
    -- the same mob twice, as the thing the hook is on and as the body
    -- it is happening to, and the moles metabolized this tick last.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        -- tg's SPT_PROB(18, 2), which its own description rounds to a
        -- third of the ticks.
        if math.random(1, 3) ~= 1 then
            return
        end
        sim.healing.apply({ target = mob, amounts = { brute = 0.25, burn = 0.25 } })
    end)
end

return content
