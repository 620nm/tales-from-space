-- Toxin: tg's base poison, and what an incompatible transfusion
-- leaves behind. It arrives only as that reaction
-- (`lib/blood_identity.luau`): no recipe makes it, no dispenser pours
-- it -- iodine and radium are the precedent for a substance file with
-- no button.
--
-- tg gives it a name, a colour and a damage figure and nothing else:
-- /datum/reagent/toxin (code/modules/reagents/chemistry/reagents/
-- toxin_reagents.dm:4-21), `color = "#CF3600"` (:7), `toxpwr = 1.5`
-- (:13). Mass, heat capacity and density are the shelf's D2
-- convention for a fictional leftover (docs/CHEMISTRY.md), stated and
-- not measured. It rests liquid and never transitions on its own, the
-- way blood does: tg gives it no phase curve either.
--
-- WHAT A MOLE COSTS. tg deals 0.5 x toxpwr per second a body holds any
-- (on_mob_life, toxin_reagents.dm:27-30) and burns REAGENTS_METABOLISM
-- 0.2 u/s (code/__DEFINES/mobs.dm:505), so a mole costs
-- 0.75 / (0.2 x 0.025) = 150 tox. This shelf charges per mole
-- metabolized instead of per second present, the way chlorine does --
-- a trace charges a trace -- and the whole of a dose lands the same
-- total tg's curve does.
-- tg: /datum/reagent/toxin (toxin_reagents.dm:4).
local content = {
    id = "toxin",
    name = "toxin",
    molar_mass = 100.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.0 },
    -- What it looks like through glass (tg: toxin_reagents.dm:7).
    color = "#CF3600",
    -- What a placard says about this substance alone
    -- (the engine's docs/chemistry/substances.md, `hazard`). The base
    -- poison: a serious health figure and nothing else.
    hazard = { health = 3, fire = 0, instability = 0 },
    -- A bench substance like the catalysts, filed under Other:
    -- nothing scrubs it, nothing breathes it, and no dispenser pours it.
    group = "other",
    -- The loader's own 0.005, stated rather than taken by silence: a
    -- poison that never metabolized would never charge.
    metabolism_rate = 0.005,
}

-- 150 tox per mole metabolized (the derivation above).
local TOX_PER_MOLE = 150.0

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        sim.damage.apply({ target = ev.entity, amounts = { tox = ev.amount * TOX_PER_MOLE } })
    end)
end

return content
