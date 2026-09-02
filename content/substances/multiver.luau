-- Multiver: the chem purger. Two presses and a hotplate at 400 K
-- (reactions/multiver.luau) make the cheapest medicine on the bench,
-- and the only one whose legs are both already products of something
-- else -- ash out of oil, salt out of sodium and liquid chlorine.
--
-- WHERE THE NUMBERS COME FROM. tg's Life tick is two seconds and so is
-- this engine's metabolism (`METABOLISM_EVERY = 40`,
-- docs/BENCH.md 5), so a tg per-tick figure ports straight across
-- once its two scaling factors are resolved:
--
--   metabolization_ratio = REM x metabolized_volume        (mob_life.dm:106)
--   REM                  = 1 / (0.2 x 2) = 2.5             (mobs.dm:505-506)
--   metabolized_volume   = metabolization_rate x seconds_per_tick
--
-- A `/datum/reagent/medicine/c2` metabolizes at `0.5 x
-- REAGENTS_METABOLISM` (cat2_medicine_reagents.dm:4), so its ratio is
-- 0.5 and `X x ratio x seconds_per_tick` is just X per tick.
--
-- tg's line is
--   adjust_tox_loss(-0.5 x min(medibonus, 6) x ratio x spt)
--   adjust_organ_loss(LUNGS, 0.5 x ratio x spt)
-- (cat2_medicine_reagents.dm:378-390). `medibonus` counts the unique
-- medicines in the bloodstream and multiver always counts itself, so
-- the floor is 1: half a point of toxin off per tick, and half a point
-- onto the lungs for it. The stacking bonus is not ported -- it reads
-- the whole reagent list per tick and this engine's hook is handed one
-- substance -- so what ships is tg's floor, which is also tg's
-- description of the chem: not great at healing, but it works when
-- there is nothing else.
--
-- Fiction-grade product, so the mass and the heat capacity are the
-- shelf's convention (D2, docs/CHEMISTRY.md) and the density is a
-- plausible round figure for a heavy organic -- which is load-bearing
-- rather than decorative, because geometry caps a reaction by the free
-- shell volume (D16) and two of these come out of every extent.
-- tg: /datum/reagent/medicine/c2/multiver (cat2_medicine_reagents.dm:369).
local content = {
    id = "multiver",
    name = "multiver",
    molar_mass = 200.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.2 },
    -- tg's c2 rate, 0.5 x REAGENTS_METABOLISM, through this engine's
    -- own 0.005 mol a tick: 0.0025.
    metabolism_rate = 0.0025,
    -- tg gives it no colour of its own, so it wears the reagent
    -- default (reagents.dm:32, COLOR_BLACK) -- which is also what its
    -- mix message says it looks like: a fine black powder.
    color = "#000000",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- A dosed medicine: harmful in quantity, inert otherwise.
    hazard = { health = 1, fire = 0, instability = 0 },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life(ctx, self, user, moles)`: the metabolism hook hands
    -- the same mob twice, as the thing the hook is on and as the body
    -- it is happening to, and the moles metabolized this tick last.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.healing.apply({ target = mob, amounts = { tox = 0.5 } })
        sim.damage_organ(mob, "lungs", 0.5)
        if math.random(1, 10) == 1 then
            sim.message.send({ recipient = mob, message = "Your chest feels tight." })
        end
    end)
end

return content
