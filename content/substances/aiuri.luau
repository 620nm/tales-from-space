-- Aiuri: the burn medicine, and the one rule on this bench that takes
-- heat OUT of the vessel it runs in (reactions/aiuri.luau). Liquid
-- ammonia and sulphuric acid in a bottle, and the bottle frosts.
--
-- WHERE THE NUMBERS COME FROM. The bridge is spelled out in
-- substances/multiver.luau: a tg `/datum/reagent/medicine/c2` has
-- `metabolization_ratio = 0.5` and `seconds_per_tick = 2`, so a tg
-- line of the form `X x ratio x spt` is X per two-second tick, and
-- this engine's metabolism runs on the same two seconds
-- (docs/BENCH.md 5).
--
-- tg's line is
--   adjust_fire_loss(-2 x ratio x spt)
--   adjust_organ_loss(EYES, 0.25 x ratio x spt)
-- (cat2_medicine_reagents.dm:200-206): two points of burn off a tick,
-- and a quarter of a point onto the eyes for it. That is what a
-- category-2 medicine IS -- it works and it costs you something --
-- and both halves ship.
--
-- Fiction-grade product: the mass and the heat capacity are the
-- shelf's convention (D2, docs/CHEMISTRY.md) and the density is a
-- plausible round figure for an organic liquid, which geometry reads
-- when it caps the reaction by the free shell volume (D16).
-- tg: /datum/reagent/medicine/c2/aiuri (cat2_medicine_reagents.dm:190).
local content = {
    id = "aiuri",
    name = "aiuri",
    molar_mass = 180.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.15 },
    -- tg's c2 rate, 0.5 x REAGENTS_METABOLISM, through this engine's
    -- own 0.005 mol a tick: 0.0025.
    metabolism_rate = 0.0025,
    -- What it looks like through glass
    -- (tg: cat2_medicine_reagents.dm:193).
    color = "#8C93FF",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- `mob.life(ctx, self, user, moles)`: the metabolism hook hands
    -- the same mob twice, as the thing the hook is on and as the body
    -- it is happening to, and the moles metabolized this tick last.
    script_definition:handle("mob.life", { kind = "react", route = "metabolize" }, function(ev)
        local mob, _user, moles, _moles = ev.entity, ev.entity, ev.amount, ev.amount
        sim.healing.apply({ target = mob, amounts = { burn = 2.0 } })
        sim.damage_organ(mob, "eyes", 0.25)
        if math.random(1, 10) == 1 then
            sim.message.send({ recipient = mob, message = "Your burns cool, and the light hurts." })
        end
    end)
end

return content
